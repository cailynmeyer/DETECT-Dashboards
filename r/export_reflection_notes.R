# Export every free-text response to the DETECT tool's "additional notes /
# story" question to an Excel workbook for manual review.
#
# The question is captured in REDCap as two linked fields:
#   ri_reflection       "Do you have any other details ... that would be
#                        helpful for us to know?"            (Yes / No)
#   ri_reflection_notes "Please briefly describe."           (free text)
# ri_reflection_notes is the response this script exports; ri_reflection is
# carried along as the gate that made the text box appear.
#
# Both data sources end up in the export:
#   * REDCap  - the reporting_instrument form (all institutions).
#   * UT Physicians - submissions captured in the EMR and hand-exported to
#     data/detect_tool/EMR_data_YYYY-MM-DD.xlsx. reshape_pulled_emr_data.R
#     maps the smartform's note field onto ri_reflection_notes, so those rows
#     carry the same variable and are exported alongside the REDCap rows.
#
# Usage (from the repository root):
#
#   Rscript r/export_reflection_notes.R                 # from saved data (fast)
#   Rscript r/export_reflection_notes.R --live          # fresh REDCap API pull
#   Rscript r/export_reflection_notes.R --out notes.xlsx
#
# --live re-pulls the reflection fields straight from REDCap, so it picks up
# submissions entered since the last `Rscript r/refresh_data.R`. It needs the
# same detect_tool_redcap_api token the prep scripts use, and it still reads the
# UT Physicians rows from the saved reshape output (that export is manual, so
# there is nothing live to pull).
#
# Only submissions that answered Yes to ri_reflection are exported. The workbook
# opens on a "Summary by Site" tab and then gives each site its own tab, so the
# note rows carry no site column -- the tab name is the site.
#
# entry_id traces a note back to its screening report: it is the REDCap
# record_id for REDCap rows and PAT_ID_YYYYMMDD for UT Physicians EMR rows.
# patient_mrn is carried alongside it for the same reason.
#
# The workbook is written under data/ (gitignored) because these notes are
# free-text clinician narrative and can contain identifiable detail.

suppressPackageStartupMessages({
  library(dplyr, warn.conflicts = FALSE)
  library(here)
})

# ---- Options ---------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

live <- "--live" %in% args

out_path <- local({
  i <- match("--out", args)
  if (!is.na(i)) {
    if (length(args) < i + 1L) {
      stop("--out needs a file path after it.", call. = FALSE)
    }
    args[[i + 1L]]
  } else {
    here::here("data", "detect_tool",
               paste0("reflection_notes_", Sys.Date(), ".xlsx"))
  }
})

unknown <- setdiff(args, c("--live", "--out", out_path))
if (length(unknown) > 0) {
  stop("Unrecognized argument(s): ", paste(unknown, collapse = ", "),
       "\nUsage: Rscript r/export_reflection_notes.R [--live] [--out PATH]",
       call. = FALSE)
}

if (!file.exists(here::here(".here")) && !file.exists(here::here("_quarto.yml"))) {
  stop("Run this from the repository root (no .here / _quarto.yml found).",
       call. = FALSE)
}

cleaned_path   <- here::here("data", "detect_tool", "detect_tool_cleaned.RDS")
excel_raw_path <- here::here("data", "detect_tool", "detect_tool_excel_raw.RDS")

# Shared with data_01_detect_tool.qmd -- keep in sync if REDCap adds a site.
institution_labels <- c(
  "Baylor College of Medicine - BT House Calls"  = 1,
  "Johns Hopkins - JHOME"                        = 2,
  "UCSF - Care at Home Program"                  = 3,
  "University of Alabama - UAB House Calls"      = 4,
  "UT Southwestern - COVE"                       = 5,
  "UTH Houston - LBJ House Calls"                = 6,
  "UTH Houston - UT Physicians House Calls"      = 7
)

# ---- Load the notes --------------------------------------------------------

# Rows reshaped from the UT Physicians EMR export, identified by record_id so we
# can label each note with the source it came from.
utp_record_ids <- if (file.exists(excel_raw_path)) {
  as.character(readr::read_rds(excel_raw_path)$record_id)
} else {
  character()
}

# Falls back to the record_id shape reshape_pulled_emr_data.R builds
# (PAT_ID_YYYYMMDD) when the reshape output isn't on disk; REDCap record_ids are
# plain integers, so the two never collide.
label_source <- function(record_id) {
  id <- as.character(record_id)
  is_utp <- if (length(utp_record_ids) > 0) {
    id %in% utp_record_ids
  } else {
    grepl("_[0-9]{8}$", id)
  }
  ifelse(is_utp, "UT Physicians EMR export", "REDCap")
}

redcap_pid <- NA_integer_

if (live) {
  suppressPackageStartupMessages({
    library(redcapAPI)
    library(janitor)
  })
  source(here::here("r", "get_api_token.R"))

  message("Pulling reflection fields from REDCap ...")
  rcon <- redcapConnection(url   = "https://redcap.uth.tmc.edu/api/",
                           token = get_api_token("detect_tool_redcap_api"))

  # Project id is only used to build a click-through link back to the record.
  redcap_pid <- tryCatch(
    as.integer(exportProjectInformation(rcon)$project_id),
    error = function(e) NA_integer_
  )

  clinician_fields <- paste0(
    "ri_clinician_",
    c("bcm", "bcm_oth", "jh", "jh_oth", "ucsf", "ucsf_oth", "uab", "uab_oth",
      "utsw", "utsw_oth", "lbj", "lbj_oth", "utp", "utp_oth")
  )

  raw <- exportRecordsTyped(
    rcon,
    fields = c("record_id", "ri_date", "ri_timestamp_start", "ri_patient_mrn",
               "calc_institution", "ri_clinician_id_2", clinician_fields,
               "password_verification", "ri_reflection", "ri_reflection_notes"),
    forms      = "reporting_instrument",
    rawOrLabel = "raw",
    factor     = FALSE
  ) %>%
    clean_names() %>%
    rename(ri_clinician_id = ri_clinician_id_2) %>%
    mutate(across(where(is.factor), as.character))

  redcap_notes <- raw %>%
    # Same exclusion data_01 applies: UAB rows that failed password verification
    # are not real submissions.
    filter(!(as.numeric(calc_institution) == 4 &
               as.numeric(password_verification) == 0 &
               !is.na(password_verification))) %>%
    transmute(
      record_id,
      date         = as.Date(ri_date),
      submitted    = as.POSIXct(reporting_instrument_timestamp, tz = "UTC"),
      site         = factor(as.numeric(calc_institution),
                            levels = as.numeric(institution_labels),
                            labels = names(institution_labels)),
      clinician    = coalesce(!!!rlang::syms(rev(clinician_fields))),
      clinician_id = as.character(ri_clinician_id),
      patient_mrn  = as.character(ri_patient_mrn),
      helpful_details_flag = recode(as.character(ri_reflection),
                                    "1" = "Yes", "0" = "No"),
      note = ri_reflection_notes
    )

  # The UT Physicians rows have no live source -- take them from the saved
  # reshape output so --live is still a complete picture.
  utp_notes <- if (file.exists(excel_raw_path)) {
    readr::read_rds(excel_raw_path) %>%
      transmute(
        record_id    = as.character(record_id),
        date         = as.Date(ri_date),
        submitted    = as.POSIXct(reporting_instrument_timestamp, tz = "UTC"),
        site         = factor(as.numeric(calc_institution),
                              levels = as.numeric(institution_labels),
                              labels = names(institution_labels)),
        clinician    = NA_character_,
        clinician_id = NA_character_,
        patient_mrn  = as.character(ri_patient_mrn),
        helpful_details_flag = as.character(ri_reflection),
        note = ri_reflection_notes
      )
  } else {
    message("No ", basename(excel_raw_path), " on disk -- REDCap rows only. ",
            "Run Rscript r/refresh_data.R to reshape the latest EMR export.")
    NULL
  }

  notes <- bind_rows(redcap_notes, utp_notes)
  source_files <- c(if (!is.null(utp_notes)) excel_raw_path,
                    "REDCap API (live pull)")
} else {
  if (!file.exists(cleaned_path)) {
    stop("Missing ", cleaned_path,
         "\nRun `Rscript r/refresh_data.R` first, or re-run this with --live.",
         call. = FALSE)
  }
  message("Reading saved data: ", cleaned_path)

  notes <- readr::read_rds(cleaned_path) %>%
    transmute(
      record_id    = as.character(record_id),
      date         = as.Date(ri_date),
      submitted    = timestamp_end,
      site         = calc_institution_7cat_f,
      clinician    = ri_clinician_id_name,
      clinician_id = as.character(ri_clinician_id),
      patient_mrn  = as.character(ri_patient_mrn),
      helpful_details_flag = as.character(ri_reflection_2cat_f),
      note = ri_reflection_notes
    )
  source_files <- cleaned_path
}

# ---- Shape the review sheet ------------------------------------------------

# Only submissions that answered Yes to the gate question are in scope -- a No
# or an unanswered gate means there was never a note to review.
eligible <- notes %>% filter(helpful_details_flag %in% "Yes")

# Someone can answer Yes and still leave the box empty; those are counted for the
# console rather than shipped as blank rows in the review sheets.
blank_notes <- sum(is.na(eligible$note) | !nzchar(trimws(eligible$note)))

notes <- eligible %>%
  filter(!is.na(note), nzchar(trimws(note))) %>%
  mutate(
    # Source is not a column in the export -- site already says where a note came
    # from -- but it still decides which rows get a REDCap link.
    redcap_link = if (!is.na(redcap_pid)) {
      ifelse(label_source(record_id) == "REDCap",
             paste0("https://redcap.uth.tmc.edu/redcap_v14.5.11/DataEntry/",
                    "record_home.php?pid=", redcap_pid, "&id=", record_id),
             NA_character_)
    } else {
      NA_character_
    },
    note_chars = nchar(note)
  ) %>%
  arrange(desc(date), site, record_id) %>%
  select(
    entry_id = record_id,
    date,
    submitted,
    site,
    clinician,
    clinician_id,
    patient_mrn,
    helpful_details_flag,
    note_chars,
    redcap_link,
    note
  )
# `site` is kept here only to split the rows into per-site sheets below; it is
# dropped from each sheet, where the tab name already says the site.

if (nrow(notes) == 0) {
  stop("No reflection notes found among submissions that answered Yes to the ",
       "gate question -- nothing to export.", call. = FALSE)
}

# Drop the link column entirely rather than shipping a column of blanks.
if (all(is.na(notes$redcap_link))) {
  notes <- select(notes, -redcap_link)
}

# Every institution stays on the summary and keeps its own tab, including the
# ones with no notes this run -- a zero is a finding (UT Physicians, for one,
# does not collect the question at all), and a silently missing site reads as
# lost data. `.drop = FALSE` keeps the unused factor levels.
summary_by_site <- notes %>%
  count(site, name = "notes", .drop = FALSE) %>%
  arrange(desc(notes), site)

missing_site <- sum(is.na(notes$site))
if (missing_site > 0) {
  warning(missing_site, " note(s) have no institution and are on no site tab.",
          call. = FALSE)
}

# ---- Write the workbook ----------------------------------------------------

# Excel caps tab names at 31 characters and rejects : \ / ? * [ ], so the full
# institution labels can't be used as-is. Anything not listed falls back to a
# sanitized truncation.
sheet_name_for <- function(site) {
  short <- c(
    "Baylor College of Medicine - BT House Calls" = "Baylor BT",
    "Johns Hopkins - JHOME"                       = "Johns Hopkins JHOME",
    "UCSF - Care at Home Program"                 = "UCSF Care at Home",
    "University of Alabama - UAB House Calls"     = "UAB House Calls",
    "UT Southwestern - COVE"                      = "UTSW COVE",
    "UTH Houston - LBJ House Calls"               = "LBJ House Calls",
    "UTH Houston - UT Physicians House Calls"     = "UT Physicians House Calls"
  )
  site <- as.character(site)
  ifelse(site %in% names(short), unname(short[site]),
         substr(gsub("[:\\\\/?*\\[\\]]", " ", site), 1, 31))
}

# One tab per site, in the same order as the summary. A site with no notes gets
# an empty tab -- column headers, no rows.
sites_all <- as.character(summary_by_site$site)

site_sheets <- lapply(sites_all, function(s) {
  notes %>%
    filter(!is.na(site), as.character(site) == s) %>%
    select(-site)
})
names(site_sheets) <- sheet_name_for(sites_all)

# Summary first, then the per-site tabs.
sheets <- c(list("Summary by Site" = summary_by_site), site_sheets)

dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)

if (nzchar(system.file(package = "writexl"))) {
  writexl::write_xlsx(sheets, path = out_path)
} else if (nzchar(system.file(package = "openxlsx"))) {
  openxlsx::write.xlsx(sheets, file = out_path)
} else {
  # Neither Excel writer is installed -- don't fail after doing all the work.
  csv_path <- sub("\\.xlsx$", ".csv", out_path)
  readr::write_excel_csv(notes, csv_path)
  message("Neither 'writexl' nor 'openxlsx' is installed, so this was written ",
          "as CSV instead:\n  ", csv_path,
          "\nInstall an Excel writer for .xlsx output: renv::install(\"writexl\")")
  quit(save = "no")
}

message("\nSource(s): ", paste(source_files, collapse = "; "))
if (blank_notes > 0) {
  message(blank_notes, " submission(s) answered Yes but left the note blank ",
          "-- not exported.")
}
message("Wrote ", nrow(notes), " reflection note(s) across ",
        length(site_sheets), " site tab(s) to:\n  ", out_path)
print(as.data.frame(summary_by_site), row.names = FALSE)
