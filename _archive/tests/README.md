# Archived tests

## `testthat/test-data-operations.R`

Archived 2026-07-30.

Tests for `data_management/aps_baseline/data_operations.R` (`get_data()` /
`save_data()`). The target code is still current and in use, but this test file
was never finished and could not run safely:

- The mock cases were left as stubs (`# TODO: Finish setting up mock table
  data`) — empty data frames with assertions expecting 5 rows and a placeholder
  `id/name/age` schema that does not match the real APS-BL data.
- `test_that` sourced `data_operations.R`, whose top-level code performs a live
  REDCap pull and overwrites the production DuckDB at source time — so merely
  loading the suite hit the API and clobbered real data.
- `save_data()` reads a global `data`, so the test-local mock was never visible
  to it.

To revive this: guard the top-level execution in `data_operations.R` (e.g.
`if (sys.nframe() == 0L) { ... }`) so sourcing is side-effect-free, pass `data`
into `save_data()` as an argument, and rebuild the mocks against the real
APS-BL column schema. Then move the file back to `tests/testthat/` and run with
`testthat::test_dir("tests/testthat")`.
