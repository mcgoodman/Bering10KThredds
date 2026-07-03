# Functions for downloading and processing AFSC Bering Sea data


# Eastern Bering Sea survey and oceanographic data

This package contains functions for downloading and processing:

- Estimates from the MOM6 oceangraphic model
- Estimates from the Bering 10K ROMS (/ROMS-NPZ) oceanographic model including the hindcast, historical runs, and projections
- Survey data from the NOAA AFSC Groundfish Assessment Program (GAP) Bering Sea survey and other standardized surveys in Alaska waters.
- Other spatial datasets (bathymetry, sediment grain size, and various shapefiles)

Currently, MOM6 and ROMS datasets downloaded from this package are returned as `stars` objects, which the package also contains some utilities for processing.

These functions were written at different times, for different projects, using (necessarily) different APIs, and therefore may not share a cohesive syntax.

## Installation

`BeringSeaData` can be installed from GitHub using:

``` r
# install.packages("pak")
pak::pak("mcgoodman/BeringSeaData")
```

## MOM6 oceanographic model outputs

Gridded outputs from MOM6 can be downloaded and returned as a `stars` object using `get_mom6`. Available variables for each data category and output frequency can be browsed using the data query generator on the [CEFI Portal](https://psl.noaa.gov/cefi_portal/) or using `list_mom6`. While this package was developed with an Alaska / Bering Sea focus, `get_mom6` can download outputs from both the Northeast Pacific (NEP) and Northwest Atlantic (NWA) model domains.

By default the outputs are cropped to the extent of the EBS survey region, but can be cropped to any region within the requested model’s domain by passing a different shapefile (as an `sf` object) or bounding box to the `extent` argument. E.g., to download monthly bottom temperature for the EBS region between 2020 and 2024:

``` r
# Defaults to region = "NEP" and grid_type = "regrid"
temp_mom6 <- get_mom6(
  var = "tob", 
  start_date = as.Date("2020-01-01"), 
  end_date = as.Date("2024-12-31")
)
```

The result is a 3-dimensional `stars` object with a band for each month:

``` r
# Print summary statistics for all cells
print(temp_mom6, n = prod(dim(temp_mom6)))
```

    stars object with 3 dimensions and 1 attribute
    attribute(s):
              Min.   1st Qu.   Median     Mean  3rd Qu.    Max.    NAs
    tob  -1.960721 0.1090782 2.019937 2.220932 3.832766 15.6925 321300
    dimension(s):
         from  to  offset  delta               refsys                    values x/y
    x       6 104  -17526  12418 WGS 84 / UTM zone 2N                      NULL [x]
    y       5 103 7323894 -12418 WGS 84 / UTM zone 2N                      NULL [y]
    time    1  60      NA     NA                 Date 2020-01-01,...,2024-12-01    

These ouputs can be plotted using `ggplot2::geom_stars` (example using ROMS below) or using the `stars` plotting utility:

``` r
library("stars")

temp_mom6 |> 
  plot(breaks = "equal", nbreaks = 21, col = viridis::inferno(20))
```

![](man/figures/unnamed-chunk-5-1.png)

To compute time series indices for the requested region:

``` r
# Time series of regional means
temp_mom6 |> 
  st_apply("time", mean, na.rm = TRUE) |> 
  as.data.frame() |> 
  head()
```

            time        mean
    1 2020-01-01  0.96913739
    2 2020-02-01  0.12537628
    3 2020-03-01 -0.11976230
    4 2020-04-01  0.01070486
    5 2020-05-01  0.71363816
    6 2020-06-01  1.96432718

Note:

- Many time series indices for standard survey and management zones in Alaska are pre-computed and available on the [ACE dashboard](https://apex.psmfc.org/akfin/r/akfin/ace/home).
- `get_mom6` currently only supports 2D (lat/lon) grids, not 3D (depth-specific) outputs.
- I recommend familiarizing yourself with the CEFI MOM6 products; a great resource for this is the [CEFI Cookbook](https://noaa-cefi-portal.github.io/cefi-cookbook).`get_mom6` is meant to provide a convenient syntax for querying MOM6 outputs via opendap, but the CEFI Cookbook also provides documentation for accessing these outputs using other languages and data hosting platforms.

Larger requests which may otherwise return opendap errors can be broken up on the client side using the “chunk” argument.

## Bering 10K ROMS model

This package also implements functions for browsing, downloading from, and bias-correcting outputs from the [NOAA ACLIM Thredds Server](https://data.pmel.noaa.gov/aclim/thredds/catalog/catalog.html) containing hindcasts, future projections, and historical runs of the the [Bering10K ROMS](https://beringnpz.github.io/roms-bering-sea/B10K-dataset-docs/) models for the Bering Sea. Browse available datasets and variables by visiting the Thredds Server or using `list_roms_datasets`.

### Downloading Level 2 ROMs output

The `get_roms_b10k` function can be used to download weekly gridded outputs as `stars` objects. E.g., to download SSP5-8.5 projections of bottom temperature for 2040-2060 from the GFDL earth systems model:

``` r
var <- "temp_bottom5m"

temp_ssp585 <- get_roms_b10k(
  var, start = 2040, end = 2060, 
  type = "projection", scenario = "SSP585", earth_model = "GFDL"
)
```

By default, the outputs are cropped to the shape of the Bering Sea Groundfish Assessment Program survey region, but this be disabled by specifying `crop_ebs = FALSE`. The result is a `stars` object with one band for each week:

``` r
# Print summary statistics for all cells
print(temp_ssp585, n = prod(dim(temp_ssp585)))
```

    stars object with 3 dimensions and 1 attribute
    attribute(s):
                   Min.    1st Qu.   Median     Mean  3rd Qu.     Max.      NAs
    temp [°C] -2.383263 -0.8619338 1.333167 1.434706 3.329926 14.18599 45604560
    dimension(s):
               from   to                  offset  delta
    xi_rho        1  182                      NA     NA
    eta_rho       1  258                      NA     NA
    ocean_time    1 1096 2040-01-01 12:00:00 UTC 7 days
                                     refsys                    values x/y
    xi_rho     +proj=longlat +datum=WGS8... [182x258] 156.4,...,215.1 [x]
    eta_rho    +proj=longlat +datum=WGS8...    [182x258] 45,...,69.69 [y]
    ocean_time                      POSIXct                      NULL    
    curvilinear grid

Plotting, for example, the first week in this dataset:

``` r
library("ggplot2")

ggplot() + 
  geom_stars(aes(fill = temp, color = temp), 
             data = dplyr::slice(temp_ssp585, 1, along = "ocean_time")) + 
  scale_fill_viridis_c(option = "inferno") + 
  scale_color_viridis_c(option = "inferno")
```

![](man/figures/unnamed-chunk-9-1.png)

### Delta bias-correcting ROMs projections

The package also supports “delta” bias-correcting ROMS projections, i.e., computing the difference between a hindcast and a model’s historical run for each grid cell and week-of-year as the model’s bias, and adjusting future projections to account for that bias. To do this we also need to download a hindcast and historical run for a reference time period, e.g:

``` r
# Download hindcast and historical
temp_hind <- get_roms_b10k(var, type = "hindcast", start = 2000, end = 2020)
temp_hist <- get_roms_b10k(var, type = "historical", start = 2000, end = 2020, earth_model = "GFDL")

# Delta-correct
temp_ssp585_bc <- temp_ssp585 |> delta_correct(hindcast = temp_hind, historical = temp_hist)
```

In this case, the historical model runs cool on average, so (on average) the bias-corrected projectioned temperatures are higher than the original values. However, because the bias-correction is spatially and seasonally explicit, some areas run hotter - this results in a negative bias correction for these areas, and, in this case, a handful of temperatures which are lower than is possible:

``` r
print(temp_ssp585_bc, n = prod(dim(temp_ssp585)))
```

    stars object with 3 dimensions and 1 attribute
    attribute(s):
               Min.    1st Qu.   Median     Mean  3rd Qu.     Max.      NAs
    temp  -5.673966 -0.7911012 1.684106 1.949184 4.182571 20.27514 45604560
    dimension(s):
               from   to     offset  delta                       refsys
    xi_rho        1  182         NA     NA +proj=longlat +datum=WGS8...
    eta_rho       1  258         NA     NA +proj=longlat +datum=WGS8...
    ocean_time    1 1096 2040-01-01 7 days                         Date
                                  values x/y
    xi_rho     [182x258] 156.4,...,215.1 [x]
    eta_rho       [182x258] 45,...,69.69 [y]
    ocean_time                      NULL    
    curvilinear grid

We may therefore want to set a floor:

``` r
temp_min <- as.numeric(min(temp_hind$temp, na.rm = TRUE))

temp_ssp585_bc <- temp_ssp585 |> 
  delta_correct(hindcast = temp_hind, historical = temp_hist, lower = temp_min)

print(temp_ssp585_bc, n = prod(dim(temp_ssp585)))
```

    stars object with 3 dimensions and 1 attribute
    attribute(s):
               Min.    1st Qu.   Median     Mean  3rd Qu.     Max.      NAs
    temp  -2.419214 -0.7911012 1.684106 1.958306 4.182571 20.27514 45604560
    dimension(s):
               from   to     offset  delta                       refsys
    xi_rho        1  182         NA     NA +proj=longlat +datum=WGS8...
    eta_rho       1  258         NA     NA +proj=longlat +datum=WGS8...
    ocean_time    1 1096 2040-01-01 7 days                         Date
                                  values x/y
    xi_rho     [182x258] 156.4,...,215.1 [x]
    eta_rho       [182x258] 45,...,69.69 [y]
    ocean_time                      NULL    
    curvilinear grid

### Checking for available datasets

We can list all available simulations on the Thredds server with:

``` r
list_roms_datasets(option = "sims")
```

     [1] "B10K-H16_CMIP5_CESM_BIO_rcp85"      "B10K-H16_CMIP5_CESM_rcp85"         
     [3] "B10K-H16_CMIP5_CESM_rcp45"          "B10K-H16_CMIP5_GFDL_BIO_rcp85"     
     [5] "B10K-H16_CMIP5_GFDL_rcp45"          "B10K-H16_CMIP5_GFDL_rcp85"         
     [7] "B10K-H16_CMIP5_MIROC_rcp45"         "B10K-H16_CMIP5_MIROC_rcp85"        
     [9] "B10K-H16_CORECFS"                   "B10K-K20P19_CMIP6_cesm_historical" 
    [11] "B10K-K20P19_CMIP6_cesm_ssp126"      "B10K-K20P19_CMIP6_cesm_ssp585"     
    [13] "B10K-K20P19_CMIP6_gfdl_historical"  "B10K-K20P19_CMIP6_gfdl_ssp126"     
    [15] "B10K-K20P19_CMIP6_gfdl_ssp585"      "B10K-K20P19_CMIP6_miroc_historical"
    [17] "B10K-K20P19_CMIP6_miroc_ssp126"     "B10K-K20P19_CMIP6_miroc_ssp585"    
    [19] "B10K-K20P19_CORECFS"                "B10K-K20_CORECFS"                  
    [21] "B10K-K20nobio_CORECFS_daily"       

For a given simulation, all available years and variables can be returned with, e.g.:

``` r
datasets <- list_roms_datasets(option = "all", sim = "B10K-K20P19_CMIP6_gfdl_ssp585")

# This is typically a large data frame
head(datasets[,c("sim", "years", "var")])
```

                                sim     years             var
    1 B10K-K20P19_CMIP6_gfdl_ssp585 2010-2014  Cop_integrated
    2 B10K-K20P19_CMIP6_gfdl_ssp585 2010-2014   Cop_surface5m
    3 B10K-K20P19_CMIP6_gfdl_ssp585 2010-2014 EupO_integrated
    4 B10K-K20P19_CMIP6_gfdl_ssp585 2010-2014  EupO_surface5m
    5 B10K-K20P19_CMIP6_gfdl_ssp585 2010-2014 EupS_integrated
    6 B10K-K20P19_CMIP6_gfdl_ssp585 2010-2014  EupS_surface5m

For a given variable and simulation, the range of years available can be checked with, e.g.:

``` r
check_availability(var, type = "projection", scenario = "SSP585", earth_model = "GFDL")
```

    variable temp_bottom5m available for the following time blocks:
    2010-2014
    2015-2019
    2020-2024
    2025-2029
    2030-2034
    2035-2039
    2040-2044
    2045-2049
    2050-2054
    2055-2059
    2060-2064
    2065-2069
    2070-2074
    2075-2079
    2080-2084
    2085-2089
    2090-2094
    2095-2099

## References

For description of ROMS models, see:

Hermann AJ, Gibson GA, Bond NA, Curchitser EN, Hedstrom K, Cheng W, Wang M, Cokelet ED, Stabeno PJ, Aydin K (2016). “Projected future biophysical states of the Bering Sea.” Deep-Sea Research Part II: Topical Studies in Oceanography, 134, 30–47. ISSN 09670645, doi:10.1016/j.dsr2.2015.11.001, Publisher: Elsevier, http://dx.doi.org/10.1016/j.dsr2.2015.11.001.

Kearney KA, Hermann A, Cheng W, Ortiz I, Aydin K (2020). “A coupled pelagic–benthic–sympagic biogeochemical model for the Bering Sea: documentation and validation of the BESTNPZ model (v2019.08.23) within a high-resolution regional ocean model.” Geoscientific Model Development, 13(2), 597–650. ISSN 1991-9603, doi:10.5194/gmd-13-597-2020, https://gmd.copernicus.org/articles/13/597/2020/.

Pilcher DJ, Naiman DM, Cross JN, Hermann AJ, Siedlecki SA, Gibson GA, Mathis JT (2019). “Modeled Effect of Coastal Biogeochemical Processes, Climate Variability, and Ocean Acidification on Aragonite Saturation State in the Bering Sea.” Frontiers in Marine Science, 5, 508. ISSN 2296-7745, doi:10.3389/fmars.2018.00508, https://www.frontiersin.org/article/10.3389/fmars.2018.00508/full.

## AFSC GAP survey data

The functions `get_catch`, `get_hauldata`, and `get_species_codes` are wrappers for the GAP API documented [here](https://afsc-gap-products.github.io/gap_products/content/foss-api-r.html). To download, for example, all positive tows for walleye pollock from the EBS (SEBS + NBS) survey, and add in the data for hauls with zero catch, use:

``` r
library("BeringSeaData")
plk_code <- get_species_codes("Gadus chalcogrammus")
plk_data <- get_catch(plk_code, zero_expand = TRUE, survey = "EBS")
```

## Disclaimer

This repository is a scientific product and is not official communication of the National Oceanic and Atmospheric Administration, or the United States Department of Commerce. All NOAA GitHub project code is provided on an ‘as is’ basis and the user assumes responsibility for its use. Any claims against the Department of Commerce or Department of Commerce bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring by the Department of Commerce. The Department of Commerce seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by DOC or the United States Government.
