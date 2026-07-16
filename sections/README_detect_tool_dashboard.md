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

1. Ensure `detect_tool_redcap_api` and `detect_tool_go_uth_api` are in your keyring (see [main README → API Keys](../README.md#api-keys))..
2. Refresh the prepped data by running the prep documents in order:
   - `data_management/detect_tool/data_01_detect_tool.qmd` — pulls raw REDCap + GO UTHealth data and cleans it.
   - `data_management/detect_tool/data_02_detect_tool.qmd` — further preparation for dashboard summaries.
