# R33 DETECT Tool Dashboard

Page: [`detect_tool_dashboard.qmd`](detect_tool_dashboard.qmd) · Published at the "Dashboards → DETECT Tool" navbar entry.

> This README covers only what is **specific** to the R33 (Detect Tool) dashboard. For installation, API-key setup, and publishing shared across all dashboards, see the [main README](../README.md).

---

## Overview of the Study

The primary objective of the study is to evaluate whether the use of the DETECT-RPC screening tool increases the average reporting of elder mistreatment (EM) by HBPC clinicians relative to a baseline period where they did not use the DETECT-RPC screening tool.

The R33 phase is divided into two parts:

  1. Universal EM Screening (RCT)
  2. Caregiver Dyad Follow-Up Interviews

### Universal EM Screening

In this part of the study (year 3-5), we will randomize approximately 43 home-based primary care clinicians to either use the adapted DETECT screening tool at every qualified home based primary care patient encounter (experimental condition) or continue to provide standard care (control condition). Providers randomized to the experimental condition will use the adapted DETECT tool at every qualified patient encounter. A waiver of informed consent is approved, as it requires no direct input from the patient; rather, it is a purely observation-based tool, which is completed by the clinician. Over the three years of follow-up, we expect our partner home-based primary care programs to treat approximately 6,150 older adults. Through the randomization process, we expect half of that number to be screened by a clinician using the adapted DETECT tool.

### Caregiver Dyad Follow-Up Interviews

In this part, we will recruit a purposive sample of 180 caregiving dyads consisting of family caregivers and their care recipients, half of which will be living with Alzheimer’s Disease or Related Dementias (ADRD). The study is recruiting dyads because we are interested in caregiver behaviors and their relationship to care recipient outcomes. The caregiving dyads will be recruited from among patients who are actively enrolled in one of our site-specific home-based primary care programs.

This repository contains the code used to create dashboards for tracking the progress of the study.

## Corresponding Data Sources

| Source | Keyring name | REDCap Project/GO UTH Link |
|---|---|---|
| Screening submissions | `detect_tool_redcap_api` | REDCap — **DETECT Tool** (`reporting_instrument` form) |
| Link / click activity | `detect_tool_go_uth_api` | GO UTHealth — **Elder Abuse Definitions** |

Both keys are required to refresh this dashboard. See [main README → API Keys](../README.md#api-keys).

## Dashboard-Specific Setup

1. Ensure `detect_tool_redcap_api`, `detect_tool_go_uth_api`, and `aps_reports_redcap_api` are in your keyring (see [main README → API Keys](../README.md#api-keys)). The APS reports key is required here because `data_02` joins in APS reports data.
2. From the **repo root**, refresh the prepped data:

   ```shell
   cd DETECT
   Rscript r/refresh_data.R
   ```

   This runs the three prep documents in dependency order:

   - `data_management/detect_tool/data_01_detect_tool.qmd` — pulls raw REDCap + GO UTHealth data and cleans it. Writes `data/detect_tool/detect_tool_cleaned.RDS` and `detect_tool_link_hits.RDS`.
   - `data_management/aps_reports/data_01_aps_reports.qmd` — pulls the APS reports data that `data_02` depends on. Writes `data/aps_reports/aps_reports_cleaned.RDS`.
   - `data_management/detect_tool/data_02_detect_tool.qmd` — further preparation for dashboard summaries (**reads the APS reports output from the previous step**). Writes `data/detect_tool/dashboard_prepped_data.RData`.

   After each step the script checks that the expected outputs were actually rewritten during this run, and stops if one wasn't — so a failed pull can't leave a later step building on stale data.

   > [!IMPORTANT]
   > **Run the prep documents — don't render them.** They exist for their side effects: they write the data files the dashboard reads. `quarto render` on a prep document produces an unwanted HTML page plus a `_files/libs/` bundle (~2.6 MB each) and refreshes nothing extra. `refresh_data.R` executes the code without rendering. These byproducts are gitignored, so an accidental render won't reach the repo.

   > [!NOTE]
   > **If the GO UTHealth token is rejected (HTTP 401),** `data_01` falls back to the last saved `detect_tool_link_hits.RDS` rather than failing, so the rest of the refresh completes. `refresh_data.R` reports this at the end under "NOT refreshed this run" — the link/click figures will be stale until a working token is in the keyring. All other data still refreshes normally.

3. Continue with building and publishing the full dashboard. See [main README → Building & Publishing](../README.md#building--publishing).