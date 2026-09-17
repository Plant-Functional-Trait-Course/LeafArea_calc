# Shared ImageJ helpers used by 00_setup.R and 01_calculate_leaf_area.R

project_root <- function() {
  if (file.exists("LeafArea_calc.Rproj")) {
    return(normalizePath("."))
  }
  if (file.exists(file.path("..", "LeafArea_calc.Rproj"))) {
    return(normalizePath(".."))
  }
  stop(
    "Working directory is not the LeafArea_calc project.\n",
    "Open LeafArea_calc.Rproj in RStudio, or setwd() to that folder."
  )
}

os_name <- function() {
  Sys.info()[["sysname"]]
}

is_macos <- function() os_name() == "Darwin"
is_windows <- function() os_name() == "Windows"

tools_dir <- function() file.path(project_root(), "tools")

# LeafArea looks for different ImageJ layouts on Mac vs Windows.
is_valid_imagej <- function(path) {
  if (is.na(path) || !dir.exists(path)) {
    return(FALSE)
  }
  mac_jar <- file.path(path, "Contents", "Java", "ij.jar")
  win_jar <- file.path(path, "ij.jar")
  file.exists(mac_jar) || file.exists(win_jar)
}

imagej_java_bin <- function(imagej_path) {
  java_name <- if (is_windows()) "java.exe" else "java"
  file.path(imagej_path, "jre", "bin", java_name)
}

find_imagej <- function() {
  candidates <- c(
    file.path(tools_dir(), "ImageJ.app"),
    file.path(tools_dir(), "ImageJ")
  )
  if (is_macos()) {
    candidates <- c(candidates, "/Applications/ImageJ.app")
  }
  if (is_windows()) {
    candidates <- c(
      candidates,
      "C:/Program Files/ImageJ",
      "C:/Program Files (x86)/ImageJ"
    )
  }

  hit <- candidates[vapply(candidates, is_valid_imagej, logical(1))]
  if (length(hit) == 0) {
    return(NA_character_)
  }
  normalizePath(hit[[1]], winslash = "/", mustWork = TRUE)
}

# macOS has a /usr/bin/java stub that is not a real JDK. Point JAVA_HOME at
# ImageJ's bundled JRE so LeafArea's system("java ...") call works.
enable_imagej_java <- function(imagej_path) {
  java_bin <- imagej_java_bin(imagej_path)
  if (!file.exists(java_bin)) {
    stop("ImageJ Java was not found at ", java_bin)
  }

  java_home <- dirname(dirname(java_bin))
  java_dir <- dirname(java_bin)
  path_sep <- .Platform$path.sep

  Sys.setenv(JAVA_HOME = java_home)
  Sys.setenv(PATH = paste(java_dir, Sys.getenv("PATH"), sep = path_sep))

  java_ok <- tryCatch({
    out <- system2(java_bin, "-version", stdout = TRUE, stderr = TRUE)
    any(grepl("version", out, ignore.case = TRUE))
  }, error = function(e) FALSE)

  if (!isTRUE(java_ok)) {
    stop("Could not start ImageJ's Java. Tried: ", java_bin)
  }

  invisible(java_bin)
}

imagej_download_spec <- function() {
  machine <- Sys.info()[["machine"]]
  if (is_macos() && grepl("arm64|aarch64", machine, ignore.case = TRUE)) {
    return(list(
      url = "https://wsr.imagej.net/distros/osx/ij154-osx-arm-java13.zip",
      zip = "ij154-osx-arm-java13.zip"
    ))
  }
  if (is_macos()) {
    return(list(
      url = "https://wsr.imagej.net/distros/osx/ij154-osx-java8.zip",
      zip = "ij154-osx-java8.zip"
    ))
  }
  if (is_windows()) {
    return(list(
      url = "https://wsr.imagej.net/distros/win/ij154-win-java8.zip",
      zip = "ij154-win-java8.zip"
    ))
  }
  list(
    url = "https://wsr.imagej.net/distros/linux/ij154-linux64-java8.zip",
    zip = "ij154-linux64-java8.zip"
  )
}
