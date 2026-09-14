# Reflection ledger: when each reflection note first appeared in the data.
#
# Lets the DETECT Tool dashboard flag reflections that are new since the
# previous data refresh. A reflection is a submission that answered Yes to
# ri_reflection and left a non-blank ri_reflection_notes -- the same rows
# r/export_reflection_notes.R exports for review.
#
# The ledger is saved to data/detect_tool/reflection_ledger.RDS by
# r/update_reflection_ledger.R (the last step of r/refresh_data.R):
#
#   refreshes  Date vector of every distinct day the ledger was updated.
#   ids        tibble(record_id, first_seen) -- the refresh day each reflection
#              was first seen on.
#
# "New" is judged against the previous refresh, not the submission date: UT
# Physicians EMR rows arrive by manual export, often carrying older dates, and
# should still be flagged when they first show up.

reflection_ledger_path <- function() {
    here::here("data", "detect_tool", "reflection_ledger.RDS")
}

# Record ids of every reflection in the cleaned DETECT tool data.
reflection_ids <- function(cleaned) {
    has_note <- !is.na(cleaned$ri_reflection_notes) &
        nzchar(trimws(cleaned$ri_reflection_notes))
    unique(as.character(
        cleaned$record_id[cleaned$ri_reflection_2cat_f %in% "Yes" & has_note]
    ))
}

# Add today's reflection ids to `ledger` (NULL when none exists yet). Re-running
# on the same day changes nothing, so a second refresh does not reset the count.
update_ledger <- function(ledger, current_ids, today = Sys.Date()) {
    current_ids <- unique(as.character(current_ids))
    today <- as.Date(today)

    if (is.null(ledger)) {
        return(list(
            refreshes = today,
            ids = tibble::tibble(record_id = current_ids, first_seen = today)
        ))
    }

    # Ids that drop out of the data stay in the ledger, so they are never
    # re-counted as new if they come back.
    unseen <- setdiff(current_ids, ledger$ids$record_id)
    ledger$ids <- dplyr::bind_rows(
        ledger$ids,
        tibble::tibble(record_id = unseen,
                       first_seen = rep(today, length(unseen)))
    )
    ledger$refreshes <- sort(unique(c(ledger$refreshes, today)))
    ledger
}

# Reflections first seen on the latest refresh, against the refresh before it.
# `prev` is NULL until there have been two refresh days -- everything in the
# first run was already there, so none of it is new.
ledger_summary <- function(ledger) {
    if (is.null(ledger) || length(ledger$refreshes) < 2) {
        return(list(latest = NULL, prev = NULL, new_ids = character(),
                    n_new = 0L))
    }
    latest <- max(ledger$refreshes)
    prev <- max(ledger$refreshes[ledger$refreshes < latest])
    new_ids <- ledger$ids$record_id[ledger$ids$first_seen == latest]
    list(latest = latest, prev = prev, new_ids = new_ids,
         n_new = length(new_ids))
}
