library(duckdb)
library(fs)
library(REDCapR)
library(testthat)

# Source the original script to load functions
source(here::here("data_management", "aps_baseline", "data_operations.R"))

# Test suite for get_data function
test_that("get_data function works correctly", {
    # Mock data for testing
    mock_redcap_data <- data.frame(
        # TODO: Finish setting up mock table data
    )

    # Use local_mocked_bindings to mock redcap_read
    local_mocked_bindings(
        redcap_read = function(...) {
            list(data = mock_redcap_data)
        }
    )

    # Test return type
    result <- get_data()
    expect_s3_class(result, "list")
    expect_true("data" %in% names(result))
    expect_s3_class(result$data, "data.frame")

    # Test data retrieval
    expect_equal(nrow(result$data), 5)
    expect_equal(names(result$data), c("id", "name", "age"))
})

# Test suite for save_data function
test_that("save_data function works correctly", {
    # Create a temporary directory for testing
    test_dir <- fs::path_temp("test_aps_data")

    # Ensure directory doesn't exist before test
    if (dir_exists(test_dir)) {
        dir_delete(test_dir)
    }

    # Mock data to simulate global 'data' variable
    data <- list(
        data = data.frame(
            # TODO: Finish setting up mock table data
        )
    )

    # Test directory creation
    save_data(directory = test_dir)
    expect_true(dir_exists(test_dir))

    # Test database file creation
    db_path <- path(test_dir, "APS-DATA.duckdb")
    expect_true(file_exists(db_path))

    # Test database connection and table
    con <- dbConnect(
        duckdb(),
        dbdir = db_path,
        read_only = TRUE
    )

    # Check if table exists and has correct data
    expect_true(dbExistsTable(con, "APS-BL"))
    table_data <- dbReadTable(con, "APS-BL")

    expect_equal(nrow(table_data), 5)
    expect_equal(names(table_data), c()) # TODO: Finish setting up mock table data

    # Close connection
    dbDisconnect(con, shutdown = TRUE)

    # Clean up temporary directory
    dir_delete(test_dir)
})

# Test suite for error handling
test_that("Functions handle errors gracefully", {
    # Test get_data with invalid token
    local_mocked_bindings(
        redcap_read = function(...) {
            stop("Invalid token")
        }
    )

    expect_error(
        get_data(token = "invalid_token"),
        regexp = "Invalid token"
    )

    # Test save_data with invalid directory
    expect_error(
        save_data(directory = "/path/that/does/not/exist"),
        regexp = "cannot create directory"
    )
})
