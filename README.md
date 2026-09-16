# plc_lab

Reproducible PLC and motion-controller laboratory projects.

The first suite compares **ZMotion ZMC432-16-V2** and **Inovance AC702** with the same 16-axis EtherCAT CSP/CST workload targeting Inovance SV680N drives.

## Benchmark matrix

| Controller | CSP/CST | 1000 us | 500 us | 250 us | 125 us |
|---|---|---|---|---|---|
| ZMC432-16-V2 | both | baseline | stress | stress | stress |
| AC702 | both | documented baseline | stress | stress | stress |

`UNSUPPORTED` is a valid laboratory result. A controller is not marked failed merely because a stress period is outside its documented operating point.

## Repository layout

```text
common/
  result_schema.json        Shared machine-readable result model
  result_template.csv       Flat CSV interchange template

docs/
  benchmark-spec.md         Test protocol, gates and fairness rules
  references.md             Vendor/manual references used by the implementation

projects/
  zmc432_16_v2/
    src/set_period.bas      Explicit SERVO_PERIOD setup helper
    src/benchmark.bas       16-axis CSP/CST ZBasic project
  ac702/
    src/Types.st
    src/GVL_Benchmark.st
    src/FB_BenchAxis.st
    src/PRG_Benchmark.st    InoProShop/CODESYS SoftMotion project

tools/
  analyze_results.py        Cross-controller statistics and PASS/FAIL/UNSUPPORTED report

tests/
  test_analyze_results.py   Analyzer regression tests
```

## What is measured

- active/measured cycle period;
- application task jitter;
- EtherCAT DC deviation;
- WKC correctness where the runtime exposes it;
- lost frames / link errors;
- explicit PDO loopback latency where a loopback fixture exists;
- following error;
- command/actual torque;
- CPU load;
- bus/axis faults and state.

Missing hardware diagnostics remain empty. Following error is **not** used as PDO latency, task jitter is **not** used as DC deviation, and link-loss counters are **not** relabeled as WKC.

## Quick start

### ZMC432-16-V2

1. Install the SV680N ESI in ZDevelop/RTSys and verify 16 drives.
2. Set `TARGET_PERIOD_US` in `projects/zmc432_16_v2/src/set_period.bas`.
3. Run it once, power-cycle the controller/drives, and verify `SERVO_PERIOD`.
4. Download `benchmark.bas` with `ARM_AXES=0` first and verify all nodes/diagnostics.
5. Arm CSP only after mechanical limits are checked; CST additionally requires a restrained fixture, torque/velocity limits and emergency stop/STO.
6. Save `?*ETHERCAT`, bus diagnostics and SCOPE exports for every run.

### AC702

1. Create an AC702 InoProShop project, scan the same 16 SV680N drives and enable DC.
2. Import the four ST source files in `projects/ac702/src/`.
3. Name the generated axes `Axis_00` ... `Axis_15` or edit their bindings in `PRG_Benchmark.st`.
4. Add/resolve the SysTime library and put `PRG_Benchmark` in the high-priority motion task.
5. Set the task interval and `g_udiRequestedCycleUs` to the same value.
6. Keep `g_xArmPower=FALSE`, `g_xArmCST=FALSE`, `g_lrCstCommandPct=0.0` for first download/diagnostics.
7. Export task, DC, EtherCAT and Trace data for every run.

The AC702 project follows the Inovance target definition of `SMC_SetTorque.fTorque`: **0.1% of rated torque per unit**. The operator-facing benchmark variable is ordinary percent and is converted internally.

## Analyze exported data

Transform vendor exports into `common/result_template.csv`, preserving empty fields for unavailable metrics, then run:

```bash
python tools/analyze_results.py results/*.csv
```

Optionally apply an application-unit following-error gate:

```bash
python tools/analyze_results.py results/*.csv --following-error-limit 0.1
```

JSON output:

```bash
python tools/analyze_results.py results/*.csv --json
```

The analyzer reports p99/max jitter, DC deviation, PDO latency, following error, CPU load, WKC/loss failures, missing metrics and final `PASS` / `FAIL` / `UNSUPPORTED` status.

## Development checks

The repository CI runs the portable parts of the suite:

```bash
python -m py_compile tools/analyze_results.py
python -m unittest discover -s tests -v
```

Vendor projects require ZDevelop/RTSys and InoProShop plus the real target packages/hardware, so CI does not claim to compile or hardware-qualify those files.

## Safety

The checked-in projects are intentionally disarmed. Do not enable nonzero CST torque on an unrestrained motor/joint. Configure drive-side positive/negative torque limits, velocity limits, fault reaction and STO/emergency-stop behavior before an energized CST run.
