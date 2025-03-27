
copy-with-rsync.sh version 1.10
Copyright (c) 2014-2025 R. Diez - Licensed under the GNU AGPLv3

Most of the time, I just want to copy files around with "cp", but, if a long transfer
gets interrupted, next time around I want it to resume where it left off, and not restart
from the beginning.

That's where rsync comes in handy. The trouble is, I can never remember the right options
for rsync, so I wrote this little wrapper script to help.

Syntax:
  ./copy-with-rsync.sh src dest  # Copies src (file or dir) to dest (file or dir)
  ./copy-with-rsync.sh src_dir/ dest_dir  # Copies src_dir's contents to dest_dir

This script assumes that the contents of each file has not changed in the meantime.
If you interrupt this script, modify a file, and resume the copy operation, you will
end up with a mixed mess of old and new file contents.

You probably want to run this script with "background.sh", so that you get a
visual indication when the transfer is complete.

Environment variables:
- Use environment variable PATH_TO_RSYNC to specify an alternative rsync tool to use.
  This is important on Microsoft Windows, as Cygwin's rsync is known to have problems.
  See this script's source code for details.
- Use environment variable RSYNC_BWLIMIT in order to pass a value
  for rsync's option '--bwlimit', which can limit the bandwidth usage.

DETECTING DATA CORRUPTION
I have yet to copy a large amount of files without some data corruption somewhere.
I have had such trouble restarting file transfers over the network against Windows PCs using SMB/CIFS.
My old laptop had silent USB data corruption issues, and slightly unreliable hard disks
also show up from time to time. No wonder I have become paranoid over the years.
Your best bet is to calculate checksums of all files at the source, and verify them at the destination.
Checksum creation:
  rhash --recursive --crc32 --simple --percents --output="subdir-file-crcs.txt" -- "subdir/"
Checksum verification:
  rhash --check --recursive --crc32 --simple --skip-ok -- "subdir-file-crcs.txt"
Further notes:
- When creating the hashes, rhash option "--update" does not work well. I could not make it
  add new file checksums to the list in a recursive manner.
  This is allegedly fixed in rhash v1.3.9, see modified --update=filename argument.
- When verifying, do not enable the progress indication. Otherwise, it is hard to see
  which files have failed. This is unfortunate.
- Consider using GNU Parallel or "xargs --max-procs" if the CPU becomes a bottleneck
  (which is unusual for simple checksums like CRC-32).


move-with-rsync.sh version 1.09
Copyright (c) 2015-2025 R. Diez - Licensed under the GNU AGPLv3

If you try to move files and subdirectores with 'mv' overwriting any existing ones,
you may come across the infamous "directory not empty" error message.
This script uses rsync to work-around this issue.

Unfortunately, rsync does not remove the source directories. This script deletes them afterwards,
but, if a new file comes along in between, it will be deleted even though it was not moved.

Note that this 'move' script cannot resume an interrupted file transfer, unlike its 'copy' sibling.
The interrupted file will be transferred from the beginning the next time around.

Syntax:
  ./move-with-rsync.sh src dest  # Moves src (file or dir) to dest (file or dir)
  ./move-with-rsync.sh src_dir/ dest_dir  # Moves src_dir's contents to dest_dir

You probably want to run this script with "background.sh", so that you get a
visual indication when the transfer is complete.

Environment variables:
- Use environment variable PATH_TO_RSYNC to specify an alternative rsync tool to use.
  This is important on Microsoft Windows, as Cygwin's rsync is known to have problems.
  See this script's source code for details.
- Use environment variable RSYNC_BWLIMIT in order to pass a value
  for rsync's option '--bwlimit', which can limit the bandwidth usage.
