# DETECT Dashboards

Welcome to the DETECT-RPC Dashboard project! This is the shared documentation for the **whole** dashboard site — installation, setup, API keys, dependencies, building, and troubleshooting. Each individual dashboard also has its own README covering what makes it different (see [Dashboards](#dashboards)).

> **DETECT** This project combines two previously separate repositories into one Quarto website:
> - **`r33_dashboards`** — the R33-phase DETECT tool / screening / recruitment dashboards.
> - **`DETECT-RPC-APS-BL-Dashboard`** — the APS Baseline monitoring dashboard (now the `sections/aps_baseline_dashboard.qmd` page).
>
> The two original repositories remain published independently; this repo is a new, unified home for both dashboards.

---

## Table of Contents

1. [Overview of the Study](#overview-of-the-study)
2. [Dashboards](#dashboards)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Project Setup](#project-setup)
6. [API Keys](#api-keys)
7. [Building & Publishing](#building--publishing)
8. [Development Workflow](#development-workflow)
9. [Contributing](#contributing)
10. [Repository Structure](#repository-structure)

---

## Overview of the Study

The primary objective of the study is to evaluate whether the use of the DETECT-RPC screening tool increases the average reporting of elder mistreatment (EM) by HBPC clinicians relative to a baseline period where they did not use the DETECT-RPC screening tool.

The R33 phase is divided into two parts:

1. **Universal EM Screening (RCT)** — randomize ~43 home-based primary care clinicians to either use the adapted DETECT screening tool at every qualified patient encounter (experimental) or continue standard care (control).
2. **Caregiver Dyad Follow-Up Interviews** — recruit a purposive sample of 180 caregiving dyads (family caregiver + care recipient), half living with Alzheimer's Disease or Related Dementias (ADRD).

This repository contains the code used to create the dashboards that track the progress of the study, including baseline APS (Adult Protective Services) reporting activity.

---

## Dashboards

The site is a multi-page Quarto **website**: `index.qmd` is the landing/overview page, and each dashboard is a page under `sections/`. Which pages are actually built is controlled by the `render:` list in [`_quarto.yml`](_quarto.yml).

**Currently published** (in the `render:` list and navbar):

| Dashboard | Page | Dashboard-specific README |
|---|---|---|
| DETECT Tool | `sections/detect_tool_dashboard.qmd` | [README](sections/README_detect_tool_dashboard.md) |
| APS Baseline | `sections/aps_baseline_dashboard.qmd` | [README](sections/README_aps_baseline_dashboard.md) |

**Present but not currently published** (in `sections/` but not in the `render:` list): `clinician_screening_completion_tracker.qmd`, `recruitment_and_scheduling_tracker.qmd`, `screening_tool_dashboard.qmd`. Add them to `render:` and the navbar in `_quarto.yml` to publish them.

Read the per-dashboard READMEs for goals, data sources, styling, and any dashboard-specific setup that differs from the shared steps below.

---

## Prerequisites

### System Requirements
* **Operating System**: Windows, macOS, or Linux
* **Memory**: Minimum 8 GB RAM
* **Storage**: At least 10 GB free space

### Software Requirements
* [R](https://cran.r-project.org/) (version 4.5)
* [Positron](https://positron.posit.co/) **OR** [RStudio](https://posit.co/download/rstudio-desktop/) IDE (latest version)
* [Quarto](https://quarto.org/docs/get-started/) (version 1.7.\*)
* [Git](https://git-scm.com/downloads) (latest version)

Verify installations:

```shell
R --version
quarto --version
git --version
```

---

## Installation

1. **Install R** from [CRAN](https://cran.r-project.org/).
2. **Install an IDE** — RStudio or Positron from [Posit](https://posit.co/).
3. **Install Quarto** from [Quarto](https://quarto.org/docs/get-started/).
4. **Install Git** from [git-scm.com](https://git-scm.com/downloads).

---

## Project Setup

### Step 1: Clone the Repository

```shell
git clone <this-repo-url>
cd DETECT
```

> [!NOTE]
> Don't clone to a cloud storage folder (Box, Dropbox, Google Drive, OneDrive, etc.). File-locking and sync conflicts can corrupt the `renv` library.

### Step 2: Open in the IDE

Open the project folder in RStudio or Positron. The `.here` file at the project root anchors `here::here()` to this directory, so all data and helper paths resolve correctly.

### Step 3: Install Project Dependencies

This project uses [renv](https://rstudio.github.io/renv/articles/renv.html) to manage package dependencies. In the R console:

```r
install.packages("renv")
renv::restore()
```

> [!NOTE]
> `renv::restore()` may take several minutes and requires an active internet connection.

### Step 4: Request & Store API Keys

The dashboards pull live data from REDCap and GO UTHealth. See [API Keys](#api-keys) for the full list and how to store them.

### Step 5: Save / Refresh the Data Locally

Data is **not tracked in git** (see [Repository Structure](#repository-structure)). Each dashboard regenerates its data from source — see [Building & Publishing](#building--publishing) and the per-dashboard READMEs.

---

## API Keys

Request tokens via the wiki: <https://github.com/brad-cannell/r33_dashboards/wiki/DETECT%E2%80%90RPC-Data#accessing-data-through-api>

| Keyring service | Source | Used by |
|---|---|---|
| `detect_tool_redcap_api` | REDCap — project **DETECT Tool** (<https://redcap.uth.tmc.edu>) | DETECT Tool dashboard |
| `detect_tool_go_uth_api` | GO UTHealth — **Elder Abuse Definitions** (<https://apps.uth.edu/go>) | DETECT Tool dashboard (link/click data) |
| `aps_reports_redcap_api` | REDCap — project **DETECT-RPC APS Reporting** (<https://redcap.uth.tmc.edu>) | APS Baseline dashboard **and** R33 `aps_reports` prep |

Store each token with [keyring](https://keyring.r-lib.org/) (a password box will appear for the token value):

```r
keyring::key_set("detect_tool_redcap_api")
keyring::key_set("detect_tool_go_uth_api")
keyring::key_set("aps_reports_redcap_api")
```

You only need the keys for the dashboards you intend to build. **Tokens are stored in your OS keychain, never in the repo.**

---

## Building & Publishing

The whole site renders together — every page in the `render:` list of `_quarto.yml`. Before rendering, refresh each dashboard's data.

### Step 1: Refresh the Data

- **DETECT Tool** — run the prep documents in `data_management/detect_tool/` (`data_01_detect_tool.qmd`, `data_02_detect_tool.qmd`). See the [DETECT Tool README](sections/README_detect_tool_dashboard.md).
- **APS Baseline** — build the DuckDB database:
  ```shell
  rscript data_management/aps_baseline/data_operations.R
  ```
  This writes `data/aps_baseline/APS-DATA.duckdb`. See the [APS Baseline README](sections/README_aps_baseline_dashboard.md).

### Step 2: Render / Publish

```shell
quarto render      # to render locally without publishing:
quarto publish gh-pages     # render + publish to GitHub Pages
```

- Confirm the publish target when prompted (this repo's GitHub Pages URL).
- You may be asked for your computer's password one or more times to let `keyring` release the API tokens.

### Step 3: Commit and Push

```shell
git add .
git commit -m "YYYY-MM-DD Dashboard Update"
git push
```

---

## Development Workflow

Use feature branches:

```shell
git checkout -b feature/your-feature-name
# ...make changes...
git add .
git commit -m "Describe changes clearly"
git push origin feature/your-feature-name
```

---

## Contributing

1. Fork the repository.
2. Create your feature branch.
3. Submit a Pull Request (PR) to the main repository.
4. Clearly document your changes in the PR description.

---

## Repository Structure

| Path | What it holds |
|---|---|
| `index.qmd` | R33 Dashboard landing screen (study aims and objectives) |
| `sections/` | Quarto documents that produce each dashboard page |
| `sections/detect_tool_dashboard.qmd` | DETECT tool dashboard (R33) — [README](sections/README_detect_tool_dashboard.md) |
| `sections/aps_baseline_dashboard.qmd` | APS Baseline dashboard — [README](sections/README_aps_baseline_dashboard.md) |
| `sections/clinician_screening_completion_tracker.qmd`, `recruitment_and_scheduling_tracker.qmd`, `screening_tool_dashboard.qmd` | Additional R33 trackers (not currently published) |
| `data_management/` | Data-prep scripts that pull from REDCap and write prepped data to `data/` |
| `data_management/detect_tool/`, `detect_tool_pilot/`, `aps_reports/`, `mock_data/` | R33 prep pipelines (one folder per data stream) |
| `data_management/aps_baseline/data_operations.R` | APS Baseline prep — builds `data/aps_baseline/APS-DATA.duckdb` |
| `data/` | Prepped/source data — **not tracked in git** (regenerated by `data_management/` scripts) |
| `r/` | Active helper functions and lookups (includes APS `codebook.r`) |
| `tests/` | `testthat` tests (currently covers APS `data_operations.R`) |
| `_archive/` | Retired files not rendered (leading `_` excludes it from the Quarto render). Includes `_archive/aps_standalone/` — the APS dashboard's original standalone HTML build |
| `assets/` | Dashboard styling (`custom_style.css`) and the APS logo (`assets/graphics/detect-logo.png`) |
| `graphics/` | R33 site logos (`detect_logo.png`, `detect_logo_small.png`) |
| `_quarto.yml` | Quarto project config: render list, navbar, theme |
| `.here` | Anchors `here::here()` to the project root (all data/source paths are project-root-relative) |
| `renv.lock` / `renv/` | Package dependency lockfile and library (managed by `renv`) |

> **Note on data paths.** Every dashboard resolves file paths with `here::here(...)`, anchored to the repo root by the `.here` sentinel. The APS Baseline page was converted from its original working-directory-relative paths to this convention when it was merged in.
