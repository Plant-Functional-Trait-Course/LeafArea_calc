###########################
### CALCULATE LEAF AREA ###
###########################

# Measures leaf area from scan/photos with the LeafArea package (ImageJ).
# Adapted from previous PFTC / trait scanning workflows.
#
# Run code/00_setup.R once per computer first (Mac and Windows).
# Images should be 300 dpi jpeg/jpg/tif files (no spaces in names).
# A ruler and envelope in the photo are cropped using the trim settings below.

if (file.exists("code/imagej_helpers.R")) {
  source("code/imagej_helpers.R")
} else if (file.exists("imagej_helpers.R")) {
  source("imagej_helpers.R")
} else {
  stop("Cannot find code/imagej_helpers.R. Open LeafArea_calc.Rproj first.")
}
setwd(project_root())


## ---- packages ----
required_packages <- c("tidyverse", "plyr", "LeafArea")
if (!all(required_packages %in% rownames(installed.packages()))) {
  stop("Missing R packages. Run code/00_setup.R first.")
}

library(tidyverse)
library(LeafArea)

if (!"trim.pixel.right" %in% names(formals(LeafArea::run.ij))) {
  stop(
    "This project needs the GitHub fork of LeafArea (with trim.pixel.right).\n",
    "Run code/00_setup.R to install it from GitHub."
  )
}


## ---- paths ----
image_dir <- "data"
temp_dir <- "data_temp"
output_dir <- "output"
mask_dir <- file.path(output_dir, "masks")

dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(mask_dir, showWarnings = FALSE, recursive = TRUE)

# LeafArea on Windows launches ImageJ from the ImageJ folder, so relative
# paths like "data_temp" are not found. Always pass absolute paths.
image_dir <- normalizePath(image_dir, winslash = "/", mustWork = TRUE)
temp_dir <- normalizePath(temp_dir, winslash = "/", mustWork = TRUE)
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
mask_dir <- normalizePath(mask_dir, winslash = "/", mustWork = TRUE)

if (grepl(" ", project_root())) {
  warning(
    "The project path contains spaces. LeafArea/ImageJ often fails on Windows ",
    "in that case. Move the project to a path without spaces, e.g. C:/LeafArea_calc.",
    call. = FALSE
  )
}


## ---- ImageJ ----
imagej_path <- find_imagej()
if (is.na(imagej_path)) {
  stop("ImageJ was not found. Run code/00_setup.R first.")
}
enable_imagej_java(imagej_path)
message("Using ImageJ at: ", imagej_path)


## ---- analysis settings ----
# 237 pixels = 2 cm is the 300 dpi scanner/photo scale used previously.
distance_pixel <- 237
known_distance_cm <- 2

# Crop envelope, tape and ruler. Adjust if ImageJ picks up the envelope or scale bar.
trim_pixel <- 58
trim_pixel_right <- 150
trim_pixel_top <- 1500

# Ignore specks smaller than this (cm2)
low_size <- 0.1


## ---- function ----
# Process one image at a time so a failed scan does not stop the whole batch.
# Copies the file into a temp folder, runs ImageJ, then saves the mask.
loop_files <- function(files) {

  file.copy(files, temp_dir, overwrite = TRUE)

  message(files)
  enable_imagej_java(imagej_path)

  area <- try(
    run.ij(
      path.imagej = imagej_path,
      set.directory = temp_dir,
      set.memory = 2,
      distance.pixel = distance_pixel,
      known.distance = known_distance_cm,
      log = TRUE,
      low.size = low_size,
      trim.pixel = trim_pixel,
      trim.pixel.right = trim_pixel_right,
      trim.pixel.top = trim_pixel_top,
      save.image = TRUE
    ),
    silent = TRUE
  )

  # Keep ImageJ's mask so the outline can be checked later
  mask_files <- dir(temp_dir, full.names = TRUE, pattern = "\\.tif$")
  if (length(mask_files) > 0) {
    file.copy(mask_files, mask_dir, overwrite = TRUE)
  }

  # Clear the temp folder so the next image is processed on its own
  leftover <- dir(temp_dir, full.names = TRUE)
  if (length(leftover) > 0 && any(!file.remove(leftover))) {
    stop("Could not empty the temp folder: ", temp_dir)
  }

  scan_id <- tools::file_path_sans_ext(basename(files))

  # If ImageJ failed, return NA for this scan and continue the batch
  if (inherits(area, "try-error") || !is.list(area) || length(area) < 2) {
    reason <- if (inherits(area, "try-error")) {
      conditionMessage(attr(area, "condition"))
    } else {
      paste(as.character(area), collapse = " ")
    }
    warning("No leaf area for ", files, ": ", reason, call. = FALSE)
    return(tibble(dir = dirname(files), id = scan_id, leaf_area = NA_real_))
  }

  tibble(
    dir = dirname(files),
    id = names(unlist(area[[2]])),
    leaf_area = unlist(area[[2]])
  )
}


## ---- run ----
list_of_files <- dir(
  path = image_dir,
  pattern = "jpeg|jpg|tif|tiff",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(list_of_files) == 0) {
  stop("No images found in ", image_dir)
}

leaf_area_raw <- plyr::ldply(list_of_files, loop_files) |>
  as_tibble()


## ---- summarise ----
# One image can contain several leaf particles; sum them per scan.
# Mask files produced by ImageJ are dropped.
leaf_area <- leaf_area_raw |>
  filter(!is.na(dir)) |>
  filter(!grepl("mask", id, ignore.case = TRUE)) |>
  mutate(id = sub("\\..*", "", id)) |>
  group_by(dir, id) |>
  summarise(
    n_particles = sum(!is.na(leaf_area)),
    leaf_area = if (all(is.na(leaf_area))) NA_real_ else sum(leaf_area, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(leaf_area_raw, file.path(output_dir, "leaf_area_raw.csv"))
write_csv(leaf_area, file.path(output_dir, "leaf_area.csv"))

print(leaf_area)
message("Saved results to ", output_dir, " and masks to ", mask_dir)
