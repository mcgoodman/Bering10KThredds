
test_that(
  "Monthly querying works", {

    # Basic Querying works

    mom6 <- get_mom6_nep(
      "sob",
      start_date = as.Date("2020-01-01"),
      end_date = as.Date("2020-02-28")
    )

    expect_equal(dim(mom6), c(x = 99, y = 99, time = 2))

    expect_equal(sf::st_crs(mom6)$epsg, 32602)

    # Alternative argument classes work

    mom6 <- get_mom6_nep(
      "sob",
      start_date = as.Date("2020-01-01"),
      end_date = as.Date("2020-02-28"),
      target_crs = sf::st_crs(mom6),
      extent = sf::st_bbox(get_ebs_shapefile("EBS"))
    )

    expect_equal(dim(mom6), c(x = 135, y = 111, time = 2))

  }
)

test_that("Daily frequency querying works", {
  mom6_daily <- get_mom6_nep(
    "tob",
    freq = "daily",
    category = "ocean_daily",
    start_date = as.Date("2020-01-01"),
    end_date = as.Date("2020-01-03")
  )
  expect_equal(dim(mom6_daily)["time"], c(time = 3))
})

test_that(
  "Error checking works", {

    expect_error(
      get_mom6_nep("temp_bottom5m"),
      "specified variable not available"
    )

    expect_error(
      get_mom6_nep(start_date = as.Date("2040-01-01")),
      "Specified date range is invalid"
    )

  }
)

test_that("Chunked retrieval works", {
  mom6_chunked <- get_mom6_nep(
    "sob",
    start_date = as.Date("2020-01-01"),
    end_date = as.Date("2020-03-31"),
    chunk = "1 month"
  )
  expect_equal(dim(mom6_chunked), c(x = 99, y = 99, time = 3))
})

test_that("NA extent / CRS works", {

  mom6_full <- get_mom6_nep(
    "sob",
    start_date = as.Date("2020-01-01"),
    end_date = as.Date("2020-01-31"),
    extent = NA, 
    target_crs = sf::st_crs(4326)
  )
  # Ensure the spatial dims are much larger without the EBS crop
  expect_gt(dim(mom6_full)["lon"], 200)
  
  mom6 <- get_mom6_nep(
    "sob",
    start_date = as.Date("2020-01-01"),
    end_date = as.Date("2020-02-28"),
    target_crs = NA
  )
  
  expect_equal(dim(mom6), c(lon = 73, lat = 128, time = 2))
  
})
