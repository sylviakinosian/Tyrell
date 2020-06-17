# --- Get average humidity for countries/states --- #
#
# ISSUES:
# - currently this isn't working properly for small area countries/states
#   and we're just generating NAs for those :(
# - (above copy-pasted from humidity data, because I'm assuming the same is true for that)

source("src/packages.R")

# Get countries and states
countries <- shapefile("clean-data/gadm-countries.shp")
states <- shapefile("clean-data/gadm-states.shp")

# Load temperature data and subset into rasters for each day of the year
# - NOTE: assumes Tom's humidity script applies here too
days <- as.Date("2020-01-01") + 0:151
temp <- rgdal::readGDAL("raw-data/cds-era5-temp-midday.grib")
humid <- rgdal::readGDAL("raw-data/cds-era5-humid-midday.grib")
.drop.col <- function(i, sp.df){
    sp.df@data <- sp.df@data[,i,drop=FALSE]
    return(sp.df)
}
temp <- lapply(seq_along(days), function(i, sp.df) velox(raster::rotate(raster(.drop.col(i, sp.df)))), sp.df=temp)
humid <- lapply(seq_along(days), function(i, sp.df) velox(raster::rotate(raster(.drop.col(i, sp.df)))), sp.df=humid)

# Do work; format and save
.avg.wrapper <- function(climate, region)
    return(do.call(cbind, mcMap(
                              function(r) r$extract(region, fun = function(x) median(x, na.rm = TRUE)),
                              climate)))
.give.names <- function(output, rows, cols, rename=FALSE){
    dimnames(output) <- list(rows, cols)
    if(rename)
        rownames(output) <- gsub(" ", "_", rownames(output))
    return(output)
}

saveRDS(
    .give.names(.avg.wrapper(temp, countries), countries$NAME_0, days, TRUE),
    "clean-data/temp-midday-countries.RDS"
)
saveRDS(
    .give.names(.avg.wrapper(temp, states), states$GID_1, days)
    "clean-data/temp-midday-states.RDS"
)
saveRDS(
    .give.names(.avg.wrapper(humid, countries), countries$NAME_0, days, TRUE),
    "clean-data/humid-midday-countries.RDS"
)
saveRDS(
    .give.names(.avg.wrapper(humid, states), states$GID_1, days),
    "clean-data/humid-midday-states.RDS"
)