# =============================================================================
# test-utp-redcap-counts.R
# =============================================================================
# Integrity check for the UTP (UT Physicians) rows that come from REDCap -- the
# screenings entered directly into the REDCap reporting_instrument form for
# institution 7, as opposed to the manually-uploaded EMR rows (those are covered
# by test-utp-manual-counts.R). It pulls REDCap live, filters to UTP, recomputes
# each count, and asserts the dashboard's REDCap-sourced UTP rows match.
#
# REQUIRES a live REDCap pull. If the token is missing or the API is unreachable,
# the test SKIPS (so the offline manual test and the rest of the suite still run).
#
# The dashboard's UTP data is a mix of REDCap + EMR rows. This test isolates the
# REDCap side by record_id: EMR rows are excluded via detect_tool_excel_raw.RDS
# (when present), and the dashboard subset is matched to the live REDCap ids.
#
# Writes nothing. Run occasionally, right after a data refresh:
#   testthat::test_dir("tests/testthat")
#
# Count definitions mirror sections/detect_tool_dashboard.qmd, scoped to UTP.
# =============================================================================

library(testthat)
library(dplyr)
library(janitor)

source(here::here("r", "get_api_token.R"))

UTP_LABEL <- "UTH Houston - UT Physicians House Calls"
UTP_CODE  <- 7   # calc_institution numeric code for UT Physicians

screening_base <- c("ri_necessities", "ri_environment", "ri_caregiver", "ri_sedated",
                    "ri_isolated", "ri_anxious", "ri_prohibited", "ri_unmet_needs",
                    "ri_injuries")
screening_f    <- paste0(screening_base, "_3cat_f")

answered <- function(x) !is.na(x) & trimws(as.character(x)) != ""


test_that("UTP REDCap-sourced counts match a fresh REDCap pull", {

  cleaned_path <- here::here("data", "detect_tool", "detect_tool_cleaned.RDS")
  if (!file.exists(cleaned_path)) {
    stop("Prepped data missing - run a data refresh before this test:\n  ", cleaned_path)
  }
  data <- readRDS(cleaned_path)   # = `data` / `dt_data` in the dashboard

  # ---- REDCap: fresh live pull (skip if token/network unavailable) -----------
  raw <- tryCatch({
    library(redcapAPI)
    api_token <- get_api_token("detect_tool_redcap_api")
    rcon <- redcapConnection(url = "https://redcap.uth.tmc.edu/api/", token = api_token)
    exportRecordsTyped(rcon, forms = "reporting_instrument",
                       rawOrLabel = "raw", factor = FALSE) |>
      janitor::clean_names()
  }, error = function(e) {
    skip(paste("REDCap pull unavailable -", conditionMessage(e)))
  })

  # ---- Scope to UTP (institution 7). UAB password filter is a no-op here. -----
  redcap_utp <- raw |> filter(calc_institution == UTP_CODE)
  redcap_ids <- as.character(redcap_utp$record_id)

  # Dashboard's REDCap-sourced UTP subset = UTP rows whose id is in the REDCap
  # pull. (EMR rows carry PAT_ID_date ids that never appear in a REDCap pull.)
  emr_ids <- character(0)
  excel_raw_path <- here::here("data", "detect_tool", "detect_tool_excel_raw.RDS")
  if (file.exists(excel_raw_path)) emr_ids <- as.character(readRDS(excel_raw_path)$record_id)

  dash_utp <- data |>
    filter(calc_institution_7cat_f == UTP_LABEL,
           as.character(record_id) %in% redcap_ids,
           !as.character(record_id) %in% emr_ids)

  # ---- record_id reconciliation (timing drift vs. real bugs) -----------------
  dash_ids       <- as.character(dash_utp$record_id)
  in_redcap_only <- setdiff(redcap_ids, dash_ids)
  in_dash_only   <- setdiff(dash_ids, redcap_ids)
  cat("\n--- UTP record_id reconciliation (REDCap side) ---------------------\n")
  cat("REDCap UTP:", length(redcap_ids), " | dashboard UTP (REDCap-sourced):", length(dash_ids), "\n")
  cat("in REDCap but NOT dashboard (dashboard stale? refresh):", length(in_redcap_only), "\n")
  cat("in dashboard but NOT REDCap (deleted upstream?)       :", length(in_dash_only), "\n")

  # ---- Counts: dashboard side (mirrors detect_tool_dashboard.qmd, UTP page) ---
  dash <- c(
    survey_responses     = nrow(dash_utp),
    unique_mrns          = n_distinct(dash_utp$ri_patient_mrn),
    screenings_started   = dash_utp |> filter(if_any(all_of(screening_f), ~ !is.na(.x))) |> nrow(),
    screenings_completed = sum(dash_utp$reporting_instrument_complete == "Complete", na.rm = TRUE),
    em_status_incomplete = dash_utp |> filter(if_all(all_of(screening_f), ~ !is.na(.x))) |>
                                        filter(is.na(suspect_em_2cat)) |> nrow(),
    em_suspected         = sum(dash_utp$suspect_em_2cat_f == "Yes", na.rm = TRUE),
    intended_reports     = sum(dash_utp$ri_report_2cat_f == "Yes", na.rm = TRUE)
  )

  # ---- Counts: REDCap raw side (same predicates on raw text values) ----------
  redcap <- c(
    survey_responses     = nrow(redcap_utp),
    unique_mrns          = n_distinct(redcap_utp$ri_patient_mrn),
    screenings_started   = redcap_utp |> filter(if_any(all_of(screening_base), ~ answered(.x))) |> nrow(),
    screenings_completed = sum(redcap_utp$reporting_instrument_complete == "Complete", na.rm = TRUE),
    em_status_incomplete = redcap_utp |> filter(if_all(all_of(screening_base), ~ answered(.x))) |>
                                          filter(!answered(suspect_em)) |> nrow(),
    em_suspected         = sum(redcap_utp$suspect_em == "Yes", na.rm = TRUE),
    intended_reports     = sum(redcap_utp$ri_report == "Yes", na.rm = TRUE)
  )

  cmp <- data.frame(
    count     = names(dash),
    dashboard = as.integer(dash),
    redcap    = as.integer(redcap[names(dash)]),
    row.names = NULL
  )
  cmp$match <- ifelse(cmp$dashboard == cmp$redcap, "OK", "*** MISMATCH ***")
  cat("\n--- UTP counts (REDCap-sourced): dashboard vs REDCap ---------------\n")
  print(cmp, row.names = FALSE)
  cat("--------------------------------------------------------------------\n\n")

  expect_equal(cmp$dashboard, cmp$redcap)
})
