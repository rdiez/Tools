
DownloadAndBuildAutotools.sh version 2.17
Copyright (c) 2011-2024 R. Diez - Licensed under the GNU AGPLv3

This script downloads, builds and installs any desired versions of the GNU Autotools
(Autoconf + Automake + Libtool), which are often needed to build many open-source projects
from their source code repositories.

You would normally use whatever Autotools versions your Operating System provides,
but sometimes you need older or newer versions, or even different combinations
for testing purposes.

You should NEVER run this script as root nor attempt to upgrade your system's Autotools versions.
In order to use the new Autotools just built by this script, temporary prepend
the full path to the "bin" subdirectory underneath the installation directory
to your PATH variable, see option --prefix below.

Syntax:
  DownloadAndBuildAutotools.sh  [options...]

Options:
 --autoconf-version=<nn>  Autoconf version to download and build, defaults to 2.72
 --automake-version=<nn>  Automake version to download and build, defaults to 1.18.1
 --libtool-version=<nn>   Libtool  version to download and build, defaults to 2.5.3
 --prefix=/some/dir       Directory where the binaries will be installed, see notes below.
                          Defaults to: autoconf-2.72-automake-1.18.1-libtool-2.5.3
 --help     displays this help text
 --version  displays the tool's version number (currently 2.17)
 --license  prints license information

Usage example:
  % cd some/dir  # The file cache and intermediate build results will land there.
  % ./DownloadAndBuildAutotools.sh --autoconf-version=2.72 --automake-version=1.18.1 --libtool-version=2.5.3

About the installation directory:

If you specify the destination directory where the binaries will be installed using option '--prefix',
and that directory already exists, its contents will be preserved. This way, you can install other tools
in the same destination directory, and they will all share the typical "bin" and "share" directory structure
underneath it that most Autotools install scripts generate.

Make sure that you remove any old Autotools from the destination directory before installing new versions.
Otherwise, you will end up with a mixture of old and new files, and something is going to break sooner or later.

If you do not specify the destination directory, a new one will be automatically created in the current directory.
Beware that this script will DELETE and recreate it every time it runs, in order to minimise chances
for mismatched file version. Therefore, it is best not to share it with other tools, in case you inadvertently
re-run this script and end up deleting all other tools as an unexpected side effect.

About the download cache and the intermediate build files:

This script uses 'curl' in order to download the files from ftpmirror.gnu.org ,
which should give you a fast mirror nearby.

The tarballs for the given Autotool versions are downloaded only once to a local file cache
named AutotoolsDownloadCache under the current directory, so that they do not have
to be downloaded again the next time around.
Do not run several instances of this script in parallel, because downloads
to the cache are not serialised or protected in any way against race conditions.

The intermediate build files are placed in a subdirectory named AutotoolsIntermediateBuildFiles
in the current directory. The intermediate build files can be deleted
afterwards in order to reclaim disk space.

Interesting Autotools versions:
- Ubuntu 16.04: Autoconf 2.69, Automake 1.15, Libtool 2.4.6
- Latest as of August 2024: Autoconf 2.72, Automake 1.16.5, Libtool 2.4.7
- Latest as of April  2025: Autoconf 2.72, Automake 1.17  , Libtool 2.5.3
- Latest as of July   2025: Autoconf 2.72, Automake 1.18.1, Libtool 2.5.3

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de
