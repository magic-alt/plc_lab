# Inovance AC702 benchmark project

This directory contains importable IEC 61131-3 Structured Text for the AC702/InoProShop side of the common 16-axis benchmark.

## Vendor/runtime assumptions

- InoProShop (CODESYS based) with the matching AC700 target package installed.
- 16 EtherCAT axes configured from the same SV680N ESI revision used for the ZMC test.
- Distributed Clocks enabled and PDOs kept equivalent between controllers where the two stacks permit it.
- AC702's published multi-axis synchronization point is 1 ms. The 500/250/125 us rows are **stress experiments**, not claimed supported operating points.

## Import / configure

1. Create an AC702 project in InoProShop.
2. Scan/import all 16 SV680N slaves under the EtherCAT master.
3. Configure DC and the high-priority cyclic motion task.
4. Import `Types.st`, `GVL_Benchmark.st`, `FB_BenchAxis.st`, and `PRG_Benchmark.st`.
5. Name the generated axis objects `Axis_00` ... `Axis_15`, or edit the 16 bindings in `PRG_Benchmark.st`.
6. Add/resolve the `SysTimeCore`/`SysTime` library used by `SysTimeGetUs`.
7. Map the PDOs needed by the selected mode.
8. Build with `g_xArmPower=FALSE` and `g_xArmCST=FALSE` first.

### CSP PDO minimum

Keep the standard CiA 402 CSP objects required by InoProShop axis mapping: control/status word, mode of operation/display, target/actual position, plus the drive feedback used for following-error diagnostics.

### CST PDO minimum and scaling

The Inovance AC700/medium-PLC torque-mode guide requires synchronous torque mode and calls out target torque `0x6071`; `MC_TorqueControl` additionally requires maximum profile velocity `0x607F`.

The checked-in implementation uses:

```text
SMC_SetControllerMode(SMC_torque)
        -> SMC_SetTorque
```

**Important target-specific difference:** the Inovance guide defines `SMC_SetTorque.fTorque` in **0.1% rated-torque units**. `GVL_Benchmark.g_lrCstCommandPct` is exposed in ordinary percent; `FB_BenchAxis` converts it with `fTorque = percent * 10`. Thus 2.0% becomes `20.0` at `SMC_SetTorque`.

The upstream generic CODESYS help describes a different physical-unit convention; for AC702 this project follows the Inovance target documentation. Verify the actual-torque display/scaling against drive object `0x6077` and the InoProShop commissioning view before using `actual_torque_pct` in a report.

## Task configuration

Create one high-priority cyclic task and attach `PRG_Benchmark` to it. Its interval must equal `g_udiRequestedCycleUs`.

Run separate configurations at:

- 1000 us — documented baseline;
- 500 us — stress;
- 250 us — stress;
- 125 us — stress.

A configured interval is not a successful measurement by itself. Save task statistics and EtherCAT diagnostics for every run.

## Measurement sources

- `SysTimeGetUs`: application-observed task period and jitter.
- InoProShop Task Configuration/Monitoring: task execution time and jitter.
- EtherCAT Master -> DC Statistics: DC deviation distribution.
- EtherCAT Master status/overview: lost-frame and link/error counters.
- EtherCAT master IEC diagnostics / `LastError`: wrong-working-counter conditions.
- SoftMotion `MC_ReadActualPosition`, `SMC_GetTrackingError`, `MC_ReadActualTorque`: motion feedback.
- AC702 display/runtime monitor: CPU load.
- `pdo_latency_us`: only from an explicit PDO loopback / timestamp fixture; leave blank otherwise.

The ST project intentionally does not fabricate WKC, DC, PDO-latency or CPU values. Bind a real runtime diagnostic if available; otherwise merge the exported runtime diagnostics into the common CSV offline.

## Safety

`g_xArmPower` and `g_xArmCST` default to `FALSE`, and `g_lrCstCommandPct` defaults to `0.0`. Keep drive torque/velocity limits and STO/emergency stop active. Never enable CST on an unrestrained motor or joint.
