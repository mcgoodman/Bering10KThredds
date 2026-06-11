
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
#' @param source "dbSEABED" or "EBSSED" (see details)
#' @param type "surface" for pre-interpolated surface, or "points" for underlying data
#' @description
#' Maps of mean sediment grain size (on the Krumbein phi scale) from either the dbSEABED database
#' (Jenkins et al. 2025) or the EBSSED database (Richwine et al. 2018). 
#' @details
#' dbSEABED estimates are newer and based on data that include the NBS domain; NBS estimates from the EBSSED data are extrapolation. These are pre-processed files using inverse distance weighting for 
#' dbSEABED or ordinary Kriging for EBSSED; all original point data (filtered to non-missing phi values) from dbSEABED and EBSSED are available as point data if a different interpolation method is preferred. 
#' 
#' For further detail on dbSEABED fields, see documentation of the _grz_OtherParams_idw3d.gdb and the _xyPOINTS_FNLf_VectorData.gdb datasets from Jenkins et al. (2025).
#' @return A "stars" object (if type = "surface") or "sf" object (if type = "points")
#' @source Jenkins, C. J., McConnaughey, R. A., and Intelmann, S. S. 2025. Documentation for multi-parameter characterization of seafloor substrates in the U.S. EEZ off Alaska. U.S. Department of Commerce, NOAA Technical Memorandum NMFS-AFSC-495, 64 p.
#' @source Richwine, K. A. et al. 2018. Surficial sediments of the eastern Bering Sea continental shelf: EBSSED-2 database documentation. – US Dept Comm, NOAA Tech Mem. NMFS-AFSC-377
#' @source Smith, K. R and McConnaughey, R. A.; 1999: EBSSED database-Surficial sediments of the eastern Bering Sea continental shelf. NOAA National Centers for Environmental Information.
#' @export
get_sediment <- function(source = c("dbSEABED", "EBSSED"), type = c("surface", "points")) {

  source <- match.arg(source)
  type <- match.arg(type)

  if (type == "surface") {
    
    data <- source |> switch(
      dbSEABED = stars::read_ncdf(system.file(package = "BeringSeaData", "GIS", "dbSEABED_phi.nc"), var = "Band1"),
      EBSSED = stars::read_stars(system.file(package = "BeringSeaData", "GIS", "EBSSED_phi.grd"))
    )
    
    names(data) <- "phi"
    
  } else {

    data <- source |> switch(
      dbSEABED = sf::read_sf(system.file(package = "BeringSeaData", "GIS", "dbSEABED_phi_pts")), 
      EBSSED = sf::read_sf(system.file(package = "BeringSeaData", "GIS", "EBSSED_phi_pts"))
    )

  }
  
  data

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
