PROGRAM PRG_Benchmark
VAR
    fbAxis : ARRAY[0..15] OF FB_BenchAxis;
    rtStart : R_TRIG;
    stNowUs : SysTime;
    uiAxis : UINT;
    xEnablePower : BOOL;
    xTorqueEnable : BOOL;
    xMovePulse : BOOL;
    xCommandStarted : BOOL := FALSE;
    xAllPowerReady : BOOL;
    xAllModeReady : BOOL;
    xAllCommandDone : BOOL;
    xAnyAxisError : BOOL;
    udiCstTicks : UDINT := 0;
    udiTicksPerHalfPeriod : UDINT := 1000;
    uiStopTicks : UINT := 0;
    lrSignedTorquePct : LREAL;
    lrAbsJitterUs : LREAL;
END_VAR

// -----------------------------------------------------------------------------
// Task timing. Put this POU in the same high-priority cyclic task as EtherCAT
// motion. SysTimeGetUs() returns a monotonic microsecond tick.
// -----------------------------------------------------------------------------
SysTimeGetUs(stNowUs);
GVL_Benchmark.g_uliNowUs := stNowUs;
IF GVL_Benchmark.g_uliPreviousUs <> 0 THEN
    GVL_Benchmark.g_lrTaskDeltaUs := ULINT_TO_LREAL(stNowUs - GVL_Benchmark.g_uliPreviousUs);
    GVL_Benchmark.g_lrTaskJitterUs := GVL_Benchmark.g_lrTaskDeltaUs - UDINT_TO_LREAL(GVL_Benchmark.g_udiRequestedCycleUs);
    lrAbsJitterUs := ABS(GVL_Benchmark.g_lrTaskJitterUs);
    IF lrAbsJitterUs > GVL_Benchmark.g_lrTaskJitterAbsMaxUs THEN
        GVL_Benchmark.g_lrTaskJitterAbsMaxUs := lrAbsJitterUs;
    END_IF
END_IF
GVL_Benchmark.g_uliPreviousUs := stNowUs;
GVL_Benchmark.g_udiSampleCounter := GVL_Benchmark.g_udiSampleCounter + 1;

rtStart(CLK := GVL_Benchmark.g_xStart);
xMovePulse := FALSE;
xEnablePower := FALSE;
xTorqueEnable := FALSE;

IF GVL_Benchmark.g_xStop THEN
    GVL_Benchmark.g_eState := E_BenchState.STOPPING;
END_IF

// -----------------------------------------------------------------------------
// Generate commands for this scan. Physical power and non-zero CST remain
// impossible until the explicit arm variables are set by the operator.
// -----------------------------------------------------------------------------
CASE GVL_Benchmark.g_eState OF
    E_BenchState.IDLE:
        GVL_Benchmark.g_xRunComplete := FALSE;
        GVL_Benchmark.g_xRunError := FALSE;
        GVL_Benchmark.g_uiCompletedCycles := 0;
        GVL_Benchmark.g_lrTaskJitterAbsMaxUs := 0.0;
        xCommandStarted := FALSE;
        udiCstTicks := 0;
        uiStopTicks := 0;
        IF rtStart.Q THEN
            GVL_Benchmark.g_eState := E_BenchState.CHECK_CONFIG;
        END_IF

    E_BenchState.CHECK_CONFIG:
        CASE GVL_Benchmark.g_udiRequestedCycleUs OF
            1000, 500, 250, 125:
                GVL_Benchmark.g_eState := E_BenchState.WAIT_ARM;
            ELSE
                GVL_Benchmark.g_xRunError := TRUE;
                GVL_Benchmark.g_eState := E_BenchState.ERROR;
        END_CASE

    E_BenchState.WAIT_ARM:
        IF GVL_Benchmark.g_xArmPower THEN
            IF (GVL_Benchmark.g_eMode = E_BenchMode.CSP) OR GVL_Benchmark.g_xArmCST THEN
                GVL_Benchmark.g_eState := E_BenchState.ENABLE_AXES;
            END_IF
        END_IF

    E_BenchState.ENABLE_AXES:
        xEnablePower := TRUE;

    E_BenchState.RUN_CSP_A:
        xEnablePower := TRUE;
        IF NOT xCommandStarted THEN
            FOR uiAxis := 0 TO 15 DO
                IF (uiAxis MOD 2) = 0 THEN
                    GVL_Benchmark.g_alrTargetPosition[uiAxis] := GVL_Benchmark.g_lrPositionAmplitude;
                ELSE
                    GVL_Benchmark.g_alrTargetPosition[uiAxis] := -GVL_Benchmark.g_lrPositionAmplitude;
                END_IF
            END_FOR
            xMovePulse := TRUE;
            xCommandStarted := TRUE;
        END_IF

    E_BenchState.RUN_CSP_B:
        xEnablePower := TRUE;
        IF NOT xCommandStarted THEN
            FOR uiAxis := 0 TO 15 DO
                IF (uiAxis MOD 2) = 0 THEN
                    GVL_Benchmark.g_alrTargetPosition[uiAxis] := -GVL_Benchmark.g_lrPositionAmplitude;
                ELSE
                    GVL_Benchmark.g_alrTargetPosition[uiAxis] := GVL_Benchmark.g_lrPositionAmplitude;
                END_IF
            END_FOR
            xMovePulse := TRUE;
            xCommandStarted := TRUE;
        END_IF

    E_BenchState.RUN_CST_A:
        xEnablePower := TRUE;
        xTorqueEnable := GVL_Benchmark.g_xArmCST;
        lrSignedTorquePct := GVL_Benchmark.g_lrCstCommandPct;
        FOR uiAxis := 0 TO 15 DO
            IF (uiAxis MOD 2) = 0 THEN
                GVL_Benchmark.g_alrCommandTorquePct[uiAxis] := lrSignedTorquePct;
            ELSE
                GVL_Benchmark.g_alrCommandTorquePct[uiAxis] := -lrSignedTorquePct;
            END_IF
        END_FOR

    E_BenchState.RUN_CST_B:
        xEnablePower := TRUE;
        xTorqueEnable := GVL_Benchmark.g_xArmCST;
        lrSignedTorquePct := GVL_Benchmark.g_lrCstCommandPct;
        FOR uiAxis := 0 TO 15 DO
            IF (uiAxis MOD 2) = 0 THEN
                GVL_Benchmark.g_alrCommandTorquePct[uiAxis] := -lrSignedTorquePct;
            ELSE
                GVL_Benchmark.g_alrCommandTorquePct[uiAxis] := lrSignedTorquePct;
            END_IF
        END_FOR

    E_BenchState.STOPPING:
        // First command 0% while still powered, then remove power after two task
        // scans. Drive-side limits / STO remain the primary safety mechanisms.
        FOR uiAxis := 0 TO 15 DO
            GVL_Benchmark.g_alrCommandTorquePct[uiAxis] := 0.0;
        END_FOR
        IF uiStopTicks < 2 THEN
            xEnablePower := GVL_Benchmark.g_xArmPower;
            xTorqueEnable := (GVL_Benchmark.g_eMode = E_BenchMode.CST) AND GVL_Benchmark.g_xArmCST;
        ELSE
            xEnablePower := FALSE;
            xTorqueEnable := FALSE;
        END_IF
        uiStopTicks := uiStopTicks + 1;

    E_BenchState.DONE:
        GVL_Benchmark.g_xRunComplete := TRUE;

    E_BenchState.ERROR:
        GVL_Benchmark.g_xRunError := TRUE;
END_CASE

// -----------------------------------------------------------------------------
// Axis bindings. Name scanned InoProShop axis objects Axis_00..Axis_15, or edit
// only these calls to match the generated device-tree identifiers.
// -----------------------------------------------------------------------------
fbAxis[0](Axis := Axis_00, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[0], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[0]);
fbAxis[1](Axis := Axis_01, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[1], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[1]);
fbAxis[2](Axis := Axis_02, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[2], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[2]);
fbAxis[3](Axis := Axis_03, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[3], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[3]);
fbAxis[4](Axis := Axis_04, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[4], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[4]);
fbAxis[5](Axis := Axis_05, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[5], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[5]);
fbAxis[6](Axis := Axis_06, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[6], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[6]);
fbAxis[7](Axis := Axis_07, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[7], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[7]);
fbAxis[8](Axis := Axis_08, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[8], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[8]);
fbAxis[9](Axis := Axis_09, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[9], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[9]);
fbAxis[10](Axis := Axis_10, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[10], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[10]);
fbAxis[11](Axis := Axis_11, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[11], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[11]);
fbAxis[12](Axis := Axis_12, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[12], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[12]);
fbAxis[13](Axis := Axis_13, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[13], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[13]);
fbAxis[14](Axis := Axis_14, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[14], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[14]);
fbAxis[15](Axis := Axis_15, xEnablePower := xEnablePower, eMode := GVL_Benchmark.g_eMode, xMoveExecute := xMovePulse, lrTargetPosition := GVL_Benchmark.g_alrTargetPosition[15], lrVelocity := GVL_Benchmark.g_lrVelocity, lrAcceleration := GVL_Benchmark.g_lrAcceleration, lrDeceleration := GVL_Benchmark.g_lrDeceleration, lrJerk := GVL_Benchmark.g_lrJerk, xTorqueEnable := xTorqueEnable, lrTorquePct := GVL_Benchmark.g_alrCommandTorquePct[15]);

// Collect per-axis telemetry and state for Trace/export.
xAllPowerReady := TRUE;
xAllModeReady := TRUE;
xAllCommandDone := TRUE;
xAnyAxisError := FALSE;
FOR uiAxis := 0 TO 15 DO
    GVL_Benchmark.g_alrActualPosition[uiAxis] := fbAxis[uiAxis].lrActualPosition;
    GVL_Benchmark.g_alrTrackingError[uiAxis] := fbAxis[uiAxis].lrTrackingError;
    GVL_Benchmark.g_alrActualTorquePct[uiAxis] := fbAxis[uiAxis].lrActualTorquePct;
    GVL_Benchmark.g_axAxisPowerReady[uiAxis] := fbAxis[uiAxis].xPowerReady;
    GVL_Benchmark.g_axAxisModeReady[uiAxis] := fbAxis[uiAxis].xModeReady;
    GVL_Benchmark.g_axAxisCommandDone[uiAxis] := fbAxis[uiAxis].xCommandDone;
    GVL_Benchmark.g_axAxisError[uiAxis] := fbAxis[uiAxis].xError;

    xAllPowerReady := xAllPowerReady AND fbAxis[uiAxis].xPowerReady;
    xAllModeReady := xAllModeReady AND fbAxis[uiAxis].xModeReady;
    xAllCommandDone := xAllCommandDone AND fbAxis[uiAxis].xCommandDone;
    xAnyAxisError := xAnyAxisError OR fbAxis[uiAxis].xError;
END_FOR

IF xAnyAxisError AND (GVL_Benchmark.g_eState <> E_BenchState.STOPPING) THEN
    GVL_Benchmark.g_xRunError := TRUE;
    GVL_Benchmark.g_eState := E_BenchState.ERROR;
END_IF

// -----------------------------------------------------------------------------
// State transitions use outputs from this scan.
// -----------------------------------------------------------------------------
CASE GVL_Benchmark.g_eState OF
    E_BenchState.ENABLE_AXES:
        IF xAllPowerReady AND xAllModeReady THEN
            xCommandStarted := FALSE;
            IF GVL_Benchmark.g_eMode = E_BenchMode.CSP THEN
                GVL_Benchmark.g_eState := E_BenchState.RUN_CSP_A;
            ELSE
                udiCstTicks := 0;
                GVL_Benchmark.g_eState := E_BenchState.RUN_CST_A;
            END_IF
        END_IF

    E_BenchState.RUN_CSP_A:
        IF xCommandStarted AND xAllCommandDone THEN
            xCommandStarted := FALSE;
            GVL_Benchmark.g_eState := E_BenchState.RUN_CSP_B;
        END_IF

    E_BenchState.RUN_CSP_B:
        IF xCommandStarted AND xAllCommandDone THEN
            xCommandStarted := FALSE;
            GVL_Benchmark.g_uiCompletedCycles := GVL_Benchmark.g_uiCompletedCycles + 1;
            IF GVL_Benchmark.g_uiCompletedCycles >= GVL_Benchmark.g_uiCycles THEN
                GVL_Benchmark.g_eState := E_BenchState.STOPPING;
            ELSE
                GVL_Benchmark.g_eState := E_BenchState.RUN_CSP_A;
            END_IF
        END_IF

    E_BenchState.RUN_CST_A, E_BenchState.RUN_CST_B:
        IF GVL_Benchmark.g_udiRequestedCycleUs > 0 THEN
            // One second per torque polarity. This is an integer number of task
            // cycles for all four benchmark periods.
            udiTicksPerHalfPeriod := 1000000 / GVL_Benchmark.g_udiRequestedCycleUs;
            IF udiTicksPerHalfPeriod = 0 THEN
                udiTicksPerHalfPeriod := 1;
            END_IF
        END_IF
        udiCstTicks := udiCstTicks + 1;
        IF udiCstTicks >= udiTicksPerHalfPeriod THEN
            udiCstTicks := 0;
            IF GVL_Benchmark.g_eState = E_BenchState.RUN_CST_A THEN
                GVL_Benchmark.g_eState := E_BenchState.RUN_CST_B;
            ELSE
                GVL_Benchmark.g_uiCompletedCycles := GVL_Benchmark.g_uiCompletedCycles + 1;
                IF GVL_Benchmark.g_uiCompletedCycles >= GVL_Benchmark.g_uiCycles THEN
                    GVL_Benchmark.g_eState := E_BenchState.STOPPING;
                ELSE
                    GVL_Benchmark.g_eState := E_BenchState.RUN_CST_A;
                END_IF
            END_IF
        END_IF

    E_BenchState.STOPPING:
        IF uiStopTicks >= 10 THEN
            GVL_Benchmark.g_xRunComplete := NOT GVL_Benchmark.g_xRunError;
            GVL_Benchmark.g_eState := E_BenchState.DONE;
        END_IF
END_CASE
