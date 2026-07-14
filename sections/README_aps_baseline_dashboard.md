# APS Baseline Dashboard

Page: [`aps_baseline_dashboard.qmd`](aps_baseline_dashboard.qmd) · Published at the "Dashboards → APS Baseline Dashboard" navbar entry.

> This README covers only what is **specific** to the APS Baseline dashboard. For installation, `renv`, general API-key setup, publishing, and troubleshooting shared across all dashboards, see the [main README](../README.md).
>
> **Provenance:** this page was merged in from the standalone `DETECT-RPC-APS-BL-Dashboard` repository. Its working-directory-relative paths were converted to `here::here(...)` and its `output-file: index.html` directive was removed so it renders as a section of the site rather than the site's home page.

---

## Goal

Efficiently monitor **new and existing APS (Adult Protective Services) Baseline reporting** submissions — total submissions, participating sites and "champions," and how submissions break down by randomization status, both overall and per home-based-primary-care site. It is the progress-monitoring view for baseline APS reporting activity.

## Data Source

| Source | Keyring service | REDCap project |
|---|---|---|
| APS baseline submissions | `aps_reports_redcap_api` | REDCap — **DETECT-RPC APS Reporting** |

> [!NOTE]
> This dashboard uses the **same** `aps_reports_redcap_api` key and REDCap project as the R33 `aps_reports` prep pipeline (`data_management/aps_reports/`). They pull from the same source but process it differently: R33's prep produces `.RDS` for cross-referencing in the DETECT Tool view, while this dashboard builds its own DuckDB database.

## Dashboard-Specific Setup

1. Ensure `aps_reports_redcap_api` is in your keyring (see [main README → API Keys](../README.md#api-keys)).
2. Build the DuckDB database:
   ```shell
   rscript data_management/aps_baseline/data_operations.R
   ```
   This pulls from REDCap (via `REDCapR`) and writes `data/aps_baseline/APS-DATA.duckdb` with a table named **`APS-BL`**.
3. The dashboard opens that database **read-only** (`dbConnect(duckdb(), dbdir = ..., read_only = TRUE)`) and queries it with SQL.

Paths are resolved with `here::here("data", "aps_baseline", "APS-DATA.duckdb")`, anchored to the repo root.

## Data Format

Uses a **DuckDB** database (`APS-DATA.duckdb`, table `APS-BL`) queried with SQL via `dbGetQuery()`. (Contrast: the DETECT Tool dashboard uses `.RDS`/`.RData`.) This is the one dashboard on a database backend rather than serialized R objects — a candidate model if the project later standardizes all dashboards on a single data format.

## Styling & Rendering

- `format: dashboard` with **`theme: simplex`** (a named bootswatch theme) — visually distinct from the DETECT Tool dashboard's default theme.
- `logo: /assets/graphics/detect-logo.png` — uses the APS dashboard's own distinct logo (site-root-relative path), **not** the R33 `graphics/detect_logo.png`.
- Layout: `orientation: columns`, a sidebar showing "last updated," a **Submission Details** page of value boxes, and a **Randomization Details** page with tabbed views (total / pre-launch / post-launch submissions by randomization status) broken out per site: BCM, JHU, UCSF, UAB, UTSW, UTH LBJ, UTH UTP.
- Charts via **`plotly`**; tables via **`DT`**.

## Key Dependencies (beyond the shared set)

**`duckdb`** and **`REDCapR`** are specific to this dashboard/its prep and may need installing (`renv::install(c("duckdb", "REDCapR"))` → `renv::snapshot()`; see [main README](../README.md#step-3-install-project-dependencies)). Also uses `DT`, `plotly`, `dplyr`, `tidyr`, `fs`.

## Helper Functions / Lookups Used

Sources `r/codebook.r`, which is **data, not functions** — it defines lookup vectors and tables used to translate REDCap codes into human-readable labels and consistent colors:
- `colors_user` — color per clinician/champion.
- `colors_institution` — color per site.
- `user` — a data frame mapping `site_champ` codes to labels.

Because `codebook.r` defines no functions, there is no name collision with the R33 `r/` helper functions.

## Tests

`tests/testthat/test-data-operations.R` exercises the `get_data()` / `save_data()` functions in `data_management/aps_baseline/data_operations.R` (some mock-data cases are still marked `TODO`). Run with `testthat::test_dir("tests/testthat")`.

## How It Differs From the Other Dashboards

- **Data format:** DuckDB + SQL (vs DETECT Tool's `.RDS`/`.RData`).
- **Single data source** (one REDCap project) vs the DETECT Tool's two.
- **Theme:** `simplex` and its own logo (vs default theme + R33 logo).
- **Prep:** a single `data_operations.R` script (vs multi-step Quarto prep documents).
- **Has an automated test suite** under `tests/`.
