' ZMC432-16-V2 EtherCAT period setup helper
' Change TARGET_PERIOD_US, download/run once, then power-cycle the controller.

GLOBAL CONST TARGET_PERIOD_US = 1000

?"Current SERVO_PERIOD = ", SERVO_PERIOD, " us"

IF (TARGET_PERIOD_US<>1000) AND (TARGET_PERIOD_US<>500) AND (TARGET_PERIOD_US<>250) AND (TARGET_PERIOD_US<>125) THEN
    ?"ERROR: benchmark period must be 1000/500/250/125 us"
    END
ENDIF

SERVO_PERIOD = TARGET_PERIOD_US
?"Requested SERVO_PERIOD = ", TARGET_PERIOD_US, " us"
?"Power-cycle controller and drives, reconnect, then verify ?SERVO_PERIOD before running benchmark.bas"
END
