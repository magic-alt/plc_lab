# Inovance AC702 benchmark project

This directory contains importable IEC 61131-3 Structured Text source for the AC702/InoProShop side of the benchmark.

## Vendor/runtime assumptions

- InoProShop (CODESYS based), AC700 target package installed.
- 16 EtherCAT axes configured from the same SV680N ESI used for the ZMC test.
- EtherCAT Distributed Clocks enabled and axis PDOs kept identical between controllers where the vendor stacks allow it.
- AC702's documented multi-axis synchronization point is 1 ms. 500/250/125 us configurations are **stress experiments**, not claimed supported operating points.

## Import / configure

1. Create an AC702 project in InoProShop.
2. Scan/import all 16 SV680N slaves under the EtherCAT master.
3. Configure DC and the cyclic task.
4. Import the ST objects under `src/`.
5. Edit `AxisBindings.st` so `Axis_00..Axis_15` match the generated InoProShop axis object names.
6. Add the `SysTimeCore` library. The instrumentation uses `SysTimeGetUs` for task-period/jitter measurement.
7. Map PDOs needed by the selected mode.

### CSP PDO minimum

Keep the standard CiA 402 CSP objects required by the InoProShop axis mapping, including control/status word, modes of operation/display, target/actual position and any following-error signal used by your axis object.

### CST PDO minimum

Inovance's AC700 torque-mode application guide requires synchronous torque mode and specifically calls out target torque `0x6071`; `MC_TorqueControl` also requires maximum profile velocity `0x607F`. The official guide shows `SMC_SetControllerMode` followed by `SMC_SetTorque` or `MC_TorqueControl`.

## Task configuration

Create one high-priority cyclic motion task and attach `PRG_Benchmark` to it.

Run separate projects/configurations at:

- 1000 us — documented baseline
- 500 us — stress
- 250 us — stress
- 125 us — stress

Do not silently accept a configured period as a valid result. Save InoProShop task statistics and EtherCAT DC statistics for every run.

## Measurement sources

- `SysTimeGetUs`: application-observed task period and jitter.
- InoProShop Task Configuration/Monitoring: task execution time and jitter.
- EtherCAT Master -> DC Statistics: DC deviation histogram.
- EtherCAT Master -> Status/Overview: LostFrameCount, TxErrorCount, RxErrorCount and slave CRC/error counters.
- EtherCAT master IEC object / `LastError`: detect `WRONG_WORKING_COUNTER`.
- AC702 front display/runtime monitor: CPU load.

The ST logger deliberately does not invent a WKC or CPU-load value. If your installed target exposes these as IEC variables, bind them in `PRG_Benchmark` and export them; otherwise use the runtime diagnostic export and merge the fields during analysis.

## Safety

`g_xArmPower` and `g_xArmCST` default to `FALSE`. Keep drive-side torque/velocity limits active. Never enable the checked-in CST sequence on a free-spinning joint or unrestrained motor.
