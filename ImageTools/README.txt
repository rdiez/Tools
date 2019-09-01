
WebPictureGenerator.sh

This is the script I use to generate pictures for a web site from high-resolution photographs.
Processing steps are cropping, scaling, watermarking, removing all EXIF information and
adding copyright information as the only EXIF data.


TransformImage.sh

This tool crops and/or resizes a JPEG image with ImageMagick or jpegtran.
It is just a wrapper for convenience.

The resulting image is optimised in order to save disk space. Any EXIF information is removed.
