
RecompressSelectively.sh version 1.02

Selectively recompress archive files (like zip files) across subdirectories.

Rationale:
  Say you have a bunch of archive files (like zip files) spread over many subdirectories,
  and you want to recompress them all.

  You would like to use another compression tool, like "advzip --shrink-insane",
  which uses the zopfli algorithm to very slowly compress as much as possible.
  Warning: advzip version 2.1-2.1build1 that comes with Ubuntu MATE 20.04
           does not support international characters in filenames.

  But you want to skip some archives based on some filename criteria. In fact, it would
  be nice use the full power of the 'find' tool.

  And you also want to skip some archives based on their contents. For example, only process
  those archives with a particular filename inside.

  You also want to swap out some shared files in all recompressed archives, because those
  common files have been updated in the meantime.

  At this point, you need so much flexibility, that you realise you will need to write
  a custom script for this purpose. But there are more features to consider.

  Any temporary files should always land on the same subdirectory. This way, if something
  fails, you can inspect them manually.

  Should you run two instances of the script at the same time by mistake, the second instance
  should of course realise and stop, so as not to disturb the first one.

  The first time around, you want to test the recompression results locally, and not modify
  the original archives, in case you have made a mistake somewhere.

  Writing such a script from scratch is time consuming, especially if you want it to be robust.
  That is why I have written a complete, robust example Bash script with all the features
  described above. Every time I need such flexibility in a batch file operation, I can save
  a lot of time by copying and modifying this example script.

Syntax:
  RecompressSelectively.sh [options...] <start directory>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently 1.02)
 --license  prints license information
 --find-only  Run only the 'find' command and list any files found.
 --output-dir <dir>  Instead of replacing the original archives,
                     place the recompressed ones somewhere else.
                     If the output directory already exists, it will not be emptied beforehand.

How to test this script:
  ./CreateTestFiles.sh  "TestData"
  ./RecompressSelectively.sh --output-dir="TestData/Output"  "TestData/FilesToProcess"

Caveats:
- File permissions are not respected. The recompressed archives will have default permissions,
  unless you modify this script yourself.
- This script should use a temporary filesystem like /tmp, for performance reasons,
  but that is not implemented yet. The main issue is making sure that any temporary files
  are deleted if the script gets killed. There is not really a reliable way to achieve that.

Exit status: 0 means success, anything else is an error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

Copyright (c) 2020 R. Diez - Licensed under the GNU AGPLv3
