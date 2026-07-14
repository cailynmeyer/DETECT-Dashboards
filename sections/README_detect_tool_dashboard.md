# DETECT Tool Dashboard

Page: [`detect_tool_dashboard.qmd`](detect_tool_dashboard.qmd) · Published at the "Dashboards → DETECT Tool" navbar entry.

> This README covers only what is **specific** to the DETECT Tool dashboard. For installation, `renv`, general API-key setup, publishing, and troubleshooting shared across all dashboards, see the [main README](../README.md).

---

## Goal

Track use of the adapted **DETECT screening tool** by home-based primary care clinicians during the R33 universal EM-screening RCT — how many reporting instruments have been submitted, which EM indicators are being flagged, and completeness of the screening data over time. It is the primary progress-monitoring view for the experimental screening arm.

## Data Sources

| Source | Keyring service | REDCap/GO project |
|---|---|---|
| Screening submissions | `detect_tool_redcap_api` | REDCap — **DETECT Tool** (`reporting_instrument` form) |
| Link / click activity | `detect_tool_go_uth_api` | GO UTHealth — **Elder Abuse Definitions** |

Both keys are required to refresh this dashboard. See [main README → API Keys](../README.md#api-keys).

## Dashboard-Specific Setup

1. Ensure `detect_tool_redcap_api` and `detect_tool_go_uth_api` are in your keyring.
2. Refresh the prepped data by running the prep documents in order:
   - `data_management/detect_tool/data_01_detect_tool.qmd` — pulls raw REDCap + GO UTHealth data and cleans it.
   - `data_management/detect_tool/data_02_detect_tool.qmd` — further preparation for dashboard summaries.
3. These write the prepped files this page reads from `data/detect_tool/`:
   - `detect_tool_cleaned.RDS`
   - `dashboard_prepped_data.RData`
   - `detect_tool_link_hits.RDS`
   - plus `data_management/detect_tool/variable_descriptions.RDS`

All paths are resolved with `here::here("data", "detect_tool", ...)`, anchored to the repo root.

## Data Format

Uses R serialized objects — **`.RDS` / `.RData`** loaded with `readRDS()` / `load()`. (Contrast: the APS Baseline dashboard uses a DuckDB database.)

## Styling & Rendering

- `format: dashboard` with the **default** Quarto dashboard theme (no explicit `theme:`), so it inherits standard Bootstrap styling rather than a named bootswatch theme.
- Layout: sidebar + value-box rows for EM indicators, plus tabular detail.
- Tables rendered with **`flextable`** (with custom row-merging for duplicate values) and **`DT`**, with row shading via `r/add_shade_column_x_rows.R`.
- Charts via **`ggplot2`** + **`plotly`**; interactive filtering via **`crosstalk`**.

## Key Dependencies (beyond the shared set)

`flextable`, `officer`, `ggplot2`, `crosstalk`, `DT`, `plotly`, `purrr`, `rlang` — all captured in `renv.lock`.

## Helper Functions Used

Sourced from `r/`: `add_shade_column_x_rows.R` (DT table shading). Other `r/` helpers (`color_alert.R`, `format_table.R`, `gauge_chart.R`, `time_series.R`, `nums_to_na.R`, `recoding_factoring_relocating.R`, `data_cleaning_tools.R`, `month_name_year.R`) support this dashboard and the R33 prep pipeline.

## How It Differs From the Other Dashboards

- **Data format:** `.RDS`/`.RData` (vs APS Baseline's DuckDB).
- **Two data sources** (REDCap DETECT Tool + GO UTHealth), vs APS Baseline's single REDCap project.
- **Theme:** default dashboard theme (vs APS Baseline's `simplex`).
- **Tables:** `flextable`/`officer` heavy (vs APS Baseline's `DT` + SQL result sets).
- **Prep:** multi-step Quarto prep documents (vs APS Baseline's single `data_operations.R`).
