library(duckdb)
library(fs)
library(REDCapR)

#### Functions - pulling and storing data

get_data <- function(token = keyring::key_get("aps_reports_redcap_api")) {
    redcap_read(
        redcap_uri = "https://redcap.uth.tmc.edu/api/",
        token = token,
        continue_on_error = FALSE
    )
}

save_data <- function(directory) {
    if (!dir_exists(path = directory)) {
        dir_create(path = directory)
    }

    con <- dbConnect(
        duckdb(),
        dbdir = path(directory, "APS-DATA", ext = "duckdb"),
        read_only = FALSE
    )

    tryCatch(
        {
            dbWriteTable(con, "APS-BL", data$data, overwrite = TRUE)
        },
        finally = {
            message(glue::glue(
                "Data written to disk at {directory} as DuckDB database"
            ))
        }
    )

    on.exit(dbDisconnect(con, shutdown = TRUE))
}

#### Program Logic and File Locations

DIRECTORY <- here::here("data", "aps_baseline")

data <- get_data()
save_data(directory = DIRECTORY)
