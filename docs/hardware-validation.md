# Hardware qualification checklist

Use this checklist for **each controller independently** before comparing results. A benchmark row is not comparable until both controllers use the same drive/motor/PDO/cable/mechanical configuration.

## 0. Record immutable run metadata

- [ ] Controller model and firmware/build.
- [ ] ZDevelop/RTSys or InoProShop version and target package.
- [ ] SV680N model, firmware and ESI/XML revision.
- [ ] Motor/joint model, encoder resolution and engineering-unit scaling.
- [ ] EtherCAT topology, cable order and cable lengths.
- [ ] Exact RxPDO/TxPDO object list and total bytes per slave.
- [ ] DC reference-clock strategy.
- [ ] Drive positive/negative torque limits and velocity limits.
- [ ] STO / emergency-stop verified.

## 1. Static bus qualification — 1 axis, 1000 us

Power stage disabled / zero command.

- [ ] One SV680N discovered with the expected identity.
- [ ] PREOP -> SAFEOP -> OP succeeds.
- [ ] Requested cycle = active cycle.
- [ ] DC enabled and stable if configured.
- [ ] WKC/working-counter diagnostic captured where available.
- [ ] Lost-frame/link counters start at zero.
- [ ] Task-cycle/jitter capture works.
- [ ] CPU/load source identified.
- [ ] PDO loopback fixture/source identified; otherwise mark PDO latency missing.

Do not proceed if the 1-axis static case is not clean.

## 2. Static bus qualification — 16 axes, 1000 us

Power stage disabled / zero command.

- [ ] All 16 drives reach OP.
- [ ] Same PDO layout is confirmed on all drives.
- [ ] 180 s idle capture completes.
- [ ] Lost frames = 0.
- [ ] Bad WKC samples = 0 where measurable.
- [ ] DC deviation distribution exported.
- [ ] Task jitter distribution exported.
- [ ] CPU load distribution exported.
- [ ] Explicit PDO loopback latency captured or marked unavailable.

## 3. CSP qualification — 16 axes, 1000 us

Start with reduced travel/speed if the mechanics are not yet characterized.

- [ ] Drives enabled without fault.
- [ ] +/-5 deg-equivalent alternating-axis trajectory is mechanically safe.
- [ ] Command position and actual position captured.
- [ ] Following error captured for every axis.
- [ ] No axis/controller/bus fault during 180 s capture.
- [ ] Bus diagnostics saved immediately after run.

## 4. CST qualification — 16 axes, 1000 us

**Restrained fixture only.** Verify STO/emergency stop before arming CST.

- [ ] Checked-in zero-torque run completes first.
- [ ] Actual torque scaling verified against SV680N 0x6077 / vendor monitor.
- [ ] First nonzero run <= +/-2% rated torque.
- [ ] Torque polarity reverses every 1 s as expected.
- [ ] Velocity remains within the configured drive limit.
- [ ] Zero-torque command is observed before power removal on stop.
- [ ] No mechanical instability or unexpected motion.

## 5. Period step-down

Only continue when the previous period passes or is explicitly understood.

For each mode, run:

```text
1000 us -> 500 us -> 250 us -> 125 us
```

At every step:

- [ ] Confirm the controller/runtime accepted the new period.
- [ ] Confirm measured/active period, not only configured period.
- [ ] Re-check 16 slaves in OP.
- [ ] Capture task jitter.
- [ ] Capture DC deviation.
- [ ] Capture WKC diagnostic where available.
- [ ] Capture lost-frame/link counters.
- [ ] Capture PDO loopback latency.
- [ ] Capture following error.
- [ ] Capture CPU load.
- [ ] Save raw diagnostics before changing configuration.

If the controller cannot accept or sustain a requested stress period, record `UNSUPPORTED`; if it accepts the configuration but violates a benchmark gate, record `FAIL`.

If the run is otherwise clean but one or more required metrics were not actually captured, record `INCOMPLETE` rather than `PASS`.

## 6. Loaded-runtime profile (optional second phase)

Do this only after the baseline matrix is complete.

Add representative non-motion workload while keeping the motion test unchanged:

- AC702: HMI/OPC UA/EtherNet-IP/logging/database traffic as relevant.
- ZMC: PC API polling, HMI/RTSys monitoring and production-equivalent communication.

Record this as a separate profile. Never mix loaded-runtime samples into the baseline dataset.

## Minimum artifacts for one valid row

A complete row should be traceable to:

1. run metadata/configuration;
2. raw task timing capture;
3. EtherCAT/DC diagnostics;
4. WKC diagnostic or explicit evidence source;
5. lost-frame/link diagnostics;
6. PDO loopback/timestamp capture;
7. motion trace containing command/actual/following-error data;
8. CPU/load capture;
9. normalized CSV generated from those sources.
