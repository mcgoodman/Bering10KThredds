
#' List available CEFI MOM6 NEP datasets
#' 
#' @param var (optional) variable name; will return all variables if missing
#' @param freq (optional) frequency ("daily" or "monthly")
#' @param category (optional) CEFI data category
#' @param release (optional) CEFI release code
#' 
#' @return A `data.frame` with available datasets
#' @export
#' 
list_mom6_nep <- function(
    var = NULL,
    freq = NULL,
    category = NULL,
    release = NULL
) {
  
  # Query available datasets
  available <- jsonlite::fromJSON("https://psl.noaa.gov/cefi_portal/data_index/cefi_data_indexing.Projects.CEFI.regional_mom6.cefi_portal.northeast_pacific.full_domain.hindcast.json")
  available <- do.call("rbind", lapply(available, as.data.frame))
  
  # Filter by arguments
  if (!missing(var)) available <- available[available$cefi_variable == var,]
  if (!missing(freq)) available <- available[available$cefi_output_frequency == freq,]
  if (!missing(category)) available <- available[available$cefi_ori_category == category,]
  if (!missing(release)) available <- available[available$cefi_release == release,]
  
  return(available)
  
}

#' Retry an expression with exponential backoff
#'
#' @param expr The expression to evaluate
#' @param max_attempts Maximum number of times to try
#' @param base_sleep Base number of seconds to sleep before the first retry
#'
#' @return The result of the expression if successful
#' @noRd
with_retries <- function(expr, max_attempts = 5, base_sleep = 2) {
  attempt <- 1
  while (attempt <= max_attempts) {
    result <- tryCatch(
      expr,
      error = function(e) e
    )

    if (!inherits(result, "error")) {
      return(result)
    }

    if (attempt == max_attempts) {
      stop(sprintf("Failed after %d attempts. Final error: %s", max_attempts, result$message), call. = FALSE)
    }

    sleep_time <- base_sleep * (2 ^ (attempt - 1)) + stats::runif(1, min = 0, max = 1)
    message(sprintf("Request failed (Attempt %d/%d). Retrying in %.1f seconds...", attempt, max_attempts, sleep_time))
    Sys.sleep(sleep_time)

    attempt <- attempt + 1
  }
}

#' Download gridded estimates from the CEFI MOM6 NEP hindcast
#'
#' @param var variable name. See [CEFI portal](https://psl.noaa.gov/cefi_portal/) or use
#'   `list_mom6_nep()` for options.
#' @param freq "monthly" or "daily". Note that a matching category must also be
#'   specified, e.g. "ocean_daily" for daily frequency.
#' @param category data category. See [CEFI portal](https://psl.noaa.gov/cefi_portal/) or use
#'   `list_mom6_nep()` for options.
#' @param release release code. If NA, returns latest available release.
#' @param extent Either (1) a shapefile from which to compute the extent,
#'  (2) a bounding box created using `sf::st_bbox()` with accompanying CRS,
#'  or (3) NA for the full MOM6 NEP grid. If a shapefile is provided, it will be
#'  used to mask (crop) the output prior to returning. Defaults to NOAA AFSC
#'  Eastern Bering Sea (including NBS) survey region.
#' @param start_date Initial date to query data for. If frequency = "monthly",
#'   only years and months of provided date is used, date of month is ignored.
#'   If NA, all available dates are returned. Can be NA even if `end_date` is provided.
#' @param end_date Final date to query data for. If frequency = "monthly",
#'   only years and months of provided date is used, date of month is ignored.
#'   If NA, all available dates are returned. Can be NA even if `start_date` is provided.
#' @param target_crs CRS to transform output to (as `crs` object or integer EPSG code). 
#'   Defaults to UTM zone 2N (EPSG 32602). NA defaults to WGS84 lat/long (EPSG 4326).
#' @param chunk Time interval to chunk requests by (e.g., "10 years"); "none" for no chunking.
#'   Using no chunks may result in request hitting server data limits; using too many chunks 
#'   may result in hitting server rate limits. Accepts any string that `seq.Date` can parse.
#'
#' @return A `stars` object
#' @export
#'
get_mom6_nep <- function(
    var = "tob",
    freq = c("monthly", "daily"),
    category = paste0("ocean_", freq),
    release = NA,
    extent = get_ebs_shapefile("EBS"),
    start_date = NA,
    end_date = NA,
    target_crs = 32602, 
    chunk = "none"
) {
  
  # Query available datasets
  available <- jsonlite::fromJSON("https://psl.noaa.gov/cefi_portal/data_index/cefi_data_indexing.Projects.CEFI.regional_mom6.cefi_portal.northeast_pacific.full_domain.hindcast.json")
  available <- do.call("rbind", lapply(available, as.data.frame))
  
  # Process arguments
  freq <- match.arg(freq)
  
  # Subset available datasets to match arguments
  available <- available[
    available$cefi_output_frequency == freq & available$cefi_ori_category == category &
    available$cefi_experiment_type == "hindcast" & available$cefi_grid_type == "regrid",
  ]
  
  # Argument checking
  if (!(nrow(available) > 0)) stop(paste0("specified data category not available for freq = ", freq))
  if (!(var %in% available$cefi_variable)) stop(paste0("specified variable not available freq = ", freq, " and category = ", category))
  
  if (inherits(target_crs, "crs")) {
    target_crs <- target_crs$epsg
  } else if (is.na(target_crs)) {
    target_crs <- 4326
  } else if (!inherits(target_crs, c("integer", "numeric"))) {
    stop("`target_crs` must be of class 'crs' or an integer EPSG code")
  }
  
  # Subset to requested variable
  available <- available[available$cefi_variable == var,]
  
  # Get latest release available or specified release
  if (is.na(release)) {
    releases <- unique(available$cefi_release)
    newest_release <- releases[which.max(as.Date(gsub("r", "", releases), format = "%Y%m%d"))]
    var_info <- available[available$cefi_release == newest_release,]
    cat(paste0("Using release ", as.Date(gsub("r", "", newest_release), format = "%Y%m%d"), "\n"))
  } else {
    var_info <- available[available$cefi_release == release,]
    if (nrow(var_info) == 0) stop(paste0("release ", release, " not available"))
  }
  
  # Link to netcdf file
  if (nrow(var_info) != 1) stop("Problem with query")
  url <- var_info$cefi_opendap
  nc <- with_retries(suppressWarnings(suppressMessages(tidync::tidync(url))), max_attempts = 5)
  
  # Clip spatial extent, if necessary
  if (inherits(extent, "sf")) {
    
    extent_wgs84 <- sf::st_transform(extent, crs = 4326)
    bbox <- sf::st_bbox(extent_wgs84)
    bbox[c("xmin", "xmax")] <- rotate_lon(bbox[c("xmin", "xmax")])
    
    nc <- nc |> tidync::hyper_filter(
      lon = lon >= bbox["xmin"] & lon <= bbox["xmax"],
      lat = lat >= bbox["ymin"] & lat <= bbox["ymax"]
    )
    
  } else if (inherits(extent, "bbox")) {
    
    bbox <- sf::st_transform(extent, crs = 4326)
    bbox[c("xmin", "xmax")] <- rotate_lon(bbox[c("xmin", "xmax")])
    
    nc <- nc |> tidync::hyper_filter(
      lon = lon >= bbox["xmin"] & lon <= bbox["xmax"],
      lat = lat >= bbox["ymin"] & lat <= bbox["ymax"]
    )
    
  } else if (!is.na(extent)) {
    
    stop("extent must either be an sf object, bbox, or NA")
    
  }
  
  # Netcdf file start and end dates
  var_dates <- strsplit(var_info$cefi_date_range, split = "-")[[1]]
  dom_end <- lubridate::days_in_month(as.Date(paste0(var_dates[2], "15"), format = "%Y%m%d"))
  var_dates <- as.Date(paste0(var_dates, c("01", dom_end)), format = "%Y%m%d")
  
  # Expand to date dimension
  if (freq == "monthly") {
    var_dates <- seq(var_dates[1], var_dates[2], by = "month")
    var_dates <- lubridate::floor_date(var_dates, "month")
  } else {
    var_dates <- seq(var_dates[1], var_dates[2], by = "day")
  }

  all_dates <- var_dates
  
  # Clip temporal extent, if necessary
  if(!is.na(start_date) | !is.na(end_date)) {
    
    dates_in <- rep(TRUE, length(all_dates))
    
    if (!is.na(start_date)) {
      
      if (!inherits(start_date, "Date")) stop("`start_date` must be class 'Date'")
      if (freq == "monthly") start_date <- lubridate::floor_date(start_date, "month")
      
      dates_in <- all_dates >= start_date
      
    }
    
    if (!is.na(end_date)) {
      
      if (!inherits(end_date, "Date")) stop("`end_date` must be class 'Date'")
      if (freq == "monthly") end_date <- lubridate::floor_date(end_date, "month")
      
      dates_in <- dates_in & (all_dates <= end_date)
      
    }
    
    if (!any(dates_in)) stop(paste(
      "Specified date range is invalid. Available range is",
      all_dates[1], "-", all_dates[length(all_dates)]
    ))
    
    var_dates <- all_dates[dates_in]
    
  }
  
  # Optionally, retrieve data in chunks to avoid server data limits
  if (chunk != "none") {
    
    if (is.na(start_date)) start_date <- min(var_dates)
    if (is.na(end_date)) end_date <- max(var_dates)
    
    start_dates <- seq(start_date, end_date, by = chunk)
    end_dates <- c(start_dates[-1] - 1, end_date)

    stars_list <- vector("list", length(start_dates))
    
    for (i in seq_along(start_dates)) {
      
      chunk_dates <- var_dates[var_dates >= start_dates[i] & var_dates <= end_dates[i]]
      indices <- match(chunk_dates, all_dates)
      
      nc_chunk <- nc |> tidync::hyper_filter(time = index >= min(indices) & index <= max(indices))

      cube_chunk <- with_retries(tidync::hyper_tbl_cube(nc_chunk), max_attempts = 5)
      cube_chunk$dims$lon <- rotate_lon(cube_chunk$dims$lon, from = "0/360")
      
      # Cell corners
      if (i == 1) {
        delta <- vapply(cube_chunk$dims[1:2], \(x) diff(x)[1], numeric(1))
        offset <- vapply(cube_chunk$dims[1:2], \(x) x[1], numeric(1)) - delta / 2
      }

      stars_list[[i]] <- stars::st_as_stars(cube_chunk$mets[[1]])
      
    }
    
    # Combine chunks
    nc <- do.call(c, c(stars_list, along = 3))
    
  } else {
    
    indices <- match(var_dates, all_dates)

    nc <- nc |> tidync::hyper_filter(time = index >= min(indices) & index <= max(indices))
    nc <- with_retries(tidync::hyper_tbl_cube(nc), max_attempts = 5)
    nc$dims$lon <- rotate_lon(nc$dims$lon, from = "0/360")

    delta <- vapply(nc$dims[1:2], \(x) diff(x)[1], numeric(1))
    offset <- vapply(nc$dims[1:2], \(x) x[1], numeric(1)) - delta / 2

    nc <- stars::st_as_stars(nc$mets[[1]])
    
  }
  
  # Convert to stars
  nc <- stats::setNames(nc, var)
  nc <- stars::st_set_dimensions(nc, which = 1, offset = offset["lon"], delta = delta["lon"], names = "lon", point = FALSE)
  nc <- stars::st_set_dimensions(nc, which = 2, offset = offset["lat"], delta = delta["lat"], names = "lat", point = FALSE)
  if (length(dim(nc)) == 3) nc <- stars::st_set_dimensions(nc, which = 3, values = var_dates, names = "time")
  nc <- stars::st_set_dimensions(nc, xy = c("lon", "lat"))
  sf::st_crs(nc) <- sf::st_crs(4326)
  
  # Resample on target CRS, if applicable
  if (sf::st_crs(target_crs) != sf::st_crs(4326)) {
    nc <- stars::st_warp(nc, crs = target_crs)
  }
  
  # Crop to shapefile extent, if applicable
  if (inherits(extent, "sf")) {
    if (sf::st_crs(extent) != sf::st_crs(target_crs)) {
      extent <- sf::st_transform(extent, crs = target_crs)
    }
    nc <- nc[extent]
  }
  
  return(nc)
  
}
