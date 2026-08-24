# =============================================================================
# test-redcap-counts.R
# =============================================================================
# Occasional-use integrity check: do the DETECT Tool counts for
# REDCap-SUBSTANTIATED data match a fresh pull from REDCap?
#
# The dashboard's data is a mix of two sources -- rows entered in REDCap and
# rows manually uploaded from the EMR export (reshaped by
# reshape_pulled_emr_data.R and bound on in data_01). This test validates ONLY
# the REDCap-substantiated rows: the manually-uploaded EMR rows are excluded
# from the dashboard side (by record_id, via detect_tool_excel_raw.RDS) so both
# sides describe the same population. The EMR rows are covered separately by
# test-utp-manual-counts.R.
#
# It pulls the reporting_instrument form live, recomputes each count directly
# from that pull, and prints a side-by-side table (dashboard vs REDCap) plus a
# record_id reconciliation, then asserts every count matches.
#
# REQUIRES a live REDCap pull -- there is NO offline/skip fallback by design.
# If the token is missing or the API call fails, the test errors loudly.
#
# Writes nothing. The pull stays in memory; the "displayed" side reads the
# existing (gitignored) data/detect_tool/*.RDS. A run leaves git clean.
#
# Run occasionally, right after a data refresh:
#   testthat::test_dir("tests/testthat")
#
# Count definitions mirror sections/detect_tool_dashboard.qmd (line refs below).
# The only intentional raw->clean row difference is data_01_detect_tool.qmd:544
# (drop UAB records with password_verification == 0), replicated here.
# =============================================================================

library(testthat)
library(dplyr)
library(tidyr)
library(redcapAPI)
library(janitor)

source(here::here("r", "get_api_token.R"))

# 9 screening-indicator fields: raw base names + their cleaned factor equivalents
screening_base <- c("ri_necessities", "ri_environment", "ri_caregiver", "ri_sedated",
                    "ri_isolated", "ri_anxious", "ri_prohibited", "ri_unmet_needs",
                    "ri_injuries")
screening_f    <- paste0(screening_base, "_3cat_f")

# 14 raw clinician-name fields that data_01 coalesces into ri_clinician_id_name
clinician_cols <- c("ri_clinician_bcm", "ri_clinician_bcm_oth",
                    "ri_clinician_jh", "ri_clinician_jh_oth",
                    "ri_clinician_ucsf", "ri_clinician_ucsf_oth",
                    "ri_clinician_uab", "ri_clinician_uab_oth",
                    "ri_clinician_utsw", "ri_clinician_utsw_oth",
                    "ri_clinician_lbj", "ri_clinician_lbj_oth",
                    "ri_clinician_utp", "ri_clinician_utp_oth")

answered <- function(x) !is.na(x) & trimws(as.character(x)) != ""


test_that("DETECT Tool REDCap-substantiated counts match a fresh REDCap pull", {

  # ---- Displayed side: exactly the data the dashboard renders ----------------
  cleaned_path <- here::here("data", "detect_tool", "detect_tool_cleaned.RDS")
  if (!file.exists(cleaned_path)) {
    stop("Prepped data missing - run a data refresh before this test:\n  ", cleaned_path)
  }
  data <- readRDS(cleaned_path)                 # = `data` / `dt_data` in the dashboard

  # ---- Exclude manually-uploaded EMR rows so this measures REDCap only --------
  # EMR rows are identified exactly by their record_ids in the reshape output.
  excel_raw_path <- here::here("data", "detect_tool", "detect_tool_excel_raw.RDS")
  emr_ids <- if (file.exists(excel_raw_path)) {
    as.character(readRDS(excel_raw_path)$record_id)
  } else {
    character(0)
  }
  n_before <- nrow(data)
  data <- data |> filter(!as.character(record_id) %in% emr_ids)
  cat("\n--- source split ---------------------------------------------------\n")
  cat("cleaned rows:", n_before, " | REDCap-substantiated (EMR excluded):",
      nrow(data), " | EMR rows removed:", n_before - nrow(data), "\n")

  # ---- REDCap: fresh live pull (REQUIRED; errors if no token / offline) ------
  api_token <- get_api_token("detect_tool_redcap_api")   # errors loudly if absent
  rcon <- redcapConnection(url = "https://redcap.uth.tmc.edu/api/", token = api_token)
  raw <- exportRecordsTyped(rcon, forms = "reporting_instrument",
                            rawOrLabel = "raw", factor = FALSE) |>
    janitor::clean_names()

  # Only intentional raw->clean row drop (data_01_detect_tool.qmd:544)
  raw_filtered <- raw |>
    filter(!(calc_institution == 4 & password_verification == 0))

  # ---- record_id reconciliation (explains timing drift vs real bugs) ---------
  raw_ids  <- as.character(raw_filtered$record_id)
  dash_ids <- as.character(data$record_id)
  in_redcap_only <- setdiff(raw_ids, dash_ids)
  in_dash_only   <- setdiff(dash_ids, raw_ids)
  cat("\n--- record_id reconciliation ---------------------------------------\n")
  cat("REDCap (filtered):", length(raw_ids), " | dashboard:", length(dash_ids), "\n")
  cat("in REDCap but NOT dashboard (dashboard stale? refresh):", length(in_redcap_only), "\n")
  cat("in dashboard but NOT REDCap (deleted upstream?)       :", length(in_dash_only), "\n")

  # ---- Clinicians: match raw clinicians to the roster ------------------------
  roster <- read.csv(here::here("data", "clinics_physicians.csv"),
                     fileEncoding = "UTF-8-BOM")
  roster_names <- unique(trimws(roster$name_full_phys))
  raw_clin <- raw_filtered |>
    select(any_of(clinician_cols)) |>
    tidyr::pivot_longer(everything(), names_to = "field", values_to = "clinician") |>
    filter(answered(clinician)) |>
    mutate(clinician = trimws(clinician)) |>
    distinct(clinician)
  raw_clin_n      <- nrow(raw_clin)
  raw_clin_roster <- sum(raw_clin$clinician %in% roster_names)
  cat("\n--- clinician roster match -----------------------------------------\n")
  cat("distinct raw clinicians:", raw_clin_n,
      "| in roster:", raw_clin_roster,
      "| free-text (not in roster):", raw_clin_n - raw_clin_roster, "\n")

  # ---- Counts: dashboard side (mirrors detect_tool_dashboard.qmd) -------------
  dash <- c(
    survey_responses     = nrow(data),                                            # :115
    unique_mrns          = n_distinct(data$ri_patient_mrn),                       # :113
    clinicians           = n_distinct(data$ri_clinician_id_name[
                                        !is.na(data$ri_clinician_id_name)]),       # :114
    screenings_started   = data |> filter(if_any(all_of(screening_f),
                                                 ~ !is.na(.x))) |> nrow(),         # :196
    screenings_completed = sum(data$reporting_instrument_complete == "Complete",
                               na.rm = TRUE),                                       # :218
    em_status_incomplete = data |> filter(if_all(all_of(screening_f), ~ !is.na(.x))) |>
                                    filter(is.na(suspect_em_2cat)) |> nrow(),      # :250
    em_suspected         = sum(data$suspect_em_2cat_f == "Yes", na.rm = TRUE),     # :271
    intended_reports     = sum(data$ri_report_2cat_f == "Yes", na.rm = TRUE)       # :287
  )

  # ---- Counts: REDCap raw side (same predicates on raw text values) ----------
  redcap <- c(
    survey_responses     = nrow(raw_filtered),
    unique_mrns          = n_distinct(raw_filtered$ri_patient_mrn),
    clinicians           = raw_clin_n,
    screenings_started   = raw_filtered |> filter(if_any(all_of(screening_base),
                                                         ~ answered(.x))) |> nrow(),
    screenings_completed = sum(raw_filtered$reporting_instrument_complete == "Complete",
                               na.rm = TRUE),
    em_status_incomplete = raw_filtered |> filter(if_all(all_of(screening_base),
                                                         ~ answered(.x))) |>
                                            filter(!answered(suspect_em)) |> nrow(),
    em_suspected         = sum(raw_filtered$suspect_em == "Yes", na.rm = TRUE),
    intended_reports     = sum(raw_filtered$ri_report == "Yes", na.rm = TRUE)
  )

  # ---- Print full comparison (all rows, regardless of pass/fail) -------------
  cmp <- data.frame(
    count     = names(dash),
    dashboard = as.integer(dash),
    redcap    = as.integer(redcap[names(dash)]),
    row.names = NULL
  )
  cmp$match <- ifelse(cmp$dashboard == cmp$redcap, "OK", "*** MISMATCH ***")
  cat("\n--- REDCap-substantiated counts: dashboard vs REDCap ---------------\n")
  print(cmp, row.names = FALSE)
  cat("--------------------------------------------------------------------\n\n")

  # ---- Assert every count matches --------------------------------------------
  expect_equal(cmp$dashboard, cmp$redcap)
})
