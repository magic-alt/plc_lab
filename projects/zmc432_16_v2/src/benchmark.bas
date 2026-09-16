' ZMC432-16-V2 / 16-axis EtherCAT benchmark
' Safety defaults: bus mapping only; motor power and non-zero CST torque are disabled.

GLOBAL CONST BUS_SLOT = 0
GLOBAL CONST BENCH_AXES = 16
GLOBAL CONST MODE_CSP = 65
GLOBAL CONST MODE_CST = 67
GLOBAL CONST REQUESTED_PERIOD_US = 1000
GLOBAL CONST TEST_MODE = MODE_CSP
GLOBAL CONST ARM_AXES = 0
GLOBAL CONST ARM_CST = 0
GLOBAL CONST UNITS_PER_DEG = 10000
GLOBAL CONST MOVE_DEG = 5
GLOBAL CONST CSP_SPEED_DEG_S = 20
GLOBAL CONST CSP_ACCEL_DEG_S2 = 200
GLOBAL CONST CST_DAC_2PCT = 20        'ZMotion torque DAC: 0..1000 => 0..100%
GLOBAL CONST CYCLES = 20

GLOBAL gBusReady
gBusReady = 0

DELAY(3000)
?"=== plc_lab ZMC432-16-V2 benchmark ==="
?"Firmware: ", VERSION, " build: ", VERSION_BUILD
?"Requested period: ", REQUESTED_PERIOD_US, " us; active SERVO_PERIOD: ", SERVO_PERIOD, " us"

IF SERVO_PERIOD <> REQUESTED_PERIOD_US THEN
    ?"ABORT: active SERVO_PERIOD does not match requested period. Run set_period.bas and power-cycle."
    END
ENDIF

CALL Ecat_Init()
IF gBusReady = 0 THEN
    ?"ABORT: EtherCAT initialization failed"
    END
ENDIF

CALL Axis_Params()
CALL Print_Diagnostics()

IF ARM_AXES = 0 THEN
    ?"SAFE STOP: ARM_AXES=0. Bus is initialized but drives are not enabled."
    ?"Run ?*ETHERCAT in the online console and save bus diagnostics."
    END
ENDIF

WDOG = 1
FOR i = 0 TO BENCH_AXES-1
    AXIS_ENABLE(i) = 1
    DELAY(10)
NEXT
DELAY(500)
CALL Print_Diagnostics()

IF TEST_MODE = MODE_CSP THEN
    CALL Run_CSP()
ELSEIF TEST_MODE = MODE_CST THEN
    CALL Run_CST()
ELSE
    ?"ABORT: TEST_MODE must be MODE_CSP or MODE_CST"
ENDIF

CALL Safe_Stop()
CALL Print_Diagnostics()
?"Run complete. Save ?*ETHERCAT output and RTSys/ZDevelop scope/diagnostic exports."
END

GLOBAL SUB Ecat_Init()
    LOCAL node, local_axis, node_axes, drive_index

    RAPIDSTOP(2)
    FOR i = 0 TO BENCH_AXES-1
        AXIS_ENABLE(i) = 0
        ATYPE(i) = 0
        AXIS_ADDRESS(i) = 0
        DELAY(5)
    NEXT

    SLOT_STOP(BUS_SLOT)
    DELAY(200)
    SLOT_SCAN(BUS_SLOT)
    IF NOT RETURN THEN
        ?"SLOT_SCAN failed"
        RETURN
    ENDIF

    ?"EtherCAT nodes discovered: ", NODE_COUNT(BUS_SLOT)
    drive_index = 0
    FOR node = 0 TO NODE_COUNT(BUS_SLOT)-1
        node_axes = NODE_AXIS_COUNT(BUS_SLOT,node)
        FOR local_axis = 0 TO node_axes-1
            IF drive_index < BENCH_AXES THEN
                'Drive indices are assigned by drive order, independent of non-drive IO nodes.
                AXIS_ADDRESS(drive_index) = drive_index + 1
                IF TEST_MODE = MODE_CST THEN
                    ATYPE(drive_index) = MODE_CST
                    DRIVE_PROFILE(drive_index) = 30
                ELSE
                    ATYPE(drive_index) = MODE_CSP
                    DRIVE_PROFILE(drive_index) = -1
                ENDIF
                DISABLE_GROUP(drive_index)
                drive_index = drive_index + 1
            ENDIF
        NEXT
    NEXT

    IF drive_index <> BENCH_AXES THEN
        ?"ERROR: expected 16 EtherCAT drive axes, mapped ", drive_index
        RETURN
    ENDIF

    SLOT_START(BUS_SLOT)
    IF NOT RETURN THEN
        ?"SLOT_START failed"
        RETURN
    ENDIF

    DELAY(1000)
    FOR node = 0 TO NODE_COUNT(BUS_SLOT)-1
        ?"node", node, " status=", NODE_STATUS(BUS_SLOT,node)
    NEXT

    gBusReady = 1
    ?"EtherCAT initialized: 16 axes mapped, mode=", TEST_MODE
END SUB

GLOBAL SUB Axis_Params()
    FOR i = 0 TO BENCH_AXES-1
        BASE(i)
        UNITS = UNITS_PER_DEG
        SPEED = CSP_SPEED_DEG_S
        ACCEL = CSP_ACCEL_DEG_S2
        DECEL = CSP_ACCEL_DEG_S2
        FASTDEC = CSP_ACCEL_DEG_S2 * 4
        SRAMP = 50
    NEXT
END SUB

GLOBAL SUB Run_CSP()
    ?"Starting CSP workload"
    BASE(0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15)
    MERGE = OFF
    TRIGGER

    FOR k = 1 TO CYCLES
        MOVEABS(MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG)
        WAIT IDLE(0)
        MOVEABS(-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG,-MOVE_DEG,MOVE_DEG)
        WAIT IDLE(0)
        CALL Print_Sample(k)
    NEXT
END SUB

GLOBAL SUB Run_CST()
    ?"Starting CST workload"
    IF ARM_CST = 0 THEN
        ?"SAFE STOP: ARM_CST=0; forcing all torque commands to zero"
        FOR i = 0 TO BENCH_AXES-1
            DAC(i) = 0
        NEXT
        RETURN
    ENDIF

    ?"WARNING: non-zero CST armed. Confirm mechanical fixture and drive velocity/torque limits."
    FOR k = 1 TO CYCLES
        FOR i = 0 TO BENCH_AXES-1
            IF (i MOD 2) = 0 THEN
                DAC(i) = CST_DAC_2PCT
            ELSE
                DAC(i) = -CST_DAC_2PCT
            ENDIF
        NEXT
        DELAY(1000)
        FOR i = 0 TO BENCH_AXES-1
            DAC(i) = -DAC(i)
        NEXT
        DELAY(1000)
        CALL Print_Sample(k)
    NEXT
END SUB

GLOBAL SUB Print_Sample(sample_no)
    ?"sample=", sample_no, " period_us=", SERVO_PERIOD
    FOR i = 0 TO BENCH_AXES-1
        ?"axis=", i, " dpos=", DPOS(i), " mpos=", MPOS(i), " fe=", DRIVE_FE(i), " torque=", DRIVE_TORQUE(i), " axisstatus=", AXISSTATUS(i), " drivestatus=", DRIVE_STATUS(i)
    NEXT
END SUB

GLOBAL SUB Print_Diagnostics()
    ?"--- diagnostics ---"
    ?"SERVO_PERIOD=", SERVO_PERIOD, " nodes=", NODE_COUNT(BUS_SLOT)
    FOR i = 0 TO BENCH_AXES-1
        ?"axis=", i, " atype=", ATYPE(i), " address=", AXIS_ADDRESS(i), " enable=", AXIS_ENABLE(i), " fe=", DRIVE_FE(i), " torque=", DRIVE_TORQUE(i), " axisstatus=", AXISSTATUS(i), " drivestatus=", DRIVE_STATUS(i)
    NEXT
    ?"Use ?*ETHERCAT for Lostcount/node details and bus-node diagnostics for 300h..309h counters."
END SUB

GLOBAL SUB Safe_Stop()
    RAPIDSTOP(2)
    FOR i = 0 TO BENCH_AXES-1
        DAC(i) = 0
        AXIS_ENABLE(i) = 0
    NEXT
    WDOG = 0
END SUB
