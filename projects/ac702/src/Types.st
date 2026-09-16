TYPE E_BenchMode :
(
    CSP := 0,
    CST := 1
);
END_TYPE

TYPE E_BenchState :
(
    IDLE := 0,
    CHECK_CONFIG := 10,
    WAIT_ARM := 20,
    ENABLE_AXES := 30,
    RUN_CSP_A := 40,
    RUN_CSP_B := 50,
    RUN_CST_A := 60,
    RUN_CST_B := 70,
    STOPPING := 80,
    DONE := 90,
    ERROR := 100
);
END_TYPE

TYPE ST_BenchSample :
STRUCT
    uliTimestampUs : ULINT;
    lrTaskDeltaUs : LREAL;
    lrJitterUs : LREAL;
    lrDcDeviationNs : LREAL;   // bind from runtime diagnostic if available, otherwise NaN/sentinel
    diWkcExpected : DINT;      // runtime-specific optional binding
    diWkcActual : DINT;        // runtime-specific optional binding
    xWkcOk : BOOL;
    udiLostFrames : UDINT;     // runtime-specific optional binding
    uiAxis : UINT;
    lrCommandPosition : LREAL;
    lrActualPosition : LREAL;
    lrFollowingError : LREAL;
    lrCommandTorquePct : LREAL;
    lrActualTorquePct : LREAL;
    lrCpuLoadPct : LREAL;      // bind if target exposes IEC CPU-load value
END_STRUCT
END_TYPE
