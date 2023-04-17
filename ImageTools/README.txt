
1) WebPictureGenerator.sh

   This is the script I use to generate pictures for a web site from high-resolution photographs.
   Processing steps are cropping, scaling, watermarking, removing all EXIF information and
   adding copyright information as the only EXIF data.


2) TransformImage.sh version 1.10

   This tool crops and/or resizes a JPEG image with ImageMagick or jpegtran.
   It is just a wrapper for convenience.

   The resulting image is optimised in order to save disk space.
   Any EXIF information, preview and thumbnail images are removed.

   Rotated images (according to the EXIF 'Orientation' field)
   are automatically 'unrotated'.

   I use this tool to prepare images for embedding in a document.

   Syntax:
     TransformImage.sh <options...> <--> image.jpg

   The resulting filename is image-transformed.jpg .

   Options:
    --crop <expr>  Crops the picture according to an expression like "10L,11R,12T,13B",
                   see below for details.
    --xres     Scales the image to the target horizontal resolution.
               The aspect ratio is maintaned.
    --help     Displays this help text.
    --version  Displays the tool's version number (currently 1.09) .
    --license  Prints license information.
    --         Terminate options processing. Useful to avoid confusion between options and filenames
               that begin with a hyphen ('-'). Recommended when calling this script from another script,
               where the filename comes from a variable or from user input.

   Crop expressions:

   - Type 1 like "10L,11R,12T,13B":
     L, R, T and B mean respectively left, right, top and bottom.
     The values are the number of pixels to remove from each side.

   - Type 2 like "10X,11Y,12W,13H":
     X and Y specify the coordinates (horizontal and vertical) and W and H the size
     (width and height) of the picture area to extract.

   - Type 3 like "10X,11Y,12X,13Y":
     The first X and Y specify the top-left coordinates and the second X and Y
     the bottom-right coordinates of the picture area to extract.

   Usage example:
     ./TransformImage.sh  --crop "500L,500R,500T,500B"  --xres 640  --  image.jpg

   If you only specify the '--crop' operation, it will be performed in a lossless fashion,
   so the cropping coordinates will no be entirely accurate. Search for "iMCU boundary"
   in the jpegtran documentation for details.

   Exit status: 0 means success. Any other value means error.

   Feedback: Please send feedback to rdiezmail-tools at yahoo.de
