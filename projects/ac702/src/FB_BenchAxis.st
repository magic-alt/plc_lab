FUNCTION_BLOCK FB_BenchAxis
VAR_IN_OUT
    Axis : AXIS_REF_SM3;
END_VAR
VAR_INPUT
    xEnablePower : BOOL;
    eMode : E_BenchMode;
    xMoveExecute : BOOL;
    lrTargetPosition : LREAL;
    lrVelocity : LREAL;
    lrAcceleration : LREAL;
    lrDeceleration : LREAL;
    lrJerk : LREAL;
    xTorqueEnable : BOOL;
    lrTorquePct : LREAL;
END_VAR
VAR_OUTPUT
    xPowerReady : BOOL;
    xModeReady : BOOL;
    xCommandDone : BOOL;
    xError : BOOL;
    lrActualPosition : LREAL;
    lrTrackingError : LREAL;
    lrActualTorquePct : LREAL;
END_VAR
VAR
    fbPower : MC_Power;
    fbSetMode : SMC_SetControllerMode;
    fbMoveAbsolute : MC_MoveAbsolute;
    fbSetTorque : SMC_SetTorque;
    fbReadPosition : MC_ReadActualPosition;
    fbTrackingError : SMC_GetTrackingError;
    fbReadTorque : MC_ReadActualTorque;
    rtMove : R_TRIG;
    rtTorqueEnable : R_TRIG;

    eRequestedControllerMode : SMC_CONTROLLER_MODE := SMC_position;
    xMoveActive : BOOL;
    xTorqueWritePulse : BOOL;
    xMoveDoneLatched : BOOL := FALSE;
    xTorqueCommanded : BOOL := FALSE;
    lrLastTorquePct : LREAL := 0.0;
END_VAR

// Power-stage control follows the SoftMotion MC_Power interface.
fbPower(
    Axis := Axis,
    Enable := TRUE,
    bRegulatorOn := xEnablePower,
    bDriveStart := xEnablePower
);
xPowerReady := fbPower.Status;

IF eMode = E_BenchMode.CST THEN
    eRequestedControllerMode := SMC_torque;
ELSE
    eRequestedControllerMode := SMC_position;
END_IF

// Switch the controller mode before issuing the setpoint command.
fbSetMode(
    Axis := Axis,
    bExecute := xEnablePower,
    nControllerMode := eRequestedControllerMode
);
xModeReady := fbSetMode.bDone;

// xMoveExecute is a one-task-cycle trigger. Latch completion so all 16 axes do
// not have to assert MC_MoveAbsolute.Done in the exact same PLC scan.
rtMove(CLK := xMoveExecute);
IF rtMove.Q THEN
    xMoveDoneLatched := FALSE;
END_IF

xMoveActive := xEnablePower AND xModeReady AND (eMode = E_BenchMode.CSP) AND xMoveExecute;
fbMoveAbsolute(
    Axis := Axis,
    Execute := xMoveActive,
    Position := lrTargetPosition,
    Velocity := lrVelocity,
    Acceleration := lrAcceleration,
    Deceleration := lrDeceleration,
    Jerk := lrJerk,
    BufferMode := MC_BUFFER_MODE.Aborting
);
IF fbMoveAbsolute.Done THEN
    xMoveDoneLatched := TRUE;
END_IF

// IMPORTANT: use the Inovance target semantics, not the generic upstream
// CODESYS documentation. The AC700/medium-PLC application guide specifies
// SMC_SetTorque.fTorque in 0.1% rated-torque units and bEnable as a rising-edge
// command. A 2.0% request therefore becomes fTorque=20.0.
rtTorqueEnable(CLK := xTorqueEnable);
xTorqueWritePulse := FALSE;
IF xEnablePower AND xModeReady AND (eMode = E_BenchMode.CST) AND xTorqueEnable THEN
    IF rtTorqueEnable.Q OR (NOT xTorqueCommanded) OR (ABS(lrTorquePct - lrLastTorquePct) > 0.0001) THEN
        xTorqueWritePulse := TRUE;
        lrLastTorquePct := lrTorquePct;
        xTorqueCommanded := TRUE;
    END_IF
ELSE
    xTorqueCommanded := FALSE;
END_IF

fbSetTorque(
    Axis := Axis,
    bEnable := xTorqueWritePulse,
    fTorque := lrTorquePct * 10.0
);

fbReadPosition(Axis := Axis, Enable := TRUE);
fbTrackingError(Axis := Axis, bEnable := TRUE, byDeadTimeCycles := 2, dwTimeStamp := 0);
fbReadTorque(Axis := Axis, Enable := TRUE);

IF fbReadPosition.Valid THEN
    lrActualPosition := fbReadPosition.Position;
END_IF
IF fbTrackingError.bValid THEN
    lrTrackingError := fbTrackingError.fActTrackingError;
END_IF
IF fbReadTorque.Valid THEN
    // Verify the AC702 target's displayed/scaled unit against 0x6077 during
    // commissioning. The benchmark CSV stores the normalized value as percent.
    lrActualTorquePct := fbReadTorque.Torque;
END_IF

IF eMode = E_BenchMode.CSP THEN
    xCommandDone := xMoveDoneLatched;
ELSE
    xCommandDone := xModeReady AND NOT fbSetTorque.bError;
END_IF

xError := fbPower.Error OR fbSetMode.bError OR fbMoveAbsolute.Error OR fbSetTorque.bError OR
          fbReadPosition.Error OR fbReadTorque.Error;
END_FUNCTION_BLOCK
