
DownloadAndBuildAutotools.sh version 2.02
Copyright (c) 2011-2014 R. Diez - Licensed under the GNU AGPLv3

This script downloads, builds and installs any desired versions of the GNU autotools
(autoconf + automake + libtool), which are often needed to build many open-source projects
from their source code repositories.

You would normally use whatever autotools versions your Operating System provides,
but sometimes you need older or newer versions, or even different combinations
for testing purposes.

You should NEVER run this script as root nor attempt to upgrade your system's autotools versions.
In order to use the new autotools just built by this script, temporary prepend
the full path to the "bin" subdirectory underneath the installation directory
to your $PATH variable, see option --prefix below.

Syntax:
  DownloadAndBuildAutotools.sh --autoconf-version=<nn> --automake-version=<nn>  <other options...>

Options:
 --autoconf-version=<nn>  autoconf version to download and build
 --automake-version=<nn>  automake version to download and build
 --prefix=/some/dir       directory where the binaries will be installed, see notes below
 --help     displays this help text
 --version  displays the tool's version number (currently 2.02)
 --license  prints license information

Usage example:
  % cd some/dir  # The file cache and intermediate build results will land there.
  % ./DownloadAndBuildAutotools.sh --autoconf-version=2.69 --automake-version=1.15 --libtool-version=2.4.6

About the installation directory:

If you specify with option '--prefix' the destination directory where the binaries will be installed,
and that directory already exists, its contents will be preserved. This way, you can install other tools
in the same destination directory, and they will all share the typical "bin" and "share" directory structure
underneath it that most autotools install scripts generate.

Make sure that you remove any old autotools from the destination directory before installing new versions.
Otherwise, you will end up with a mixture of old and new files, and something is going to break sooner or later.

If you do not specify the destination directory, a new one will be automatically created in the current directory.
Beware that this script will DELETE and recreate it every time it runs, in order to minimise chances
for mismatched file version. Therefore, it is best not to share it with other tools, in case you inadvertently
re-run this script and end up deleting all other tools as an unexpected side effect.

About the download cache and the intermediate build files:

This script uses 'curl' in order to download the files from ftpmirror.gnu.org ,
which should give you a fast mirror nearby.

The tarball for a given autotool version is downloaded only once to a local file cache,
so that it does not have to be downloaded again the next time around.
Do not run several instances of this script in parallel, because downloads
to the cache are not serialised or protected in any way against race conditions.

The file cache and the intermediate build files are placed in automatically-created
subdirectories of the current directory. The intermediate build files can be deleted
afterwards in order to reclaim disk space.

Interesting autotools versions:
- Ubuntu 12.04 (as of february 2014): autoconf 2.68, automake 1.11.3
- Ubuntu 13.10: autoconf 2.69, automake 1.13.3
- Latest as of february 2014: autoconf 2.69, automake 1.14.1
- Latest as of november 2015: autoconf 2.69, automake 1.15, libtool 2.4.6

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

