
copy-with-rsync.sh version 1.05

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

Use environment variable PATH_TO_RSYNC to specify an alternative rsync tool to use.
This is important on Microsoft Windows, as Cygwin's rsync is known to have problems.
See this script's source code for details.


move-with-rsync.sh version 1.05

If you try to move files and subdirectores with 'mv' overwriting any existing ones,
you may come across the infamous "directory not empty" error message.
This script uses rsync to work-around this issue.

Unfortunately, rsync does not remove the source directories. This script deletes them afterwards,
but, if a new file comes along in between, it will be deleted even though it was not moved.

Syntax:
  ./move-with-rsync.sh src dest  # Moves src (file or dir) to dest (file or dir)
  ./move-with-rsync.sh src_dir/ dest_dir  # Moves src_dir's contents to dest_dir

You probably want to run this script with "background.sh", so that you get a
visual indication when the transfer is complete.

Use environment variable PATH_TO_RSYNC to specify an alternative rsync tool to use.
This is important on Microsoft Windows, as Cygwin's rsync is known to have problems.
See this script's source code for details.


Copyright (c) 2015-2017 R. Diez - Licensed under the GNU AGPLv3
