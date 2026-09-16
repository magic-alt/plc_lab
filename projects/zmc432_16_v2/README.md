# ZMC432-16-V2 benchmark project

This is the ZDevelop/RTSys ZBasic side of the common 16-axis EtherCAT benchmark.

## Prerequisites

- ZMC432-16-V2 with EtherCAT firmware supporting the requested `SERVO_PERIOD`.
- 16 EtherCAT servo axes. The target lab topology is 16 x Inovance SV680N.
- Correct ESI/XML installed in ZDevelop/RTSys.
- Drive-side torque and velocity limits configured before any CST test.

## Files

- `src/benchmark.bas`: bus discovery/mapping, CSP/CST setup, safe arming, deterministic workload and diagnostics.
- `src/set_period.bas`: explicit period configuration helper. Period changes require a controller power cycle.

## Important ZMotion semantics used

- `SLOT_SCAN(0)` / `SLOT_START(0)` initialize the EtherCAT bus.
- `AXIS_ADDRESS()` maps controller axes to EtherCAT drives.
- `ATYPE=65` is CSP, `66` CSV and `67` CST.
- `DRIVE_PROFILE=-1` uses the drive/default PDO profile; official examples also show profile 30 for torque mode. Validate the SV680N PDO before CST.
- `SERVO_PERIOD` is in microseconds.
- `DRIVE_FE`, `DRIVE_TORQUE`, `DRIVE_STATUS`, `AXISSTATUS` provide useful cyclic diagnostics.
- `?*ETHERCAT` in the online command window prints node state and `Lostcount`; the bus-node diagnostic view exposes 300h..309h error/link-loss counters.

## Bring-up order

1. Leave `ARM_AXES = 0` and `ARM_CST = 0`.
2. Set the desired period with `set_period.bas`, power-cycle the controller and drives, then verify `SERVO_PERIOD`.
3. Run `benchmark.bas`; confirm exactly 16 drive axes are discovered and all nodes reach OP.
4. Run `?*ETHERCAT` and save the output.
5. Set `ARM_AXES = 1` only after limits and mechanics are verified.
6. Run CSP first at 1000 us.
7. CST remains zero torque until `ARM_CST = 1`; only enable it on a safe fixture.
8. Repeat at 500/250/125 us only when the firmware accepts the value and the previous step has zero packet loss.

## Data capture

For each run save:

- pre/post `?*ETHERCAT` output;
- bus-node diagnostics (especially 308h/309h link-loss counters);
- RTSys/ZDevelop SCOPE export for DPOS/MPOS/DRIVE_FE/DRIVE_TORQUE on the selected axes;
- controller firmware/version and active `SERVO_PERIOD`.

The repository analysis tool intentionally leaves WKC/DC fields empty if the controller does not expose them directly. Do not manufacture equivalent values from unrelated counters.
