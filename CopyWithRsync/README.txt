
copy-with-rsync.sh version 1.02

Most of the time, I just want to copy files around with "cp", but, if a long transfer
gets interrupted, next time around I want it to resume where it left off, and not restart
from the beginning.

That's where rsync comes in handy. The trouble is, I can never remember the right options
for rsync, so I wrote this little wrapper script to help.

Syntax:
  ./copy-with-rsync.sh src dest  # Copies src (file or dir) to dest (file or dir)
  ./copy-with-rsync.sh src_dir/ dest_dir  # Copies src_dir's contents to dest_dir

This script assumes that the files have not changed in the meantime. If they have,
you will end up with a mixed mess of old and new file contents.

You probably want to run this script with "background.sh", so that you get a
visual indication when the transfer is complete.


move-with-rsync.sh version 1.02

If you try to move files and subdirectores with 'mv' overwriting any existing ones,
you may come across the infamous "directory not empty" error message.
This script uses rsync to work-around this issue.


Copyright (c) 2014-2015 R. Diez - Licensed under the GNU AGPLv3
