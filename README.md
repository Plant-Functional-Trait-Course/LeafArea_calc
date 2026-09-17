# LeafArea_calc

Measure leaf area from scanned photos with R and [ImageJ](https://imagej.net/ij/), using the [`LeafArea`](https://github.com/richardjtelford/LeafArea) package.

This is a [GitHub template](https://github.com/Plant-Functional-Trait-Course/LeafArea_calc) for the [Plant Functional Trait Course](https://github.com/Plant-Functional-Trait-Course). Click **Use this template** to make your own copy, then clone that copy. Do not work directly in the course template.

The workflow is the same on Mac and Windows. What differs is **how ImageJ and Java are installed**. Run the setup script once on each computer, then use the same analysis script everywhere.

## Requirements

- R and RStudio
- Leaf photos in `data/` (jpeg, jpg, tif, or tiff)
- **No spaces** in file or folder names (`LeafArea` cannot handle them)

You do **not** need a separate Java or ImageJ install. The setup script downloads original ImageJ (not Fiji / ImageJ2) with Java bundled.

## Setup (once per computer)

1. Open `LeafArea_calc.Rproj` in RStudio so the working directory is this project.
2. Run `code/00_setup.R`.

That script:

- installs `tidyverse`, `plyr`, and `LeafArea` (GitHub fork with extra trim options)
- downloads the correct ImageJ build for Mac (Apple Silicon or Intel) or Windows
- unpacks it into `tools/`
- checks that ImageJ's Java actually runs

On Mac, ImageJ lives at `tools/ImageJ.app`. On Windows, it lives at `tools/ImageJ`.

## Calculate leaf area

1. Put images in `data/` (subfolders are fine).
2. Run `code/01_calculate_leaf_area.R`.
3. Check `output/leaf_area.csv` and the masks in `output/masks/`.

Each image is processed one at a time. If one scan fails, the rest still run.

`output/leaf_area.csv` has one row per scan:

- `id`: file name without extension (e.g. `DKQ6258`)
- `n_particles`: number of objects ImageJ counted as leaves
- `leaf_area`: total area in cm²

If `n_particles` is much larger than the number of leaves, ImageJ probably picked up the envelope, ruler, tape, or dirt. Inspect that scan's mask and adjust the trim settings (below).

## Image requirements

Photos should be **300 dpi**. The default scale is **237 pixels = 2 cm**, which matches 300 dpi scans used in previous trait workflows.

These photos include an envelope at the top and a ruler on the right. The script crops those away before measuring. The leaf should sit on a light background.

## Settings you may need to change

In `code/01_calculate_leaf_area.R`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `distance_pixel` / `known_distance_cm` | 237 pixels = 2 cm | Scale. Change only if scans are not 300 dpi. |
| `trim_pixel` | 58 | Crop a little from the edges. |
| `trim_pixel_right` | 150 | Crop the ruler. |
| `trim_pixel_top` | 1500 | Crop the envelope. |
| `low_size` | 0.1 | Ignore specks smaller than this (cm²). |

If the mask still includes the envelope, increase `trim_pixel_top`. If it includes the ruler, increase `trim_pixel_right`. If a small leaf is missing, lower `low_size`.

## Mac vs Windows

`code/01_calculate_leaf_area.R` is the same on both systems. Differences are only in setup:

- **Mac:** ImageJ is `ImageJ.app`. LeafArea calls `java` on the PATH, so the scripts point `JAVA_HOME` at ImageJ's bundled JRE. This avoids the macOS `/usr/bin/java` stub, which is not a real Java runtime.
- **Windows:** ImageJ is a folder containing `ij.jar` and `jre\bin\java.exe`. LeafArea uses that `java.exe` directly.

Do not install Fiji. LeafArea only supports original ImageJ.

## Folders

```text
LeafArea_calc.Rproj
code/
  00_setup.R                 # run once: packages + ImageJ
  01_calculate_leaf_area.R   # measure leaf area
  imagej_helpers.R           # shared Mac/Windows ImageJ helpers
data/                        # put leaf images here
output/
  leaf_area.csv
  leaf_area_raw.csv
  masks/                     # ImageJ outlines for checking
tools/                       # ImageJ is downloaded here (not committed)
```

## Troubleshooting

**`Unable to locate a Java Runtime`**  
Run `code/00_setup.R`, then re-run the whole of `01_calculate_leaf_area.R` from the top (not just the last few lines).

**`ImageJ not found`**  
Run setup again, or download ImageJ from https://imagej.net/ij/download.html (the build *bundled with Java*) and place `ImageJ.app` (Mac) or the `ImageJ` folder (Windows) in `tools/`.

**Area looks wrong / too many particles**  
Open the matching file in `output/masks/` and compare it to the original photo. Adjust trim or `low_size`, then re-run.

**Setup download fails**  
Download the zip yourself from https://imagej.net/ij/download.html, unzip it into `tools/`, and run `00_setup.R` again. It will reuse the local copy.
