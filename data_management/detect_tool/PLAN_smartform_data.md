# PLAN — Smartform Data tab (DRAFT, not yet implemented)

Status: **planning only.** Nothing in this file is wired into the pipeline or the
dashboard. All code below is a starting point to edit until it is ready to
implement. Column names, connection details, and the scrubbing rules are
**assumptions** flagged with `# TODO` and must be confirmed before use.

## Goal

Add a **"Smartform Data"** tab beside the existing **"Textbox Data"** table on the
DETECT Tool dashboard's `All` page. It should present, in the same visual style:

- **Date of submission**
- **Provider comment** (free text)

The data comes from a **remote SQL Server database** reached with `DBI` + `odbc`,
not from REDCap. Query target: table **`vSMRTDATAv2`** in schema **`dbo`** of
database **`DETECT`** (i.e. `DETECT.dbo.vSMRTDATAv2`).

All MRNs / patient identifiers must be scrubbed from the comment text before it is
saved or displayed.

## How this parallels the existing textbox flow

| Concern | Existing textbox | Proposed smartform |
|---|---|---|
| Source | REDCap (`redcapAPI`) in `data_01_detect_tool.qmd` | SQL Server (`DBI`/`odbc`) — new pull |
| Shaping | `data_02_detect_tool.qmd:531–573` builds `text_box_table_data` | new step builds `smartform_table_data` |
| Persist | saved into `dashboard_prepped_data.RData` (`data_02:999`) | see "Where to save" — recommend a **separate RDS** |
| Display | `text_box_dt()` DT table, `detect_tool_dashboard.qmd:437–462` | new `smartform_dt()` in a `{.tabset}` beside it |
| De-identification | MRN columns simply **not selected** | **must actively redact free text** (new) |

The last row is the important difference — see [Scrubbing](#scrubbing-phi-from-free-text-new-requirement).

---

## Open questions to resolve before implementing

1. **Actual column names in `vSMRTDATAv2`.** The code below uses placeholders
   (`smrt_submit_date`, `smrt_provider_comment`). Confirm the real names, types,
   and whether the date is `DATE`/`DATETIME`/string.
2. **Connection + auth.** DSN vs. driver string? Windows trusted auth vs. SQL
   login (UID/PWD)? Where do credentials live — `.Renviron`, keyring via
   `get_api_token.R`, or a system DSN? **Does the pull require VPN / on-campus
   network?** (If so, note it in the README next to the REDCap keys.)
3. **ODBC driver availability.** Which driver name is installed on each analyst's
   machine (e.g. `"ODBC Driver 17 for SQL Server"` vs `18` vs FreeTDS on macOS)?
   This is the most common breakage point across machines.
4. **Any identifier to keep?** Should a de-identified record key be retained for
   filtering/joining, or is the tab fully anonymous (date + comment only)?
5. **Institution column?** The textbox table hides an `Institution` column used
   for filtering. Does the smartform view expose an equivalent?
6. **Is scrubbing sufficient / IRB sign-off.** Free-text PHI redaction is
   never perfectly reliable. Confirm with the PI/IRB that regex redaction +
   review is an acceptable control for displaying provider comments, or whether
   the comments should be shown at all.

---

## Step 1 — Pull the smartform data

Recommended location: a **dedicated prep document** rather than folding this into
`data_01_detect_tool.qmd`. Rationale: it uses a different connection, a different
credential, and a different network path (likely VPN). Keeping it separate means a
smartform outage can't break the REDCap refresh, and mirrors how `aps_baseline`
already isolates its own `data_operations.R`.

Suggested file: `data_management/detect_tool/data_03_smartform.qmd`
(or `.../smartform/data_operations.R` if you prefer the aps_baseline style).

```r
library(DBI)
library(odbc)
library(dplyr)
library(stringr)
library(readr)
library(here)

source(here::here("r", "get_api_token.R"))  # if using token/password auth

# --- Connection -----------------------------------------------------------
# TODO: confirm driver name, server, and auth method with the DB owner.
# Option A — Windows trusted auth (no stored password):
con <- DBI::dbConnect(
    odbc::odbc(),
    Driver             = "ODBC Driver 17 for SQL Server",   # TODO confirm
    Server             = Sys.getenv("SMARTFORM_DB_SERVER"), # e.g. via .Renviron
    Database           = "DETECT",
    Trusted_Connection = "yes",
    timeout            = 10
)

# Option B — SQL login (uncomment if not using trusted auth):
# con <- DBI::dbConnect(
#     odbc::odbc(),
#     Driver   = "ODBC Driver 17 for SQL Server",
#     Server   = Sys.getenv("SMARTFORM_DB_SERVER"),
#     Database = "DETECT",
#     UID      = Sys.getenv("SMARTFORM_DB_USER"),
#     PWD      = get_api_token("smartform_db_pwd"),  # keyring/.Renviron fallback
#     timeout  = 10
# )

# Option C — pre-configured system DSN:
# con <- DBI::dbConnect(odbc::odbc(), dsn = "DETECT_SMARTFORM")

on.exit(try(DBI::dbDisconnect(con), silent = TRUE), add = TRUE)

# --- Query ----------------------------------------------------------------
# Select only the columns we need once names are confirmed. Using Id() keeps the
# schema qualification explicit and avoids SQL-injection-y string building.
# TODO: replace column names with the real ones from vSMRTDATAv2.
smartform_raw <- DBI::dbGetQuery(
    con,
    "SELECT
         smrt_submit_date       AS submit_date,      -- TODO real column
         smrt_provider_comment  AS provider_comment  -- TODO real column
     FROM DETECT.dbo.vSMRTDATAv2;"
)
```

### Graceful fallback (mirror the GO-UTHealth pattern)

`data_01_detect_tool.qmd:78–87` returns `NULL` and reuses the last saved copy when
the GO-UTHealth API is unreachable. Do the same here so an off-VPN render still
completes with the previous smartform pull instead of erroring:

```r
smartform_raw <- tryCatch(
    {
        con <- DBI::dbConnect(odbc::odbc(), dsn = "DETECT_SMARTFORM")  # or Option A/B
        on.exit(try(DBI::dbDisconnect(con), silent = TRUE), add = TRUE)
        DBI::dbGetQuery(con, "SELECT ... FROM DETECT.dbo.vSMRTDATAv2;")
    },
    error = function(e) {
        warning("Smartform DB unreachable; reusing last saved copy. ", conditionMessage(e))
        NULL
    }
)

saved_path <- here::here("data", "detect_tool", "smartform_table_data.RDS")
smartform_fresh <- !is.null(smartform_raw)
```

---

## Step 2 — Scrub PHI from free text (NEW REQUIREMENT)

> [!IMPORTANT]
> The existing textbox table is de-identified only because MRN **columns** are
> never selected. Smartform provider comments are **free text** that may contain
> MRNs, names, phone numbers, etc. inline, so they need active redaction. Regex
> redaction is **defense-in-depth, not a guarantee** — pair it with a review step
> and PI/IRB confirmation before these comments are displayed.

```r
# Conservative redactor. Order matters (structured patterns before generic digits).
scrub_phi <- function(x) {
    x <- as.character(x)
    x |>
        # SSN-like  123-45-6789
        stringr::str_replace_all("\\b\\d{3}-\\d{2}-\\d{4}\\b", "[REDACTED-ID]") |>
        # Phone-like (various separators)
        stringr::str_replace_all("\\b\\d{3}[-.\\s]?\\d{3}[-.\\s]?\\d{4}\\b", "[REDACTED-PHONE]") |>
        # MRN / any run of 4+ digits (TODO: tune length to the real MRN format)
        stringr::str_replace_all("\\b\\d{4,}\\b", "[REDACTED-ID]")
    # NOTE: names are NOT reliably removable by regex. If provider/patient names
    # can appear, consider (a) an allow-list of provider names to strip, or
    # (b) a manual review gate before publish. Document whatever is chosen.
}
```

---

## Step 3 — Shape to a tidy table

Produce columns that parallel `text_box_table_data` as closely as the source
allows. Minimum viable = `date`, `content`.

```r
smartform_table_data <- smartform_raw |>
    dplyr::transmute(
        date    = as.Date(submit_date),          # TODO confirm date parsing
        content = scrub_phi(provider_comment)
    ) |>
    dplyr::filter(!is.na(content), content != "", !is.na(date)) |>
    dplyr::distinct() |>
    dplyr::arrange(dplyr::desc(date))
```

### Where to save

Recommend a **standalone RDS** (not the `dashboard_prepped_data.RData` bundle),
so the smartform pull stays decoupled from `data_02` and can fail independently:

```r
# Only overwrite when we actually got fresh data (see fallback above).
if (isTRUE(smartform_fresh)) {
    readr::write_rds(
        smartform_table_data,
        here::here("data", "detect_tool", "smartform_table_data.RDS")
    )
} else {
    message("Skipping overwrite of smartform_table_data.RDS (no fresh pull).")
}
```

`data/` is gitignored, so this file is never committed — same as the other
prepped data.

---

## Step 4 — Display: add the tab

In `sections/detect_tool_dashboard.qmd`:

**(a) Read the new file** in the load block (near lines 23–47):

```r
smartform_table_data <- readRDS(
    here::here("data", "detect_tool", "smartform_table_data.RDS")
)
```

**(b) Define a DT helper** near `text_box_dt()` (around line 439):

```r
smartform_dt <- function(data) {
    DT::datatable(
        data,
        colnames = c("Date", "Provider Comment"),
        filter   = list(position = "top", clear = FALSE),
        options  = list(autoWidth = TRUE)
    )
}
```

**(c) Convert the current single `## Row` textbox block into a tabset.** Today it
is (`detect_tool_dashboard.qmd:435–463`):

```markdown
## Row

​```{r, echo = FALSE}
#| title: Textbox Data
...
text_box_dt(text_box_table_data)
​```
```

Proposed:

```markdown
## Row

### Column {.tabset}

​```{r, echo = FALSE}
#| title: Textbox Data
text_box_dt(text_box_table_data)
​```

​```{r, echo = FALSE}
#| title: Smartform Data
smartform_dt(smartform_table_data)
​```
```

(`{.tabset}` is the same mechanism already used elsewhere in this dashboard, e.g.
`detect_tool_dashboard.qmd:468`.)

---

## Step 5 — Wire into the refresh + docs

- Add the pull to `r/refresh_data.R` as a new step, with its expected output
  `data/detect_tool/smartform_table_data.RDS` marked `required = FALSE` (so an
  off-VPN run degrades gracefully, like `detect_tool_link_hits.RDS`).
- Add `DBI` and `odbc` via `renv::install(c("DBI", "odbc"))` → `renv::snapshot()`.
- Document the DB connection (driver, DSN/creds, **VPN requirement**) in the main
  README API/setup section and the DETECT Tool README.
- Note the new ODBC driver system dependency in Prerequisites.

## Dependencies to add

- R packages: `DBI`, `odbc` (+ `stringr` if not already in the lockfile).
- System: an ODBC driver for SQL Server on every machine that runs the pull
  (and any future render/CI host).

## Risks / notes

- **PHI in free text** is the headline risk — see Step 2. Get sign-off.
- **ODBC driver drift** across machines is the most likely portability failure.
- **VPN/network**: if the DB is only reachable on-campus/VPN, the fallback in
  Step 1 is what keeps renders working elsewhere.
- Keep DB credentials out of the repo (`.Renviron` / keyring only), consistent
  with the existing token handling in `r/get_api_token.R`.
