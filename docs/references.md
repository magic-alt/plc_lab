# Implementation references

The benchmark intentionally separates vendor-guaranteed behavior from laboratory stress points.

## Inovance AC702 / AC700

- **AC700 Series Intelligent Mechanical Controller User Guide** — hardware, AC702/AC703 axis counts, EtherCAT master parameters, minimum synchronization-period example, display/runtime diagnostics.
  - https://portal-file.inovance.com/owfile/ProdDoc/SC/PS00004465_PDF_EN/A02/AC700%20Series%20Intelligent%20Mechanical%20Controller%20User%20Guide-EN-A02.PDF?response-content-disposition=attachment
- **Application Guide for EtherCAT Bus Servo Torque Mode Controlled by Medium-Sized PLC** — `SMC_SetControllerMode`, `SMC_SetTorque`, `MC_TorqueControl`, 0x6071/0x607F, operation mode 8/10 and torque-mode precautions.
  - https://www.inovance.com/global/content/details_2349_583467.html
- **Medium-sized PLC Programming Guide (Motion Control)** — PLCopen/SoftMotion axis instructions and error semantics.
  - https://portal-file.inovance.com/owfile/ProdDoc/SC/19012378-SC/A00/19012378-SCY_A00%20Medium-sized%20PLC%20Programming%20Guide%20%28Motion%20Control%29-EN.pdf

Important implementation detail: Inovance's AC/medium-PLC documentation defines `SMC_SetTorque.fTorque` in **0.1% rated-torque units**. This differs from the generic upstream CODESYS SM3_Basic documentation, which describes the generic block in physical torque/force units. For the AC702 project, use the Inovance target's documented semantics.

## CODESYS runtime / SoftMotion diagnostics

- `SysTimeGetUs` for microsecond task timing:
  - https://content.helpme-codesys.com/en/LibDevSummary/date_time.html
- `MC_Power`:
  - https://content.helpme-codesys.com/en/libs/SM3_Basic/Current/SM3_Basic/POUs/AdministrativeConfiguration/MC_Power.html
- `MC_MoveAbsolute`:
  - https://content.helpme-codesys.com/en/libs/SM3_Basic/Current/SM3_Basic/POUs/Movement/MC_MoveAbsolute.html
- `SMC_SetControllerMode`:
  - https://content.helpme-codesys.com/en/libs/SM3_Basic/Current/SM3_Basic/POUs/AdministrativeConfiguration/SMC_SetControllerMode.html
- `SMC_GetTrackingError`:
  - https://content.helpme-codesys.com/en/libs/SM3_Basic/Current/SM3_Basic/POUs/Diagnostics/SMC_GetTrackingError.html

For AC702 DC deviation, lost-frame counters, WKC errors and CPU load, prefer target/runtime diagnostic views and exported runtime values over attempting to derive these values from motion feedback.

## ZMotion ZMC432-16-V2 / RTSys / ZBasic

- **ZBasic Programming Manual** — EtherCAT initialization sequence and commands such as `SLOT_SCAN`, `SLOT_START`, `AXIS_ADDRESS`, `ATYPE`, `SERVO_PERIOD`, `DRIVE_FE`, `DRIVE_TORQUE`, `NODE_*`.
  - https://www.zmotion.com.cn/upload/%E6%AD%A3%E8%BF%90%E5%8A%A8%E6%8A%80%E6%9C%AF-%E3%80%8AZBasic%E7%BC%96%E7%A8%8B%E6%89%8B%E5%86%8CV3.2.5%E3%80%8B.pdf
- **RTSys User Manual** — `?*ETHERCAT`, `Lostcount`, node status and bus diagnostics.
  - https://file.zmotion.com.cn/upload/RTSys%E4%BD%BF%E7%94%A8%E6%89%8B%E5%86%8CV1.3.1.pdf
- **ZDevelop User Manual** — EtherCAT diagnostic output and development/trace tooling.
  - https://file.zmotion.com.cn/upload/ZDevelop%E4%BD%BF%E7%94%A8%E6%89%8B%E5%86%8CV3.10.04.pdf

ZMotion documentation/support material also notes that short EtherCAT periods such as 125/500 us must be validated against node count and PDO size; packet loss at an accepted period is still a failed laboratory configuration.

## Measurement rule

A value is only populated if it comes from a controller/runtime diagnostic, a mapped PDO, or an explicitly documented hardware loopback measurement. In particular:

- following error is not treated as PDO latency;
- lost-frame/link counters are not treated as WKC;
- task jitter is not treated as EtherCAT DC deviation;
- configured cycle time is not treated as measured cycle time.
