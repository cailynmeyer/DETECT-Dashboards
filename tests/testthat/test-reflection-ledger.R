# =============================================================================
# test-reflection-ledger.R
# =============================================================================
# Offline unit tests for r/reflection_ledger.R, which decides how many
# reflections the DETECT Tool "All" page banner reports as new since the
# previous data refresh. Uses no data files and writes nothing.

source(here::here("r", "reflection_ledger.R"))

d <- function(x) as.Date(x)

test_that("the first run seeds the ledger and reports nothing new", {
    ledger <- update_ledger(NULL, c("1", "2", "3"), today = d("2026-09-14"))
    expect_equal(nrow(ledger$ids), 3)
    s <- ledger_summary(ledger)
    expect_null(s$prev)
    expect_equal(s$n_new, 0L)
})

test_that("ids first seen on the latest refresh are counted as new", {
    ledger <- update_ledger(NULL, c("1", "2"), today = d("2026-09-14"))
    ledger <- update_ledger(ledger, c("1", "2", "3", "4"), today = d("2026-09-28"))
    s <- ledger_summary(ledger)
    expect_equal(s$latest, d("2026-09-28"))
    expect_equal(s$prev, d("2026-09-14"))
    expect_equal(s$n_new, 2L)
    expect_setequal(s$new_ids, c("3", "4"))
})

test_that("a refresh with no new reflections reports zero", {
    ledger <- update_ledger(NULL, c("1", "2"), today = d("2026-09-14"))
    ledger <- update_ledger(ledger, c("1", "2"), today = d("2026-09-28"))
    expect_equal(ledger_summary(ledger)$n_new, 0L)
})

test_that("re-running on the same day does not reset the count", {
    ledger <- update_ledger(NULL, "1", today = d("2026-09-14"))
    ledger <- update_ledger(ledger, c("1", "2"), today = d("2026-09-28"))
    again <- update_ledger(ledger, c("1", "2"), today = d("2026-09-28"))
    expect_identical(again, ledger)
    expect_equal(ledger_summary(again)$n_new, 1L)
})

test_that("a late EMR row with an old submission date still counts as new", {
    # The ledger never looks at submission dates -- only when an id appears.
    ledger <- update_ledger(NULL, "1", today = d("2026-09-14"))
    ledger <- update_ledger(ledger, c("1", "Z123_20260301"), today = d("2026-09-28"))
    expect_equal(ledger_summary(ledger)$new_ids, "Z123_20260301")
})

test_that("ids that drop out and come back are not re-counted", {
    ledger <- update_ledger(NULL, c("1", "2"), today = d("2026-09-01"))
    ledger <- update_ledger(ledger, "1", today = d("2026-09-14"))
    ledger <- update_ledger(ledger, c("1", "2"), today = d("2026-09-28"))
    expect_equal(ledger_summary(ledger)$n_new, 0L)
})

test_that("reflection_ids keeps only Yes answers with a non-blank note", {
    cleaned <- data.frame(
        record_id = c(1, 2, 3, 4, 5),
        ri_reflection_2cat_f = factor(c("Yes", "Yes", "No", "Yes", NA)),
        ri_reflection_notes = c("note", "  ", "note", NA, "note")
    )
    expect_equal(reflection_ids(cleaned), "1")
})
