# ─────────────────────────────────────────────────────────────────────────────
# reshape_new_detect_data.R
#
# PURPOSE
#   Reshape a local Excel export of new DETECT tool submissions (long format:
#   one row per question) into the RAW `tool_raw` layout, so data_01 can
#   bind_rows() it onto the REDCap pull and clean both together in one pass.
#
#   Produces + saves: `excel_raw` (base ri_* columns holding raw TEXT values,
#   matching what data_01 expects BEFORE its cleaning steps run).
#   Output: data/detect_tool/detect_tool_excel_raw.RDS
#
# INPUT LAYOUT (this export)
#   PAT_ID  : patient id  -> groups a submission (detect_id = PAT_ID + date)
#   MRN     : medical record number -> ri_patient_mrn (unique-patient count + APS linkage)
#   dttm    : per-row documentation SUBMISSION datetime -> date + reporting timestamp
#   c       : question number (e.g. "UTP544"); UTP544 = documentation START time
#             as a 10-digit Unix epoch -> ri_timestamp_start (metadata, not clinical)
#   name    : question text
#   value   : response value
#
#   detect_id = PAT_ID + date(dttm). Because dttm is per row, submissions on
#   different days separate cleanly; two submissions by one patient on the SAME
#   day would share a detect_id and surface in the section-4 duplicate guard.
#
# HOW IT WIRES IN (data_01_detect_tool.qmd)
#   After var_desc is built (just before `tool <- tool_raw %>% ...`), add:
#     excel_raw_path <- here::here("data","detect_tool","detect_tool_excel_raw.RDS")
#     if (file.exists(excel_raw_path)) {
#       tool_raw <- dplyr::bind_rows(tool_raw, readr::read_rds(excel_raw_path))
#     }
#
# STILL TO CONFIRM  (run inspect_new_data_structure.R first)
#   [C] q_num -> ri_var mapping        -> `qnum_for` in section 3
#   [D] raw response strings per item  -> the *_map lookups in section 6
# ─────────────────────────────────────────────────────────────────────────────

library(readxl)
library(dplyr)
library(tidyr)
library(tibble)
library(stringr)
library(here)

# --- 0. Config ---------------------------------------------------------------
# UTP EMR exports are named EMR_data_YYYY_MM_DD.xlsx; use the newest one on disk.
EXCEL_PATH <- local({
    fs <- list.files(
        here::here("data", "detect_tool"),
        pattern = "^EMR_data_[0-9]{4}[-_][0-9]{2}[-_][0-9]{2}\\.xlsx$", full.names = TRUE
    )
    if (length(fs) == 0) {
        stop("No EMR_data_YYYY-MM-DD.xlsx found in data/detect_tool.", call. = FALSE)
    }
    d <- as.Date(gsub("_", "-", sub(".*EMR_data_([0-9]{4}[-_][0-9]{2}[-_][0-9]{2})\\.xlsx$", "\\1", fs)),
                 format = "%Y-%m-%d")
    fs[which.max(d)]  # newest pull
})
SHEET            <- "vSMRTDATAv"   # tab to read (the workbook has two tabs).
                                   #   Matched exactly first, then by prefix (e.g. vSMRTDATAv2).
INSTITUTION_CODE <- 7   # 1=Baylor 2=JH 3=UCSF 4=UAB 5=UTSW 6=LBJ 7=UTP
# Raw institution TEXT must be the exact label data_01 maps to code 7:
INSTITUTION_NAME <- "UTH Houston - UT Physicians House Calls"

# Long-format column headers:
COL_PATIENT_ID <- "PAT_ID"       # patient id used to GROUP a submission
COL_MRN        <- "MRN"          # medical record number -> ri_patient_mrn
COL_DATE       <- "dttm"         # per-row documentation SUBMISSION datetime
COL_QNUM       <- "ELEMENT_ID"   # question-number column ("UTP544" -> 544)
COL_NAME       <- "name"         # question-name column
COL_VALUE      <- "value"        # response-value column

# Documentation START time question (metadata, NOT clinical -- keep out of qnum_for):
QNUM_TS_START  <- 544            # 'c' UTP544 = start time
START_TS_EPOCH <- TRUE           # TRUE: UTP544 value is a 10-digit Unix epoch (seconds).
                                 #   FALSE: parse it as text with TS_FORMAT instead.

# Parse overrides (leave NULL unless a parse below yields NAs):
DTTM_FORMAT <- NULL              # for 'dttm'; NULL uses "%Y-%m-%d %H:%M:%S" (handles the
                                 #   "2026-06-16 10:07:51 UTC" form -- trailing tz is stripped)
TS_FORMAT   <- NULL              # for UTP544 when START_TS_EPOCH = FALSE

# Reflection: the DETECT tool has TWO fields -- ri_reflection (Yes/No, "Have
# helpful details") and ri_reflection_notes (free text, "Brief note"). If the
# smartform supplies only ONE (mapped to ri_reflection in qnum_for), say what it
# holds:
#   "notes" -> it's the free-text note. Move it to ri_reflection_notes and derive
#              ri_reflection = "Yes" when a note is present, else "No".
#   "flag"  -> it's the Yes/No. Keep as ri_reflection; leave ri_reflection_notes NA.
REFLECTION_FIELD <- "notes"

# --- 1. Read the long-format export + build detect_id ------------------------
# Resolve the target tab (exact match, else prefix match) so we never read the
# wrong sheet of the two-tab workbook.
.sheets    <- readxl::excel_sheets(EXCEL_PATH)
sheet_name <- .sheets[c(which(tolower(trimws(.sheets)) == tolower(trimws(SHEET))),
                        grep(paste0("^", SHEET), .sheets, ignore.case = TRUE))[1]]
if (length(sheet_name) == 0 || is.na(sheet_name)) {
  stop("Sheet '", SHEET, "' not found. Tabs: ", paste(.sheets, collapse = ", "),
       call. = FALSE)
}
message("Reading sheet: ", sheet_name)

raw0 <- readxl::read_excel(EXCEL_PATH, sheet = sheet_name)
names(raw0) <- trimws(names(raw0))               # drop stray header whitespace

# Resolve a configured column name to the real header (trim + case-insensitive).
pick <- function(want) {
  hit <- which(tolower(names(raw0)) == tolower(trimws(want)))
  if (length(hit) == 0) {
    stop("Column '", want, "' not found on sheet '", sheet_name, "'. Available: ",
         paste(names(raw0), collapse = ", "), call. = FALSE)
  }
  names(raw0)[hit[1]]
}

parse_dttm <- function(x) {
  if (inherits(x, "POSIXct")) return(x)                      # already a datetime -> use as-is
  if (inherits(x, "Date"))    return(as.POSIXct(x, tz = "UTC"))
  x   <- as.character(x)
  x   <- sub("\\s+[A-Za-z]{2,5}$", "", trimws(x))            # strip trailing tz name, e.g. " UTC"
  fmt <- if (!is.null(DTTM_FORMAT)) DTTM_FORMAT else "%Y-%m-%d %H:%M:%S"
  as.POSIXct(x, format = fmt, tz = "UTC")
}
parse_start_ts <- function(x) {
  if (START_TS_EPOCH)      as.POSIXct(as.numeric(x), origin = "1970-01-01", tz = "UTC")
  else if (!is.null(TS_FORMAT)) as.POSIXct(as.character(x), format = TS_FORMAT, tz = "UTC")
  else                     as.POSIXct(as.character(x), tz = "UTC")
}

long0 <- raw0 %>%
  transmute(
    patient_id = as.character(.data[[pick(COL_PATIENT_ID)]]),
    mrn        = as.character(.data[[pick(COL_MRN)]]),
    sub_dttm   = parse_dttm(.data[[pick(COL_DATE)]]),
    q_num      = as.integer(stringr::str_extract(as.character(.data[[pick(COL_QNUM)]]), "\\d+")),
    name       = as.character(.data[[pick(COL_NAME)]]),
    value      = as.character(.data[[pick(COL_VALUE)]])
  ) %>%
  mutate(
    sub_date  = as.Date(sub_dttm, tz = "UTC"),   # explicit tz so the day never shifts
    detect_id = paste0(patient_id, "_", format(sub_date, "%Y%m%d"))
  )

no_date <- long0 %>% filter(is.na(sub_date)) %>% distinct(patient_id)
if (nrow(no_date) > 0) {
  warning(nrow(no_date), " patient(s) have an unparseable 'dttm'; their rows will ",
          "be dropped. Check COL_DATE / DTTM_FORMAT.")
}

# --- 2. Submission metadata (one row per detect_id) --------------------------
# Start time from UTP544 (epoch), keyed by detect_id.
ts_start <- long0 %>%
  filter(q_num == QNUM_TS_START) %>%
  transmute(detect_id, ts_start = parse_start_ts(value)) %>%
  distinct()

submission_meta <- long0 %>%
  filter(!is.na(sub_date)) %>%
  group_by(detect_id) %>%
  summarise(
    patient_id = dplyr::first(patient_id),
    mrn        = dplyr::first(mrn),
    sub_date   = dplyr::first(sub_date),
    ts_submit  = dplyr::first(sub_dttm),   # documentation submission time
    .groups    = "drop"
  ) %>%
  left_join(ts_start, by = "detect_id")

# --- 3. Crosswalk: question number (q_num) -> raw ri_* column ------------------
# [C] Fill in each CLINICAL question number from the inspector's catalog. Leave
#     NA for items the smartform doesn't collect (they bind as NA).
#     Do NOT put UTP544 (start time) here -- it is handled as metadata above.
qnum_for <- c(
  #  ri_variable            = <col 'c' #>   # question meaning (match against `name`)
  ri_necessities           = 521,  # Absence of necessities
  ri_environment           = 522,  # Environment health or safety concern
  ri_caregiver             = 524,  # Defensive
  ri_sedated               = 527,  # Chemically sedated
  ri_isolated              = 528,  # Isolated
  ri_anxious               = 529,  # Anxious
  ri_prohibited            = 530,  # Prohibited
  ri_unmet_needs           = 531,  # Unmet needs
  ri_injuries              = 532,  # Unexplained injuries
  suspect_em               = 534,  # Suspect EM (yes/no)
  ri_em_no_reason          = 535,   # Indicators observed but EM not suspected - reason
  ri_em_reason             = NA,   # Suspect EM - reason
  ri_em_type_1             = NA,   # Self-neglect suspected
  ri_em_type_2             = NA,   # Financial exploitation suspected
  ri_em_type_3             = NA,   # Emotional or psychological abuse suspected
  ri_em_type_4             = NA,   # Physical abuse suspected
  ri_em_type_5             = NA,   # Sexual abuse suspected
  ri_em_type_6             = NA,   # Caregiver neglect suspected
  ri_em_type_7             = NA,   # Abandonment suspected
  ri_em_type_98            = NA,   # Other mistreatment type suspected
  ri_em_type_99            = NA,   # Don't know / not sure of mistreatment type
  ri_em_type_other         = NA,   # Specific other mistreatment type (text)
  ri_environment_un_reason = NA,   # Environment not assessed - reason
  ri_caregiver_un_reason   = NA,   # Caregiver not assessed - reason
  ri_caregiver_oth         = NA,   # Other reason caregiver not assessed (text)
  ri_patient_assess        = 533,  # Patient not assessed - reason
  ri_report                = NA,   # Intend to report to APS (yes/no)
  ri_aps_no_reason         = NA,   # No intention to report to APS - reason
  ri_refer_svcs            = NA,   # Other service referral (yes/no)
  ri_refer_svcs_specify    = NA,   # Specify other service (text)
  ri_reflection            = 778,  # Have helpful details / reflection (see REFLECTION_FIELD)
  ri_reflection_notes      = NA    # Brief note (text) -- leave NA if REFLECTION_FIELD = "notes"
)

crosswalk <- tibble::tibble(
  ri_var = names(qnum_for),
  q_num  = as.integer(unname(qnum_for))
) %>% filter(!is.na(q_num))

# --- 4. Guard: one response per (detect_id, question) ------------------------
dupes <- long0 %>%
  filter(q_num %in% crosswalk$q_num) %>%
  count(detect_id, q_num) %>%
  filter(n > 1)
if (nrow(dupes) > 0) {
  warning(nrow(dupes), " duplicate (detect_id, question) pairs -- inspect:")
  print(dupes)
}

# --- 5. Join crosswalk + pivot wide (columns come out named ri_*) ------------
long_mapped <- long0 %>%
  filter(!is.na(sub_date), q_num %in% crosswalk$q_num) %>%
  left_join(crosswalk, by = "q_num")

unmapped <- long0 %>%
  filter(!q_num %in% crosswalk$q_num, q_num != QNUM_TS_START) %>%
  distinct(q_num, name)
if (nrow(unmapped) > 0) {
  message("Note: ", nrow(unmapped), " question number(s) not mapped (ignored). ",
          "Add clinical ones to qnum_for if they belong:")
  print(unmapped)
}

wide <- long_mapped %>%
  distinct(detect_id, ri_var, value) %>%
  pivot_wider(
    id_cols     = detect_id,
    names_from  = ri_var,
    values_from = value
  )

# --- 5b. Reflection: populate both fields from the single source -------------
if (REFLECTION_FIELD == "notes" &&
    "ri_reflection" %in% names(wide) &&
    !"ri_reflection_notes" %in% names(wide)) {
  wide <- wide %>%
    mutate(
      ri_reflection_notes = ri_reflection,                         # mapped field is the note text
      ri_reflection = if_else(!is.na(ri_reflection_notes) &
                                trimws(ri_reflection_notes) != "", "Yes", "No")
    )
}

# --- 6. Recode VALUES to the raw text data_01 expects ------------------------
# named-vector lookup -> any value NOT on the LEFT becomes NA. The RIGHT side is
# fixed by data_01 and must stay as written. Put YOUR raw strings on the LEFT
# ([D], from the inspector's value profile).
recode_vals <- function(x, map) unname(map[as.character(x)])

# data_01 screening items expect: "Yes" / "No" / "Unable to assess"
yn3_map <- c("Yes" = "Yes", "No" = "No", "Unable to assess" = "Unable to assess")  # TODO left side
# data_01 yes/no items expect: "Yes" / "No".
# The smartform codes these as binary 1/0 (suspect_em, etc.); accept both codings.
yn2_map <- c("Yes" = "Yes", "No" = "No", "1" = "Yes", "0" = "No")
# data_01 EM-type items expect: "Checked" / "Unchecked" (it maps these to Yes/No)
chk_map <- c("Checked" = "Checked", "Unchecked" = "Unchecked")                      # TODO left side

screen_3cat <- c("ri_necessities", "ri_environment", "ri_caregiver", "ri_sedated",
                 "ri_isolated", "ri_anxious", "ri_prohibited", "ri_unmet_needs",
                 "ri_injuries")
yn2_cols    <- c("suspect_em", "ri_report", "ri_refer_svcs", "ri_reflection")
emtype_cols <- paste0("ri_em_type_", c(1:7, 98, 99))

wide <- wide %>%
  mutate(
    across(any_of(screen_3cat), ~ recode_vals(.x, yn3_map)),
    across(any_of(yn2_cols),    ~ recode_vals(.x, yn2_map)),
    across(any_of(emtype_cols), ~ recode_vals(.x, chk_map))
  )

# --- 7. Add meta columns (join submission metadata; derive from timestamps) ----
# record_id holds detect_id (PAT_ID + date). ri_patient_mrn holds the real MRN.
# Neither is displayed by the dashboard (textbox/summary views never select them).
excel_raw <- wide %>%
  left_join(submission_meta, by = "detect_id") %>%
  mutate(
    record_id                      = detect_id,
    ri_patient_mrn                 = suppressWarnings(as.numeric(mrn)),
    ri_timestamp_start             = dplyr::coalesce(ts_start, ts_submit),  # UTP544, else submit
    reporting_instrument_timestamp = format(ts_submit, "%Y-%m-%d %H:%M:%S"),
    ri_date                        = sub_date,
    reporting_instrument_complete  = "Complete",        # TODO if incomplete is tracked
    calc_institution               = INSTITUTION_CODE,
    ri_institution                 = INSTITUTION_NAME,
    ri_institution_2               = INSTITUTION_NAME,
    ri_clinician_id                = NA_character_,
    password_verification          = NA_real_
  ) %>%
  select(-detect_id, -patient_id, -mrn, -sub_date, -ts_start, -ts_submit)

message("excel_raw: ", nrow(excel_raw), " rows x ", ncol(excel_raw), " cols")

# --- 8. Save (decoupled RDS; data/ is gitignored) ----------------------------
out_path <- here::here("data", "detect_tool", "detect_tool_excel_raw.RDS")
saveRDS(excel_raw, out_path)
message("Saved: ", out_path)
