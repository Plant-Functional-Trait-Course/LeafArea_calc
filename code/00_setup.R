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


## ---- R packages ----
message("Installing R packages if needed...")

cran_packages <- c("tidyverse", "plyr", "remotes")
missing <- cran_packages[!cran_packages %in% rownames(installed.packages())]
if (length(missing) > 0) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}

if (!"LeafArea" %in% rownames(installed.packages())) {
  remotes::install_github("richardjtelford/LeafArea", upgrade = "never")
}

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
