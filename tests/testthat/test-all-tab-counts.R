# =============================================================================
# test-all-tab-counts.R
# =============================================================================
# Occasional-use integrity check: do the DETECT Tool 'All'-page counts the
# dashboard displays match a fresh pull from REDCap?
#
# It pulls the reporting_instrument form live, recomputes each 'All'-tab count
# directly from that pull, and prints a side-by-side table (dashboard vs REDCap)
# plus a record_id reconciliation, then asserts every count matches.
#
# REQUIRES a live REDCap pull -- there is NO offline/skip fallback by design.
# If the token is missing or the API call fails, the test errors loudly.
#
# Writes nothing. The pull stays in memory; the "displayed" side reads the
# existing (gitignored) data/detect_tool/*.RDS|*.RData. A run leaves git clean.
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


test_that("DETECT Tool 'All'-tab counts match a fresh REDCap pull", {

  # ---- Displayed side: exactly the data the dashboard renders ----------------
  cleaned_path <- here::here("data", "detect_tool", "detect_tool_cleaned.RDS")
  rdata_path   <- here::here("data", "detect_tool", "dashboard_prepped_data.RData")
  if (!file.exists(cleaned_path) || !file.exists(rdata_path)) {
    stop("Prepped data missing - run a data refresh before this test:\n  ", cleaned_path)
  }
  data <- readRDS(cleaned_path)                 # = `data` / `dt_data` in the dashboard
  prepped <- new.env(); load(rdata_path, envir = prepped)
  reports_intended <- prepped$reports_intended  # Intended Reports box source

  # ---- REDCap: fresh live pull (REQUIRED; errors if no token / offline) ------
  api_token <- get_api_token("detect_tool_redcap_api")   # errors loudly if absent
  rcon <- redcapConnection(url = "https://redcap.uth.tmc.edu/api/", token = api_token)
  raw <- exportRecordsTyped(rcon, forms = "reporting_instrument",
                            rawOrLabel = "raw", factor = FALSE) |>
    janitor::clean_names()

  # Only intentional raw->clean row drop (data_01_detect_tool.qmd:544)
  raw_filtered <- raw |>
    filter(!(calc_institution == 4 & password_verification == 0))

  # ---- record_id reconciliation (explains timing drift vs. real bugs) --------
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
    intended_reports     = nrow(reports_intended)                                 # :287
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
  cat("\n--- 'All'-tab counts: dashboard vs REDCap --------------------------\n")
  print(cmp, row.names = FALSE)
  cat("--------------------------------------------------------------------\n\n")

  # ---- Assert every count matches --------------------------------------------
  expect_equal(cmp$dashboard, cmp$redcap)
})
