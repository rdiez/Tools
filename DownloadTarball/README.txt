
DownloadTarball.sh version 1.12
Copyright (c) 2014-2025 R. Diez - Licensed under the GNU AGPLv3

This script reliably downloads a tarball or zip/jar file by testing its integrity
before committing the downloaded file to the destination directory.
It can also unpack the tarball to a given directory.

If the tarball is already there, the download and test operations are skipped.

Tool 'curl' is called to perform the actual download.
The destination directory must exist beforehand.

Some file mirrors use HTML redirects that 'curl' cannot follow properly, so it may
end up downloading an HTML error page instead of a valid tarball file.
In order to minimize room for such download errors, this script creates a
temporary subdirectory in the destination directory, named like
tarball.tgz-download-in-progress, and downloads the file there.
Afterwards, the tarball's integrity is tested and optionally decompressed there.
The tarball file is only committed (moved) to the destination directory if the test succeeds.

This way, it is very hard to download a corrupt file and not immediately notice.
Even if you interrupt the transfer, the destination directory will never
end up containing corrupt tarballs.

Should an error occur, the corrupted file is left for the user to manually inspect.
The corresponding error message shows then the corrupted file's location.

Option '--unpack-to-new-dir' unpacks the tarball to the given directory.
Again, this tool will only move the unpacked files there if the whole
unpack operation succeeds, so it is hard to end up with an incomplete set of unpacked files.
The given directory is meant to be for this tarball only,
and will be deleted and recreated before unpacking if it already existed.

If the tarball was already downloaded, but the directory to unpack to does not exist,
then the existing tarball is unpacked. The idea is that, if you modify the unpack directory
and then delete it, it will be recreated automatically from the previously-downloaded tarball.

Syntax:
  DownloadTarball.sh  [options...]  <url>  <destination dir>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently 1.12)
 --license  prints license information
 --unpack-to-new-dir="dest-dir"
            Unpacks the tarball into the given directory.
            If the tarball already exists, but the destination directory does not,
            then only unpacking is performed.
            The given directory will be deleted and recreated when unpacking.
            This option is incompatible with --test-with-full-extraction .
 --remove-first-level
            Many tarballs contain a single directory with a similar name as the tarball.
            For example, "gdb-7.9.tar.xz" has a single directory inside called "gdb-7.9".
            This options removes that single directory level when unpacking to the destination directory.
            Only valid if specified together with --unpack-to-new-dir.
 --test-with-full-extraction
            The integrity test extracts all files to a temporary directory,
            which is then deleted if successful. Otherwise, "tar --to-stdout >/dev/null"
            is used, which should be reliable enough for integrity test purposes.
            This option makes no difference for .zip files.
            This option is incompatible with --unpack-to-new-dir .

Usage examples:
  $ mkdir "downloaded-files"
  $ ./DownloadTarball.sh "http://ftpmirror.gnu.org/gdb/gdb-7.8.tar.xz" "downloaded-files"
  $ ./DownloadTarball.sh --unpack-to-new-dir="gdb-src" -- "http://ftpmirror.gnu.org/gdb/gdb-7.9.tar.xz" "downloaded-files"

Possible performance improvements still to implement:
 - Implement a shallower integrity check that just scans the filenames in the tarball
   with tar's --list option. Such a simple check should suffice in most scenarios
   and is probably faster than unpacking the file contents.
 - Alternatively, if the .tar file is compressed (for example, as a .tar.gz),
   checking the compressed checksum of the whole .tar file without unpacking
   all the files inside could also be a good compromise.

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiez-tools at rd10.de

