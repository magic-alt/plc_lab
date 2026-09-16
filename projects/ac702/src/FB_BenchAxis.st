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
    lrTorqueNm : LREAL;
END_VAR
VAR_OUTPUT
    xPowerReady : BOOL;
    xModeReady : BOOL;
    xCommandDone : BOOL;
    xError : BOOL;
    lrActualPosition : LREAL;
    lrTrackingError : LREAL;
    lrActualTorqueNm : LREAL;
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

    eRequestedControllerMode : SMC_CONTROLLER_MODE := SMC_position;
    xMoveActive : BOOL;
    xTorqueActive : BOOL;
    xMoveDoneLatched : BOOL := FALSE;
END_VAR

// Power-stage control follows the standard SoftMotion MC_Power interface.
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

// The required setpoint FB must take over immediately after the mode switch.
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

// SMC_SetTorque expects Nm (or N for a linear axis), not percentage.
// The caller converts the requested percentage using actual motor rated torque.
xTorqueActive := xEnablePower AND xModeReady AND (eMode = E_BenchMode.CST) AND xTorqueEnable;
fbSetTorque(
    Axis := Axis,
    bEnable := xTorqueActive,
    fTorque := SEL(xTorqueActive, 0.0, lrTorqueNm)
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
    lrActualTorqueNm := fbReadTorque.Torque;
END_IF

IF eMode = E_BenchMode.CSP THEN
    xCommandDone := xMoveDoneLatched;
ELSE
    // CST is a continuous command; mode-ready means the cyclic setpoint path is active.
    xCommandDone := xModeReady AND NOT fbSetTorque.bError;
END_IF

xError := fbPower.Error OR fbSetMode.bError OR fbMoveAbsolute.Error OR fbSetTorque.bError OR
          fbReadPosition.Error OR fbReadTorque.Error;
END_FUNCTION_BLOCK
