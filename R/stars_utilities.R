
#' Change multi-band, single attribute `stars` object to single-band, multi-attribute
#'
#' @param x stars object with three dimensions
#'
#' @returns A stars object
#'
#' @export
st_reband <- function(x) {

  if (!(inherits(x, "stars") & length(dim(x)) == 3)) {
    stop("`x` must be a 3-dimensional `stars` object")
  }

  if (length(names(x)) == 1) {

    x_list <- vector("list", dim(x)[3])

    band_names <- stars::st_get_dimension_values(x, 3)

    for (i in 1:(dim(x)[3])) {

      x_list[[i]] <- do.call(dplyr::slice, list(x, i, along = dimnames(x)[3]))
      names(x_list[[i]]) <- band_names[i]

    }

    return(Reduce("c", x_list))

  } else {

    x_list <- vector("list", length(names(x)))

    for (i in seq_along(names(x))) {

      x_list[[i]] <- st_reband(x[names(x)[i]])
      names(x_list[[i]]) <- paste(names(x)[i], names(x_list[[i]]), sep = ".")

    }

    return(Reduce("c", x_list))

  }

}


#' Expand a 2-dimensional `stars` object over time
#'
#' @param x 2-dimensional `stars` object
#' @param name Name of time dimension
#' @param values Values to use for time dimension
#'
#' @returns A 3-dimensional `stars` object
#' @export
st_replicate <- function(x, name, values = 1:2) {

  if (!(inherits(x, "stars") & length(dim(x)) == 2)) {
    stop("`x` must be a 2-dimensional `stars` object")
  }

  if (length(values) <= 1) {
    stop("`values` must be length 2 or more")
  }

  if (missing(name)) name <- "z"

  xi <- stats::setNames(vector("list", length(names(x))), names(x))

  for (i in seq_along(names(x))) {

    xi[[i]] <- stats::setNames(rep(list(x[i]), length(values)), values)
    xi[[i]] <- Reduce("c", xi[[i]])
    xi[[i]] <- stars::st_redimension(xi[[i]])
    xi[[i]] <- stars::st_set_dimensions(xi[[i]], which = 3, values = values, names = name)
    names(xi[[i]]) <- names(x)[i]

  }

  if (length(xi) > 1) {
    return(Reduce("c", xi))
  } else {
    return(xi[[1]])
  }

}
