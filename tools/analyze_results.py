#!/usr/bin/env python3
"""Summarize plc_lab EtherCAT benchmark CSV exports.

Missing measurements stay missing: DC deviation, WKC, PDO latency and CPU load
are never inferred from unrelated signals. A capture missing any of the six core
benchmark dimensions is INCOMPLETE rather than silently passing.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path
from typing import Iterable, Mapping, Sequence

GROUP_KEYS = ("controller", "mode", "requested_cycle_us")
CORE_METRICS = (
    "task_jitter",
    "dc_deviation",
    "wkc",
    "pdo_latency",
    "following_error",
    "cpu_load",
)


def _float(value: object) -> float | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        number = float(text)
    except ValueError:
        return None
    return number if math.isfinite(number) else None


def _bool(value: object) -> bool | None:
    if value is None:
        return None
    text = str(value).strip().lower()
    if not text:
        return None
    if text in {"1", "true", "yes", "y", "ok", "pass"}:
        return True
    if text in {"0", "false", "no", "n", "bad", "fail"}:
        return False
    return None


def percentile(values: Sequence[float], p: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    rank = (len(ordered) - 1) * p
    lower = math.floor(rank)
    upper = math.ceil(rank)
    if lower == upper:
        return ordered[lower]
    weight = rank - lower
    return ordered[lower] * (1.0 - weight) + ordered[upper] * weight


def load_rows(paths: Iterable[Path]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for path in paths:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if not reader.fieldnames:
                continue
            missing = [key for key in GROUP_KEYS if key not in reader.fieldnames]
            if missing:
                raise ValueError(f"{path}: missing grouping columns: {', '.join(missing)}")
            for row in reader:
                clean = {k: (v or "").strip() for k, v in row.items()}
                clean["_source"] = str(path)
                rows.append(clean)
    return rows


def _series(rows: Sequence[Mapping[str, str]], field: str, *, absolute: bool = False) -> list[float]:
    values: list[float] = []
    for row in rows:
        value = _float(row.get(field))
        if value is not None:
            values.append(abs(value) if absolute else value)
    return values


def _summary_stats(values: Sequence[float]) -> dict[str, float | int | None]:
    if not values:
        return {"count": 0, "median": None, "p99": None, "max": None}
    return {
        "count": len(values),
        "median": statistics.median(values),
        "p99": percentile(values, 0.99),
        "max": max(values),
    }


def summarize_group(
    rows: Sequence[Mapping[str, str]],
    *,
    following_error_limit: float | None = None,
    jitter_p99_ratio_limit: float = 0.10,
    jitter_max_ratio_limit: float = 0.25,
    dc_p99_limit_ns: float = 5000.0,
    cpu_p99_limit_pct: float = 80.0,
) -> dict[str, object]:
    if not rows:
        raise ValueError("cannot summarize an empty group")

    requested = _float(rows[0].get("requested_cycle_us"))
    if requested is None or requested <= 0:
        raise ValueError("requested_cycle_us must be positive")

    actual = _series(rows, "actual_cycle_us")
    task_delta = _series(rows, "task_delta_us")
    jitter = _series(rows, "jitter_us", absolute=True)
    if not jitter and task_delta:
        jitter = [abs(v - requested) for v in task_delta]

    dc = _series(rows, "dc_deviation_ns", absolute=True)
    pdo = _series(rows, "pdo_latency_us")
    following = _series(rows, "following_error", absolute=True)
    cpu = _series(rows, "cpu_load_pct")
    lost = _series(rows, "lost_frames")

    wkc_values = [_bool(row.get("wkc_ok")) for row in rows]
    wkc_present = [value for value in wkc_values if value is not None]
    bad_wkc = sum(value is False for value in wkc_present)

    actual_stats = _summary_stats(actual or task_delta)
    jitter_stats = _summary_stats(jitter)
    dc_stats = _summary_stats(dc)
    pdo_stats = _summary_stats(pdo)
    following_stats = _summary_stats(following)
    cpu_stats = _summary_stats(cpu)

    missing_metrics: list[str] = []
    for name, values in (
        ("task_jitter", jitter),
        ("dc_deviation", dc),
        ("wkc", wkc_present),
        ("pdo_latency", pdo),
        ("following_error", following),
        ("cpu_load", cpu),
    ):
        if not values:
            missing_metrics.append(name)

    reasons: list[str] = []
    measured_cycle = actual_stats["median"]
    if measured_cycle is not None and abs(float(measured_cycle) - requested) > max(2.0, requested * 0.05):
        reasons.append(f"measured cycle {measured_cycle:.3f} us differs from requested {requested:.0f} us")
    if jitter_stats["p99"] is not None and float(jitter_stats["p99"]) > requested * jitter_p99_ratio_limit:
        reasons.append(f"jitter p99 {jitter_stats['p99']:.3f} us exceeds {jitter_p99_ratio_limit:.0%} of cycle")
    if jitter_stats["max"] is not None and float(jitter_stats["max"]) > requested * jitter_max_ratio_limit:
        reasons.append(f"jitter max {jitter_stats['max']:.3f} us exceeds {jitter_max_ratio_limit:.0%} of cycle")
    if dc_stats["p99"] is not None and float(dc_stats["p99"]) > dc_p99_limit_ns:
        reasons.append(f"DC deviation p99 {dc_stats['p99']:.1f} ns exceeds {dc_p99_limit_ns:.0f} ns")
    if bad_wkc:
        reasons.append(f"{bad_wkc} samples report bad WKC")
    if lost and max(lost) > 0:
        reasons.append(f"lost_frames reached {max(lost):.0f}")
    if following_error_limit is not None and following_stats["max"] is not None:
        if float(following_stats["max"]) > following_error_limit:
            reasons.append(f"following error max {following_stats['max']:.6g} exceeds {following_error_limit:.6g}")
    if cpu_stats["p99"] is not None and float(cpu_stats["p99"]) > cpu_p99_limit_pct:
        reasons.append(f"CPU load p99 {cpu_stats['p99']:.1f}% exceeds {cpu_p99_limit_pct:.1f}%")

    explicit = {str(row.get("status", "")).upper() for row in rows if row.get("status")}
    if "UNSUPPORTED" in explicit:
        status = "UNSUPPORTED"
    elif "ABORTED" in explicit:
        status = "ABORTED"
    elif reasons:
        status = "FAIL"
    elif missing_metrics:
        status = "INCOMPLETE"
    else:
        status = "PASS"

    return {
        "controller": rows[0].get("controller", ""),
        "mode": rows[0].get("mode", ""),
        "requested_cycle_us": int(requested),
        "samples": len(rows),
        "status": status,
        "reasons": reasons,
        "missing_metrics": missing_metrics,
        "actual_cycle_us": actual_stats,
        "jitter_abs_us": jitter_stats,
        "dc_deviation_abs_ns": dc_stats,
        "pdo_latency_us": pdo_stats,
        "following_error_abs": following_stats,
        "cpu_load_pct": cpu_stats,
        "bad_wkc_samples": bad_wkc,
        "lost_frames_max": max(lost) if lost else None,
    }


def summarize_rows(rows: Sequence[Mapping[str, str]], **kwargs: object) -> list[dict[str, object]]:
    grouped: dict[tuple[str, str, str], list[Mapping[str, str]]] = defaultdict(list)
    for row in rows:
        key = tuple(row.get(name, "") for name in GROUP_KEYS)
        grouped[key].append(row)
    return [summarize_group(grouped[key], **kwargs) for key in sorted(grouped)]


def _fmt(value: object, precision: int = 3) -> str:
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:.{precision}f}"
    return str(value)


def render_markdown(summaries: Sequence[Mapping[str, object]]) -> str:
    headers = ["Controller", "Mode", "Cycle us", "Status", "Jitter p99 us", "DC p99 ns", "PDO latency p99 us", "Follow err p99", "CPU p99 %", "Bad WKC", "Lost frames", "Missing"]
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join(["---"] * len(headers)) + "|"]
    for item in summaries:
        jitter = item["jitter_abs_us"]
        dc = item["dc_deviation_abs_ns"]
        pdo = item["pdo_latency_us"]
        follow = item["following_error_abs"]
        cpu = item["cpu_load_pct"]
        lines.append("| " + " | ".join([
            str(item["controller"]), str(item["mode"]), str(item["requested_cycle_us"]), str(item["status"]),
            _fmt(jitter["p99"]), _fmt(dc["p99"], 1), _fmt(pdo["p99"]), _fmt(follow["p99"], 6), _fmt(cpu["p99"], 1),
            str(item["bad_wkc_samples"]), _fmt(item["lost_frames_max"], 0), ", ".join(item["missing_metrics"]) or "-",
        ]) + " |")
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", nargs="+", type=Path, help="raw benchmark CSV exports")
    parser.add_argument("--json", action="store_true", help="emit JSON instead of Markdown")
    parser.add_argument("--following-error-limit", type=float, default=None, help="optional application-unit limit; no default is assumed")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    rows = load_rows(args.csv)
    summaries = summarize_rows(rows, following_error_limit=args.following_error_limit)
    if args.json:
        print(json.dumps(summaries, ensure_ascii=False, indent=2))
    else:
        print(render_markdown(summaries))
        for item in summaries:
            for reason in item["reasons"]:
                print(f"- {item['controller']} {item['mode']} {item['requested_cycle_us']} us: {reason}")
            if item["status"] == "INCOMPLETE":
                print(
                    f"- {item['controller']} {item['mode']} {item['requested_cycle_us']} us: "
                    f"missing required metrics: {', '.join(item['missing_metrics'])}"
                )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
