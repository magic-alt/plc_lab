# Benchmark results

Store normalized CSV exports here; keep vendor-native raw captures outside this directory or under a run-specific subdirectory if their size is reasonable.

Recommended run ID / filename:

```text
YYYYMMDD_<controller>_<mode>_<cycle-us>us_<run-index>.csv
```

Example:

```text
20260916_ac702_CSP_1000us_01.csv
20260916_zmc432-16-v2_CSP_1000us_01.csv
```

Every normalized row should preserve the controller/drive firmware, requested and actual period, and a note identifying the raw capture or runtime diagnostic source. Leave unavailable metrics empty; never enter `0` merely to satisfy a column.

Do not commit large binary scope captures by default. The normalized CSV plus enough provenance to reproduce it is the reviewable artifact.
