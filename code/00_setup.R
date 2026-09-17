###########################
### SETUP: R + ImageJ  ###
###########################

# Run this once per computer (Mac or Windows) before calculating leaf area.
# Open LeafArea_calc.Rproj in RStudio, then source this file.

if (file.exists("code/imagej_helpers.R")) {
  source("code/imagej_helpers.R")
} else if (file.exists("imagej_helpers.R")) {
  source("imagej_helpers.R")
} else {
  stop("Cannot find code/imagej_helpers.R. Open LeafArea_calc.Rproj first.")
}
setwd(project_root())
dir.create(tools_dir(), showWarnings = FALSE, recursive = TRUE)

# LeafArea is a pure R package (no C/Fortran). remotes::install_github() still
# asks for Rtools on Windows, even though it is not needed. Installing the
# GitHub zip with utils::install.packages() avoids that check.
leafarea_has_trim <- function() {
  if (!"LeafArea" %in% rownames(installed.packages())) {
    return(FALSE)
  }
  "trim.pixel.right" %in% names(formals(LeafArea::run.ij))
}

install_leafarea_github <- function() {
  if (leafarea_has_trim()) {
    message("LeafArea GitHub fork already installed.")
    return(invisible(TRUE))
  }

  message("Installing LeafArea from GitHub (richardjtelford/LeafArea)...")
  zip_url <- "https://github.com/richardjtelford/LeafArea/archive/refs/heads/master.zip"
  zip_file <- tempfile(fileext = ".zip")
  unpack_dir <- tempfile()
  dir.create(unpack_dir)

  utils::download.file(zip_url, zip_file, mode = "wb")
  utils::unzip(zip_file, exdir = unpack_dir)
  pkg_dir <- list.dirs(unpack_dir, recursive = FALSE, full.names = TRUE)
  pkg_dir <- pkg_dir[file.exists(file.path(pkg_dir, "DESCRIPTION"))]
  if (length(pkg_dir) != 1) {
    stop("Could not find the LeafArea package in the GitHub zip.")
  }

  utils::install.packages(pkg_dir, repos = NULL, type = "source")
  unlink(c(zip_file, unpack_dir), recursive = TRUE)

  if (!leafarea_has_trim()) {
    stop(
      "LeafArea installed, but run.ij() is missing trim.pixel.right.\n",
      "Need the GitHub fork: https://github.com/richardjtelford/LeafArea"
    )
  }
  invisible(TRUE)
}


## ---- R packages ----
message("Installing R packages if needed...")

cran_packages <- c("tidyverse", "plyr")
missing <- cran_packages[!cran_packages %in% rownames(installed.packages())]
if (length(missing) > 0) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}

install_leafarea_github()
message("R packages OK.")


## ---- ImageJ ----
# LeafArea needs original ImageJ (not Fiji / ImageJ2), bundled with Java.
# Mac and Windows use different zip files and folder layouts.

force_redownload <- FALSE
existing <- tryCatch(find_imagej(), error = function(e) NA_character_)

if (!is.na(existing) && !force_redownload) {
  message("ImageJ already found at: ", existing)
  imagej_path <- existing
} else {
  spec <- imagej_download_spec()
  zip_path <- file.path(tools_dir(), spec$zip)
  message("Downloading ImageJ for this computer...")
  message(spec$url)

  options(timeout = max(600, getOption("timeout")))
  download.file(spec$url, destfile = zip_path, mode = "wb")

  message("Unpacking ImageJ...")
  unzip(zip_path, exdir = tools_dir(), overwrite = TRUE)
  unlink(zip_path)

  if (is_macos()) {
    app <- file.path(tools_dir(), "ImageJ.app")
    if (dir.exists(app)) {
      try(system2("xattr", c("-cr", app)), silent = TRUE)
    }
  }

  imagej_path <- find_imagej()
  if (is.na(imagej_path)) {
    stop(
      "ImageJ downloaded but could not be found in tools/.\n",
      "Unzip the file from https://imagej.net/ij/download.html into tools/."
    )
  }
}

java_bin <- enable_imagej_java(imagej_path)

message("Setup complete.")
message("ImageJ: ", imagej_path)
message("Java:   ", java_bin)
message("Now run code/01_calculate_leaf_area.R")
