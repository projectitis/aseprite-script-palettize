# Palettize (Aseprite script)

Allows finer control when applying a fixed palette to an image. It presents a dialog that allows you to load a palette and then preview your image with that palette applied. You can adjust the HSV of the original image to get the best match for your palette before applying it.

IMPORTANT: This script will currently not work for multiple layers or multiple frames. My use-case is only to load a single image at-a-time and then to palettize it.

## Installation

1. Open Aseprite
2. Go to `File > Scripts > Open scripts folder`
3. Copy `palettize.lua` to the scripts folder
4. In Aseprite, go to `File > Scripts > Rescan scripts folder`

## To run the script

1. In Aseprite, go to `File > Scripts > palettize`

## Basic usage

- Load an image to palettize
- Run the palettize script
- Click `Select file` to browse for a PNG palette file
- Select the color range to adjust (e.g. "Greens", "Purples" or "Global")
- Change the HSV sliders to adjust the selected range and get the best palette mapping
- Once you are ready, click `Convert to indexed mode and apply palette` to apply it to your image

## Removing unwanted color matches

To remove unwanted colors completely:

- Click a color in the palette to remove it

To stop a color in your image matching to an unwanted color you can create _exclusions_. Each exclusion will stop a color from matching a specific palette color. Exclusions have a 10% tolerance range (currently not adjustable) to also prevent similar colors from matching.

To add an exclusion:

- Click the unwanted color in the preview image on the right. It will be added as an exclusion
- Click the exclusion to remove it again

## Screenshot of the extension

![screenshot](screenshot.png)
