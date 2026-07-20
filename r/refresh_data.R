# Refresh all dashboard data.
#
# Runs the three data-prep documents in dependency order without rendering
# them, so no HTML or _files/ bundles are produced. Each document is executed
# for its side effects: it writes the .RDS / .RData files the dashboards read.
#
#   Rscript r/refresh_data.R
#
# Run from the repository root. After each step the expected outputs are
# checked and must have been written during this run -- if an upstream step
# fails, the script stops rather than letting a downstream step build on
# stale inputs.
#
# Note: knitr::purl() extracts every code chunk, including any marked
# `eval: false`. If such a chunk is ever added to a prep document, exclude it
# here rather than relying on the render-time option.

start_time <- Sys.time()

if (!file.exists(".here") && !file.exists("_quarto.yml")) {
  stop("Run this from the repository root (no .here / _quarto.yml found).",
       call. = FALSE)
}

# Each step lists the files it must produce. Outputs marked `required = FALSE`
# may legitimately be left untouched -- see the GO-UTHealth note on step 1.
steps <- list(
  list(
    label = "DETECT tool - clean REDCap data + GO-UTHealth link traffic",
    qmd = file.path("data_management", "detect_tool",
                    "data_01_detect_tool.qmd"),
    outputs = list(
      list(path = file.path("data", "detect_tool", "detect_tool_cleaned.RDS"),
           required = TRUE),
      list(path = file.path("data_management", "detect_tool",
                            "variable_descriptions.RDS"),
           required = TRUE),
      # data_01 deliberately skips overwriting this when a GO-UTHealth pull
      # fails (e.g. expired token), reusing the last good copy instead. A
      # stale file here is expected, not an error -- it is reported below.
      list(path = file.path("data", "detect_tool",
                            "detect_tool_link_hits.RDS"),
           required = FALSE)
    )
  ),
  list(
    label = "APS reports - clean REDCap data (feeds step 3)",
    qmd = file.path("data_management", "aps_reports",
                    "data_01_aps_reports.qmd"),
    outputs = list(
      list(path = file.path("data", "aps_reports", "aps_reports_cleaned.RDS"),
           required = TRUE),
      list(path = file.path("data_management", "aps_reports",
                            "variable_descriptions.RDS"),
           required = TRUE)
    )
  ),
  list(
    label = "DETECT tool - build dashboard variables",
    qmd = file.path("data_management", "detect_tool",
                    "data_02_detect_tool.qmd"),
    outputs = list(
      list(path = file.path("data", "detect_tool",
                            "dashboard_prepped_data.RData"),
           required = TRUE)
    )
  )
)

# Execute a .qmd's code in its own environment. The prep documents pass data
# between each other through files, not memory, so isolating them keeps a
# leftover object from masking a step that silently failed to write.
run_qmd <- function(qmd) {
  if (!file.exists(qmd)) {
    stop("Missing prep document: ", qmd, call. = FALSE)
  }
  script <- knitr::purl(qmd, output = tempfile(fileext = ".R"), quiet = TRUE)
  on.exit(unlink(script), add = TRUE)
  source(script, local = new.env(parent = globalenv()), echo = FALSE)
  invisible(NULL)
}

# An output counts as refreshed only if it was written after the step began.
# Checking existence alone would pass on a file left over from a previous run.
check_outputs <- function(outputs, step_start, label) {
  stale <- character()
  for (out in outputs) {
    if (!file.exists(out$path)) {
      if (out$required) {
        stop("Step failed: ", label, "\n  Expected output was not created: ",
             out$path, call. = FALSE)
      }
      stale <- c(stale, paste0(out$path, " (missing)"))
      next
    }
    if (file.mtime(out$path) < step_start) {
      if (out$required) {
        stop("Step failed: ", label,
             "\n  Output exists but was not rewritten this run: ", out$path,
             "\n  The step likely errored before saving.", call. = FALSE)
      }
      stale <- c(stale, out$path)
    }
  }
  stale
}

stale_outputs <- character()

for (i in seq_along(steps)) {
  step <- steps[[i]]
  message("\n[", i, "/", length(steps), "] ", step$label)
  message("      ", step$qmd)

  step_start <- Sys.time()
  run_qmd(step$qmd)
  stale_outputs <- c(stale_outputs,
                     check_outputs(step$outputs, step_start, step$label))

  message("      done")
}

elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "mins")), 1)
message("\nData refresh complete (", elapsed, " min).")

if (length(stale_outputs) > 0) {
  message("\nNOT refreshed this run -- the dashboard will show older data ",
          "for:\n  - ", paste(stale_outputs, collapse = "\n  - "),
          "\nFor detect_tool_link_hits.RDS this usually means the ",
          "GO-UTHealth API token was rejected.")
}

message("\nNext: quarto render")
