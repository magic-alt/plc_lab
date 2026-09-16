{attribute 'qualified_only'}
VAR_GLOBAL CONSTANT
    gc_uiAxisCount : UINT := 16;
    gc_udiDefaultCycleUs : UDINT := 1000;
END_VAR

VAR_GLOBAL
    // Safety: checked-in defaults never enable a physical power stage.
    g_xArmPower : BOOL := FALSE;
    g_xArmCST : BOOL := FALSE;
    g_xStart : BOOL := FALSE;
    g_xStop : BOOL := FALSE;

    // Run configuration. The task interval in InoProShop must match this value.
    g_eMode : E_BenchMode := E_BenchMode.CSP;
    g_udiRequestedCycleUs : UDINT := 1000;
    g_lrPositionAmplitude : LREAL := 5.0;       // axis engineering units, normally deg at output-equivalent scaling
    g_lrVelocity : LREAL := 20.0;              // engineering units/s
    g_lrAcceleration : LREAL := 200.0;         // engineering units/s^2
    g_lrDeceleration : LREAL := 200.0;
    g_lrJerk : LREAL := 0.0;
    g_lrCstCommandPct : LREAL := 0.0;           // percent rated torque; checked-in safe value, first loaded run <= 2%
    g_uiCycles : UINT := 20;

    // State/status exported to Trace / watch / CSV.
    g_eState : E_BenchState := E_BenchState.IDLE;
    g_xRunComplete : BOOL := FALSE;
    g_xRunError : BOOL := FALSE;
    g_uiCompletedCycles : UINT := 0;
    g_udiSampleCounter : UDINT := 0;

    // Task timing captured with SysTimeGetUs().
    g_uliNowUs : ULINT := 0;
    g_uliPreviousUs : ULINT := 0;
    g_lrTaskDeltaUs : LREAL := 0.0;
    g_lrTaskJitterUs : LREAL := 0.0;
    g_lrTaskJitterAbsMaxUs : LREAL := 0.0;

    // Runtime-specific diagnostics. Leave invalid unless explicitly bound from the AC702 target/runtime.
    g_xDcDeviationValid : BOOL := FALSE;
    g_lrDcDeviationNs : LREAL := 0.0;
    g_xWkcValid : BOOL := FALSE;
    g_diWkcExpected : DINT := 0;
    g_diWkcActual : DINT := 0;
    g_xWkcOk : BOOL := TRUE;
    g_xLostFramesValid : BOOL := FALSE;
    g_udiLostFrames : UDINT := 0;
    g_xCpuLoadValid : BOOL := FALSE;
    g_lrCpuLoadPct : LREAL := 0.0;
    g_xPdoLatencyValid : BOOL := FALSE;
    g_lrPdoLatencyUs : LREAL := 0.0;

    // Per-axis values. Capture these arrays with Trace/export.
    g_alrTargetPosition : ARRAY[0..15] OF LREAL;
    g_alrActualPosition : ARRAY[0..15] OF LREAL;
    g_alrTrackingError : ARRAY[0..15] OF LREAL;
    g_alrCommandTorquePct : ARRAY[0..15] OF LREAL;
    g_alrActualTorquePct : ARRAY[0..15] OF LREAL;
    g_axAxisPowerReady : ARRAY[0..15] OF BOOL;
    g_axAxisModeReady : ARRAY[0..15] OF BOOL;
    g_axAxisCommandDone : ARRAY[0..15] OF BOOL;
    g_axAxisError : ARRAY[0..15] OF BOOL;
END_VAR
