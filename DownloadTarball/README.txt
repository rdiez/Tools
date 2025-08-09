
DownloadTarball.sh version 1.10
Copyright (c) 2014-2022 R. Diez - Licensed under the GNU AGPLv3

This script reliably downloads a tarball by testing its integrity before
committing the downloaded file to the destination directory.

If the file is already there, the download and test operations are skipped.

The destination directory must exist beforehand. Tool 'curl' is called to
perform the actual download.

Some file mirrors use HTML redirects that 'curl' cannot follow properly, so it may
end up downloading an HTML error page instead of a valid tarball file.
In order to minimize room for such download errors, this script creates a
'download-in-progress' subdirectory in the destination directory
and downloads the file there. Afterwards, the tarball's integrity is tested.
The tarball file is only committed (moved) to the destination directory if the test succeeds.

This way, it is very hard to download a corrupt file and not immediately notice.
Even if you interrupt the transfer, the destination directory will never end up containing
corrupt tarballs (except possibly in the 'download-in-progress' subdirectory).

Should an error occur, the corrupted file is left for the user to manually inspect.
The corresponding error message shows then the corrupted file's location.

Syntax:
  DownloadTarball.sh  [options...]  <url>  <destination dir>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently 1.10)
 --license  prints license information
 --unpack-to="dest-dir"  Leaves the unpacked contents in the given directory.
                         This option is incompatible with --test-with-full-extraction .
                         Make sure tool "move-with-rsync.sh" is in your PATH.
 --test-with-full-extraction  The integrity test extracts all files to a temporary directory
                              created with 'mktemp'. Otherwise, "tar --to-stdout" is used,
                              which should be just as reliable for test purposes.
                              This option makes no difference for .zip files.
 --delete-download-dir  Delete the 'download-in-progress' subdirectory if
                        successful and empty. Do not use this option if running
                        several instances of this script in parallel.

Usage example:
  % mkdir somedir
  % ./DownloadTarball.sh "http://ftpmirror.gnu.org/gdb/gdb-7.8.tar.xz" "somedir"

Possible performance improvements still to implement:
 - Implement a shallower integrity check that just scans the filenames in the tarball
   with tar's --list option. Such a simple check should suffice in most scenarios
   and is probably faster than extracting the file contents.
 - Alternatively, if the .tar file is compressed (for example, as a .tar.gz),
   checking the compressed checksum of the whole .tar file without extracting
   all the files inside could also be a good compromise.

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

