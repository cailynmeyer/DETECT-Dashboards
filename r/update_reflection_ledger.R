# Update the reflection ledger from the latest cleaned DETECT tool data, so the
# dashboard can flag reflections that are new since the previous refresh.
# See r/reflection_ledger.R for how "new" is defined.
#
#   Rscript r/update_reflection_ledger.R
#
# Normally run as the last step of `Rscript r/refresh_data.R`.

source(here::here("r", "reflection_ledger.R"))

cleaned_path <- here::here("data", "detect_tool", "detect_tool_cleaned.RDS")
if (!file.exists(cleaned_path)) {
    stop("Missing ", cleaned_path,
         "\nRun `Rscript r/refresh_data.R` first.", call. = FALSE)
}

ledger_path <- reflection_ledger_path()
ledger <- if (file.exists(ledger_path)) readRDS(ledger_path) else NULL
ledger <- update_ledger(ledger, reflection_ids(readRDS(cleaned_path)))
# Always rewritten, even when nothing changed: refresh_data.R checks that each
# step's output was written during the run.
saveRDS(ledger, ledger_path)

s <- ledger_summary(ledger)
if (is.null(s$prev)) {
    message("Reflection ledger started with ", nrow(ledger$ids),
            " reflection(s); new ones are flagged from the next refresh day.")
} else {
    message(s$n_new, " new reflection(s) since ", s$prev, ".")
}
