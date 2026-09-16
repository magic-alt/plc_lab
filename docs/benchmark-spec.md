# ZMC432-16-V2 vs AC702 EtherCAT Benchmark Protocol

## Objective

Compare both controllers with the same 16-axis EtherCAT workload and report measured behavior rather than brochure claims.

DUT topology:

```text
controller -> SV680N[0] -> ... -> SV680N[15]
```

Use the same drives, motors, ESI revision, PDO layout, cables, mechanics, limits, power supply and firmware for both controllers. Record all versions in each run manifest.

## Test matrix

| mode | requested cycle | duration | classification |
|---|---:|---:|---|
| CSP | 1000 us | 180 s | baseline |
| CSP | 500 us | 180 s | stress |
| CSP | 250 us | 180 s | stress |
| CSP | 125 us | 180 s | stress |
| CST | 1000 us | 180 s | baseline |
| CST | 500 us | 180 s | stress |
| CST | 250 us | 180 s | stress |
| CST | 125 us | 180 s | stress |

AC702 documentation gives 1 ms as the published multi-axis synchronization point. Sub-1 ms AC702 rows are exploratory stress tests: `UNSUPPORTED` is a valid result and is not converted into a device failure.

ZMC `SERVO_PERIOD` is configured in microseconds and requires a controller restart after a change. An accepted configuration is still valid only if the complete 16-axis PDO workload remains stable.

## Workloads

### CSP

All 16 axes execute the same bounded position workload with alternating signs:

- amplitude: +/-5 deg output-side equivalent after engineering-unit scaling;
- velocity: 20 deg/s equivalent;
- acceleration/deceleration: 200 deg/s^2 equivalent;
- odd/even axes move in opposite directions;
- 30 s warm-up followed by the measurement window.

The two vendor motion kernels may interpolate differently internally. The benchmark therefore compares equivalent motion semantics, not identical source-instruction counts.

### CST

CST is **disarmed and 0% torque by default**. Nonzero torque may only be enabled on a mechanically safe fixture after drive positive/negative torque and velocity limits are configured.

Recommended first loaded profile:

- +/-2% rated torque;
- polarity reversal every 1 s;
- odd/even axes use opposite signs;
- STO / external emergency stop available.

For AC702/InoProShop, the Inovance application guide defines `SMC_SetTorque.fTorque` in **0.1% rated-torque units**; the checked-in project exposes percent to the operator and performs the x10 conversion internally.

## Required metrics

Common CSV columns:

- identity: `controller`, firmware versions, `mode`, `requested_cycle_us`, `actual_cycle_us`;
- scheduling: `timestamp_us`, `task_delta_us`, `jitter_us`;
- EtherCAT: `dc_deviation_ns`, `wkc_expected`, `wkc_actual`, `wkc_ok`, `lost_frames`;
- latency: `pdo_latency_us`;
- motion: command/actual position, `following_error`, command/actual torque;
- load/state: `cpu_load_pct`, bus state, axis state and notes.

A metric that the target does not expose must be left empty. Never synthesize a value from a different diagnostic.

### PDO latency definition

`pdo_latency_us` is optional and only valid when measured by an explicit loopback or hardware timestamp path, for example:

```text
master output PDO bit/word
  -> EtherCAT slave / remote I/O
  -> physical or firmware loopback
  -> input PDO
  -> master timestamp
```

Report round-trip latency unless the fixture provides independently timestamped one-way latency. Record the method in `notes`. **Following error is not PDO latency**, task jitter is not DC deviation, and link-loss counters are not WKC.

## Pass/fail gates

A cycle/mode row is `PASS` only when all applicable measurements satisfy the declared gates and all 16 configured slaves remain operational. `UNSUPPORTED` is distinct from `FAIL`.

Default laboratory gates (not vendor guarantees):

- measured/active cycle matches the requested cycle;
- jitter p99 <= 10% of cycle;
- jitter max <= 25% of cycle;
- DC deviation p99 <= 5 us where measurable;
- lost frames = 0;
- bad WKC samples = 0 where WKC is exposed;
- following error <= application-specific limit (start with 0.1 deg equivalent if appropriate);
- CPU load p99 <= 80% where exposed;
- no drive/controller fault.

## Measurement sources

### ZMC432-16-V2

- `SERVO_PERIOD`: configured/active system-bus period;
- `DPOS`, `MPOS`, `DRIVE_FE`, `DRIVE_TORQUE`: cyclic motion feedback;
- `NODE_STATUS`, `DRIVE_STATUS`, `AXISSTATUS`: state;
- `?*ETHERCAT`: node state and `Lostcount`;
- RTSys/ZDevelop bus-node diagnostics: 300h..309h counters, especially link-loss counters;
- SCOPE/trace export for selected cyclic channels.

Do not label a ZMotion loss counter as WKC unless the firmware/runtime explicitly provides WKC semantics.

### AC702

- `SysTimeGetUs`: application-observed task period/jitter;
- InoProShop/CODESYS task monitor: cycle/execution-time statistics;
- EtherCAT Master DC Statistics: DC timing deviation;
- EtherCAT Master status/overview: lost-frame and link/error counters;
- EtherCAT master IEC diagnostics / last error: wrong-working-counter conditions;
- SoftMotion axis diagnostics: actual position, tracking error and torque;
- AC702 display/runtime monitor: CPU load.

## Run procedure

1. Record controller, drive, ESI and motor firmware/version information.
2. Verify identical PDOs and DC strategy.
3. Start with one axis at 1 ms and a zero/non-moving command.
4. Expand to 16 axes at 1 ms.
5. Run CSP baseline.
6. Run CST only after fixture, STO and limits are verified.
7. Move to 500/250/125 us one step at a time.
8. Save raw data and diagnostics before calculating summaries.
9. After a bus fault, topology/PDO/period change or power cycle, start a new run ID.

## Fairness rules

- Same drive firmware and ESI revision.
- Same PDO byte count/order where both stacks permit it.
- Same DC-reference strategy where configurable.
- Same cable chain and lengths.
- No HMI/OPC UA/database traffic during baseline runs; add a separate `loaded-runtime` profile later.
- Never edit raw captures after collection; transform them into the common CSV in a separate step.
