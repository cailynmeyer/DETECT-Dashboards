# Tests

Occasional-use checks for the DETECT dashboards. This is not a CI suite — run these
by hand when you want to verify something, from the repo root:

```r
testthat::test_dir("tests/testthat")
```

(The repo is not an R package, so `test_dir` is the runner, not `R CMD check`.)

---

## `test-all-tab-counts.R` — do the 'All'-tab counts match REDCap?

Verifies that the counts shown on the **DETECT Tool 'All' page** are accurate to what
is actually in REDCap. It pulls the `reporting_instrument` form **live**, recomputes
each count directly from that pull, prints a side-by-side comparison, and asserts they
match the numbers the dashboard displays.

### Requirements (no fallbacks by design)

- **A live REDCap pull is required.** There is no offline/skip path — the point is the
  fresh pull. If the token is missing or the API call fails, the test **errors loudly**.
  Needs `detect_tool_redcap_api` available via `r/get_api_token.R` (env var or keyring);
  you may be prompted for your keychain password.
- **Prepped data must exist** — `data/detect_tool/detect_tool_cleaned.RDS` and
  `dashboard_prepped_data.RData` (the files the dashboard reads). If they're missing,
  run a data refresh first.
- **Run it right after a refresh** for a clean pass (see "Reading the results").

### It writes nothing

The REDCap pull stays in memory; the displayed side reads the existing (gitignored)
`data/` files. A run leaves `git status` clean — no fixtures, no cached pull, no output
files.

### What it checks (8 counts)

All mirror `sections/detect_tool_dashboard.qmd` (line refs are in the test):
survey responses, unique MRNs, clinicians, screenings started, screenings completed,
EM-status-incomplete, EM suspected, intended reports.

Scope is the **DETECT-tool (`reporting_instrument`) counts only** — not the APS-reports
"Intended Reports Made" box, and not the GO-UTHealth link-click boxes (those don't come
from REDCap).

### Reading the results

The run prints three blocks:

1. **`record_id reconciliation`** — REDCap record count vs dashboard record count, and
   how many records are in one but not the other:
   - *in REDCap but NOT dashboard* → the dashboard snapshot is **stale**; refresh to
     catch up. This is the usual reason counts differ.
   - *in dashboard but NOT REDCap* → records deleted upstream in REDCap.

2. **`clinician roster match`** — distinct clinicians in the pull, split into how many
   are on the roster (`data/clinics_physicians.csv`) vs entered as free-text (the `_oth`
   fields, not on the roster). The count uses **all** distinct clinicians (matching the
   dashboard's `ri_clinician_id_name`); the roster split is validation, not the count —
   a pure roster match would undercount because free-text clinicians are real.

3. **`'All'-tab counts` table** — `count | dashboard | redcap | match?` for all 8, so you
   see the full picture regardless of pass/fail. Then the assertion fails if any row
   mismatches.

### Interpreting a failure

A failure almost always means **stale dashboard data, not a bug.** Cross-check the
mismatches against the reconciliation: if REDCap has N more records, expect
`survey_responses`, `screenings_started`, and `screenings_completed` to each be short by
~N, with `unique_mrns` / `em_suspected` short by however many of those N are new patients
/ new EM-suspected. If every difference reconciles to the new records, the dashboard is
simply behind — **refresh and re-run, and it should read all `OK`.**

If a count **still** mismatches after a fresh refresh (i.e. beyond the record drift),
that's a genuine finding — a cleaning, recoding, or display discrepancy worth digging
into.

The assertion is deliberately **strict**: "fail" means "refresh needed, or a real
discrepancy," and the printed blocks tell you which. Keeping it strict is what makes the
staleness visible.

### Sanity-check that it can catch problems

Temporarily break one raw-side predicate (e.g. remove the UAB `password_verification`
filter line) and re-run — the table should show a mismatch and the test should fail.
Revert after.

### Notes

- The only intentional raw→clean row difference is `data_01_detect_tool.qmd:544` (drop
  UAB records with `password_verification == 0`); the test replicates it.
- Harmless warnings you can ignore: `package '...' was built under R version ...` and
  `Some records failed validation` (the latter comes from `exportRecordsTyped`, same as
  the data-prep pipeline).
- The count definitions are encoded independently of the dashboard, so if a value box's
  definition ever changes, this test will (correctly) flag it until updated to match —
  that's the guardrail.

---

## Archived

An earlier `test-data-operations.R` (APS baseline `get_data`/`save_data`) was an
unfinished stub and was moved to [`_archive/tests/`](../_archive/tests/README.md); that
note explains what to fix before reviving it.
