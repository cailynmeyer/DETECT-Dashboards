# =============================================================================
# test-utp-manual-counts.R
# =============================================================================
# Integrity check for the UTP (UT Physicians) rows that are MANUALLY UPLOADED
# from the EMR export -- i.e. the rows produced by
# data_management/detect_tool/reshape_pulled_emr_data.R and bound onto the
# REDCap pull by data_01. It confirms those rows survived reshape -> bind ->
# clean intact and that their dashboard counts match the reshaped source.
#
# OFFLINE by design: reads only the two local (gitignored) files
#   - data/detect_tool/detect_tool_excel_raw.RDS   (reshape output = raw source)
#   - data/detect_tool/detect_tool_cleaned.RDS      (what the dashboard renders)
# No REDCap token or network needed. If no EMR export has been reshaped yet
# (excel_raw missing), the test skips rather than fails -- manual data is optional.
#
# The EMR rows are identified EXACTLY by their record_ids (record_id in
# excel_raw$record_id), not by a pattern guess, so a change to the id scheme
# won't silently mis-scope the check.
#
# Writes nothing. Run after a data refresh:
#   testthat::test_dir("tests/testthat")
#
# Count definitions mirror sections/detect_tool_dashboard.qmd, scoped to UTP.
# =============================================================================

library(testthat)
library(dplyr)

UTP_LABEL <- "UTH Houston - UT Physicians House Calls"

# 9 screening-indicator fields: raw base names + cleaned factor equivalents
screening_base <- c("ri_necessities", "ri_environment", "ri_caregiver", "ri_sedated",
                    "ri_isolated", "ri_anxious", "ri_prohibited", "ri_unmet_needs",
                    "ri_injuries")
screening_f    <- paste0(screening_base, "_3cat_f")

answered <- function(x) !is.na(x) & trimws(as.character(x)) != ""


test_that("UTP manually-uploaded (EMR) rows match the reshaped source", {

  excel_raw_path <- here::here("data", "detect_tool", "detect_tool_excel_raw.RDS")
  cleaned_path   <- here::here("data", "detect_tool", "detect_tool_cleaned.RDS")

  if (!file.exists(excel_raw_path)) {
    skip("No reshaped EMR data (detect_tool_excel_raw.RDS) present - manual upload is optional.")
  }
  if (!file.exists(cleaned_path)) {
    stop("Cleaned data missing - run a data refresh before this test:\n  ", cleaned_path)
  }

  excel_raw <- readRDS(excel_raw_path)   # raw source: one row per EMR submission
  data      <- readRDS(cleaned_path)     # = `data` / `dt_data` in the dashboard

  # ---- Scope: the dashboard rows that came from the EMR upload ----------------
  emr_ids  <- as.character(excel_raw$record_id)
  dash_emr <- data |> filter(as.character(record_id) %in% emr_ids)

  # ---- Reconcile which ids made it through cleaning --------------------------
  present  <- sum(emr_ids %in% as.character(data$record_id))
  missing  <- setdiff(emr_ids, as.character(data$record_id))
  cat("\n--- EMR row reconciliation -----------------------------------------\n")
  cat("reshaped EMR rows:", length(emr_ids),
      "| present in dashboard:", present,
      "| dropped during cleaning:", length(missing), "\n")
  if (length(missing) > 0) cat("  dropped record_ids:", paste(head(missing, 20), collapse = ", "), "\n")

  # Every reshaped EMR row should appear in the cleaned data (UTP rows are never
  # dropped by data_01 -- the only intentional drop is UAB password rows).
  expect_equal(present, length(emr_ids))

  # ---- All EMR-sourced dashboard rows must be UTP ----------------------------
  bad_inst <- dash_emr |> filter(is.na(calc_institution_7cat_f) |
                                   calc_institution_7cat_f != UTP_LABEL)
  expect_equal(nrow(bad_inst), 0)

  # ---- Counts: dashboard EMR subset (cleaned) vs reshaped source (raw) --------
  # Only mapped items are compared; unmapped source columns (e.g. ri_report) are
  # absent from excel_raw, so any_of() keeps the recompute robust.
  sf_dash  <- intersect(screening_f, names(dash_emr))
  sb_raw   <- intersect(screening_base, names(excel_raw))

  dash <- c(
    rows                 = nrow(dash_emr),
    unique_mrns          = n_distinct(dash_emr$ri_patient_mrn),
    screenings_started   = dash_emr |> filter(if_any(all_of(sf_dash), ~ !is.na(.x))) |> nrow(),
    screenings_completed = sum(dash_emr$reporting_instrument_complete == "Complete", na.rm = TRUE),
    em_suspected         = sum(dash_emr$suspect_em_2cat_f == "Yes", na.rm = TRUE)
  )

  src <- c(
    rows                 = nrow(excel_raw),
    unique_mrns          = n_distinct(excel_raw$ri_patient_mrn),
    screenings_started   = excel_raw |> filter(if_any(all_of(sb_raw), ~ answered(.x))) |> nrow(),
    screenings_completed = sum(excel_raw$reporting_instrument_complete == "Complete", na.rm = TRUE),
    em_suspected         = sum(excel_raw$suspect_em == "Yes", na.rm = TRUE)
  )

  cmp <- data.frame(
    count     = names(dash),
    dashboard = as.integer(dash),
    source    = as.integer(src[names(dash)]),
    row.names = NULL
  )
  cmp$match <- ifelse(cmp$dashboard == cmp$source, "OK", "*** MISMATCH ***")
  cat("\n--- UTP manual (EMR) counts: dashboard vs reshaped source ----------\n")
  print(cmp, row.names = FALSE)
  cat("--------------------------------------------------------------------\n\n")

  expect_equal(cmp$dashboard, cmp$source)
})
