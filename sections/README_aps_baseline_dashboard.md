# APS Baseline Dashboard

Page: [`aps_baseline_dashboard.qmd`](aps_baseline_dashboard.qmd) · Published at the "Dashboards → APS Baseline Dashboard" navbar entry.

> This README covers only what is **specific** to the APS Baseline dashboard. For installation, API-key setup, and publishing shared across all dashboards, see the [main README](../README.md).

---

## Goal

Efficiently monitor APS Baseline reporting submissions. It is the progress-monitoring view for baseline APS reporting activity.

## Corresponding Data Source

| Source | Keyring name | REDCap project |
|---|---|---|
| APS baseline submissions | `aps_reports_redcap_api` | REDCap — **DETECT-RPC APS Reporting** |

> [!NOTE]
> This dashboard uses the **same** `aps_reports_redcap_api` key and REDCap project as the R33 `aps_reports` prep pipeline (`data_management/aps_reports/`). 

## Dashboard-Specific Setup

1. Ensure `aps_reports_redcap_api` is in your keyring (see [main README → API Keys](../README.md#api-keys)).
2. Ensure `renv` is current (`renv::status()`; restore with `renv::restore()`).
3. From the **repo root**, build the DuckDB database:

   ```shell
   cd DETECT
   Rscript data_management/aps_baseline/data_operations.R
   ```
   This runs the APS prep document:
   - `data_management/aps_baseline/data_operations.R`:This pulls from REDCap (via `REDCapR`) and writes `data/aps_baseline/APS-DATA.duckdb` with a table named **`APS-BL`**.

   > [!NOTE]
   > This is a plain R script, so it is run — never rendered. The equivalent step for the DETECT Tool dashboard is `Rscript r/refresh_data.R`; see the [DETECT Tool README](README_detect_tool_dashboard.md). Both are listed together in [main README → Step 1](../README.md#step-1-refresh-the-data).

4. Continue with building and publishing the full dashboard. See [main README → Building & Publishing](../README.md#building--publishing).

Paths are resolved with `here::here("data", "aps_baseline", "APS-DATA.duckdb")`, anchored to the repo root.

## Key Dependencies (beyond the shared set)

**`duckdb`** and **`REDCapR`** are specific to this dashboard/its prep and may need installing (`renv::install(c("duckdb", "REDCapR"))` → `renv::snapshot()`; see [main README](../README.md#step-3-install-project-dependencies)). Also uses `DT`, `plotly`, `dplyr`, `tidyr`, `fs`.

## Tests

`tests/testthat/test-data-operations.R` exercises the `get_data()` / `save_data()` functions in `data_management/aps_baseline/data_operations.R` (some mock-data cases are still marked `TODO`). Run with `testthat::test_dir("tests/testthat")`.
