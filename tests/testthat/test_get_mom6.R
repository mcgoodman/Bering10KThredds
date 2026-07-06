test_that(
  "NEP Regrid monthly querying works", {

    # Basic Querying works
    mom6 <- get_mom6(
      "sob",
      grid_type = "regrid",
      region = "NEP",
      start_date = as.Date("2020-01-01"),
      end_date = as.Date("2020-02-28")
    )

    expect_equal(dim(mom6), c(lon = 73, lat = 128, time = 2))
    expect_equal(sf::st_crs(mom6)$epsg, 4326)

    # Alternative argument classes work
    mom6 <- get_mom6(
      "sob",
      grid_type = "regrid",
      region = "NEP",
      start_date = as.Date("2020-01-01"),
      end_date = as.Date("2020-02-28"),
      extent = sf::st_bbox(get_ebs_shapefile("EBS"))
    )

    expect_equal(dim(mom6), c(lon = 89, lat = 130, time = 2))

  }
)

test_that("NEP Regrid daily frequency querying works", {
  
  mom6_daily <- get_mom6(
    "tob",
    grid_type = "regrid",
    region = "NEP",
    freq = "daily",
    category = "ocean_daily",
    start_date = as.Date("2020-01-01"),
    end_date = as.Date("2020-01-03")
  )

  expect_equal(dim(mom6_daily), c(lon = 73, lat = 128, time = 3))

})

test_that("NEP Raw querying works", {

  ebs_bbox <- sf::st_bbox(get_ebs_shapefile("EBS"))
  
  mom6_raw <- get_mom6(
    "tob",
    grid_type = "raw",
    region = "NEP",
    extent = ebs_bbox,
    start_date = as.Date("2020-01-01"),
    end_date = as.Date("2020-02-28")
  )
  
  expect_true("time" %in% names(dim(mom6_raw)))
  expect_equal(dim(mom6_raw), c(ih = 182, jh = 186, time = 2))

})

test_that("NWA Regrid monthly querying works", {

  nwa_bbox <- sf::st_bbox(c(xmin = -75, xmax = -70, ymin = 35, ymax = 40), crs = sf::st_crs(4326))

  mom6_nwa <- get_mom6(
    "tob",
    grid_type = "regrid",
    region = "NWA",
    extent = nwa_bbox,
    start_date = as.Date("2015-01-01"),
    end_date = as.Date("2015-02-28")
  )

  expect_equal(dim(mom6_nwa), c(lon = 62, lat = 80, time = 2))

})

test_that("NWA Raw monthly querying works", {

  nwa_bbox <- sf::st_bbox(c(xmin = -75, xmax = -70, ymin = 35, ymax = 40), crs = sf::st_crs(4326))

  mom6_nwa_raw <- get_mom6(
    "tob",
    grid_type = "raw",
    region = "NWA",
    extent = nwa_bbox,
    start_date = as.Date("2015-01-01"),
    end_date = as.Date("2015-02-28")
  )

  expect_equal(dim(mom6_nwa_raw), c(xh = 63, yh = 79, time = 2))

})

test_that(
  "Error checking works", {

    expect_error(
      get_mom6("temp_bottom5m", grid_type = "regrid", region = "NEP"),
      "specified variable not available"
    )

    expect_error(
      get_mom6(start_date = as.Date("2040-01-01"), grid_type = "regrid", region = "NEP"),
      "Specified date range is invalid"
    )

  }
)

test_that("Chunked retrieval works", {

  mom6_chunked <- get_mom6(
    "sob",
    grid_type = "regrid",
    region = "NEP",
    start_date = as.Date("2020-01-01"),
    end_date = as.Date("2020-03-31"),
    chunk = "1 month"
  )

  expect_equal(dim(mom6_chunked), c(lon = 73, lat = 128, time = 3))

})

test_that("NA extent works", {

  mom6_full <- get_mom6(
    "sob",
    grid_type = "regrid",
    region = "NEP",
    start_date = as.Date("2020-01-01"),
    end_date = as.Date("2020-01-31"),
    extent = NA
  )

  expect_gt(dim(mom6_full)["lon"], 200)
  
})
