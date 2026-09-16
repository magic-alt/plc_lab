# ZMC432-16-V2 vs AC702 EtherCAT Benchmark Protocol

## Objective

Compare the two controllers with the same 16-axis EtherCAT workload and report measured behavior, not brochure claims.

## DUT topology

`controller -> SV680N[0] -> ... -> SV680N[15]`

Use the same drives, motors, cables, PDO layout, firmware, mechanics, limits and power supply for both controllers. Record all versions in the run manifest.

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

AC702 documentation specifies 1 ms as the typical synchronization period for the published multi-axis case. Sub-1 ms AC702 rows are exploratory stress tests: `unsupported` is a valid result and must not be converted into a failure of the device.

ZMC `SERVO_PERIOD` is the bus/system cycle in microseconds. A changed value requires controller restart. The requested value is valid only when it is accepted by the controller firmware and the full 16-axis PDO workload remains stable.

## Workloads

### CSP

All 16 axes execute the same bounded position workload with phase offsets. Default engineering profile:

- amplitude: 5 deg output-side equivalent (adapt `UNITS`/electronic gearing)
- motion frequency: 0.5 Hz
- phase: `axis * 22.5 deg`
- acceleration/deceleration limited
- 30 s warm-up, 180 s capture

The vendor motion kernel may generate interpolation internally; the comparison therefore measures controller + EtherCAT execution under equivalent motion semantics, not identical source-code instruction count.

### CST

CST is **disarmed by default**. The checked-in configuration uses 0% torque. Nonzero torque may only be enabled on a mechanically safe fixture after drive-side positive/negative torque limits and velocity limits are configured.

Recommended loaded-fixture profile: +/-2% rated torque, 0.5 Hz square/triangle command, ramp >= 20 %/s, explicit velocity limit.

## Required metrics

Each result row uses the common CSV schema:

- `controller`, `firmware`, `mode`, `requested_cycle_us`, `actual_cycle_us`
- `sample_index`, `timestamp_us`, `task_delta_us`, `jitter_us`
- `dc_deviation_ns`
- `wkc_expected`, `wkc_actual`, `wkc_ok`
- `lost_frames`
- `axis`, `command_position`, `actual_position`, `following_error`
- `command_torque_pct`, `actual_torque_pct`
- `cpu_load_pct`
- `bus_state`, `axis_state`, `notes`

If a controller does not expose a metric cyclically, leave the field empty and collect the nearest vendor diagnostic separately. Do not synthesize missing hardware values.

## Pass/fail gates

A cycle/mode row is `PASS` only if all are true:

1. all 16 configured slaves reach OP and stay operational;
2. zero communication-loss events during capture;
3. no wrong-working-counter condition (where the runtime exposes WKC);
4. no drive fault or controller axis fault;
5. task jitter and DC deviation stay within the test's declared limits;
6. following-error limit is not exceeded;
7. controller CPU/load indication remains below the declared saturation limit;
8. the requested cycle equals the measured/active cycle.

`UNSUPPORTED` is distinct from `FAIL`.

## Suggested default limits

These are laboratory gates, not vendor guarantees:

- jitter p99 <= 10% of cycle
- jitter max <= 25% of cycle
- DC deviation p99 <= 5 us where measurable
- lost frames = 0
- bad WKC cycles = 0
- following error: application-specific; start with <= 0.1 deg equivalent
- CPU load p99 <= 80%

## Measurement sources

### ZMC432-16-V2

- `SERVO_PERIOD`: active controller/bus period
- `DPOS`, `MPOS`, `DRIVE_FE`, `DRIVE_TORQUE`: motion feedback
- `NODE_STATUS`, `DRIVE_STATUS`, `AXISSTATUS`: state
- `?*ETHERCAT`: node state and `Lostcount`
- RTSys/ZDevelop bus-node diagnostics: 300h..309h counters, especially link-loss counters
- `SCOPE`: cycle-synchronous capture for selected channels

### AC702

- InoProShop/CODESYS task monitor: task cycle and jitter
- EtherCAT Master DC Statistics: DC timing deviation distribution
- EtherCAT Master Status/Overview: LostFrameCount/RxErrorCount/TxErrorCount and slave errors
- EtherCAT Master IEC object / last error: wrong-working-counter condition
- PLCopen motion feedback / axis reference: following error and state
- controller display/runtime monitor: CPU load

## Run procedure

1. Record controller, drive and motor firmware versions.
2. Verify identical PDOs and DC configuration.
3. Start with one axis at 1 ms, zero/non-moving command.
4. Expand to 16 axes at 1 ms.
5. Run CSP baseline.
6. Run CST only after fixture and limits are verified.
7. Move to shorter periods one step at a time.
8. After any bus fault, stop, save diagnostics, power-cycle if required, and start a new run ID.
9. Never reuse a failed run after topology/PDO/period changes.

## Fairness rules

- Same drive firmware and EtherCAT XML/ESI revision.
- Same PDO byte count and ordering where possible.
- Same DC reference strategy.
- Same cable chain and cable lengths.
- No HMI/OPC UA/database traffic during baseline runs; add a separate `loaded-runtime` profile later.
- Store raw data before calculating summary statistics.
