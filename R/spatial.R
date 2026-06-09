
# Functions for reading in package-associated GIS files -------------------------------------------

#' @title EBS survey shapefiles
#' @param region Either "EBS" for full survey region including NBS, or "SEBS"
#' @param type Whether to return multipolygon corresponding to survey grid ("grid") or region boundary only ("boundary")
#' @source \href{https://github.com/afsc-gap-products/akgfmaps}{github.com/afsc-gap-products/akgfmaps}
#'
#' @return An "sf" object
#' @export
get_ebs_shapefile <- function(region = c("EBS", "SEBS"), type = c("boundary", "grid")) {

  region <- match.arg(region)
  type <- match.arg(type)

  option <- paste(region, type, sep = "_")

  option |> switch(
    EBS_grid = sf::st_read(system.file(package = "BeringSeaData", "GIS", "EBS_grid"), quiet = TRUE),
    EBS_boundary = sf::st_read(system.file(package = "BeringSeaData", "GIS", "EBS_boundary"), quiet = TRUE),
    SEBS_grid = sf::st_read(system.file(package = "BeringSeaData", "GIS", "SEBS_grid"), quiet = TRUE),
    SEBS_boundary = sf::st_read(system.file(package = "BeringSeaData", "GIS", "SEBS_boundary"), quiet = TRUE)
  )

}


#' @title Coastline shapefile for Alaska region (including parts of Russia and Canada)
#'
#' @param res resolution ("medium" or "high")
#' @return An "sf" object
#' @export
get_ak_coast <- function(res = c("medium", "high")) {

  res <- match.arg(res)

  res |> switch(
    high = sf::st_read(system.file(package = "BeringSeaData", "GIS", "Alaska_Shoreline", "ak_russia.shp")),
    medium = sf::st_read(system.file(package = "BeringSeaData", "GIS", "Alaska_Shoreline", "ak_russia_medium.shp"))
  )

}


#' @title NOAA ETOPO 15-arcsecond digitial bedrock elevation model for the EBS
#' @return A "stars" object
#' @source NOAA National Centers for Environmental Information. 2022: ETOPO 2022 15 Arc-Second Global Relief Model. NOAA National Centers for Environmental Information. \href{https://doi.org/10.25921/fd45-gt74}{doi.org/10.25921/fd45-gt74}
#' @export
get_bathymetry <- function() {

  out <- stars::read_stars(system.file(package = "BeringSeaData", "GIS", "etopo_bedrock_15arcsecond.tif"))
  names(out) <- "depth_m"
  out

}

#' @title Log sediment grain size (Krumbein phi scale) for the EBS region
#' @description Estimates from the EBSSED database interpolated / extrapolated using
#' ordinary kriging with an exponential fit to the empirical semi-variogram.
#' @return A "stars" object
#' @source Richwine, K. A. et al. 2018. Surficial sediments of the eastern Bering Sea continental shelf: EBSSED-2 database documentation. – US Dept Comm, NOAA Tech Mem. NMFS-AFSC-377
#' @export
get_sediment <- function() {

  phi <- stars::read_stars(system.file(package = "BeringSeaData", "GIS", "phi.grd"))
  phi <- phi |> stars::st_warp(crs = "+proj=longlat +datum=WGS84 +no_defs")
  names(phi) <- "phi"
  phi

}

#' @title Simple function to convert longitude from 0/360 to -180/180 and vice-versa
#' @param x A numeric vector of longitudes
#' @param from Whether to convert from -180/180 or 0/360
#'
#' @return A numeric vector
#' @export
rotate_lon <- function(x, from = c("-180/180", "0/360")) {

  from <- match.arg(from)

  from |> switch(
    `-180/180` = (x + 360) %% 360,
    `0/360` = ((x + 180) %% 360) - 180
  )

}
