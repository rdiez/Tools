
-------- backup.sh and backup.bat --------

These script templates help backup files under Linux and Windows respectively.

They use tools '7z' and 'par2' in order to create compressed and encrypted backup files
with extra redundant data for recovery purposes.

In order to use one of them, copy it to an empty directory and edit the directory paths
to backup and the subdirectories and file extensions to exclude.


-------- test-all-backups.sh --------

This script template lets you easily test all .par2 and .7z files found
under the specified subdirectories.


-------- update-file-mirror-by-modification-time.sh version 1.09 --------

For online backup purposes, sometimes you just want to copy all files across
to another disk at regular intervals. There is often no need for
encryption or compression. However, you normally don't want to copy
all files every time around, but only those which have changed.

Assuming that you can trust your filesystem's timestamps, this script can
get you started in little time. You can easily switch between
rdiff-backup and rsync (see this script's source code), until you are
sure which method you want.

Syntax:
  ./update-file-mirror-by-modification-time.sh src dest  # The src directory must exist.

You probably want to run this script with "background.sh", so that you get a
visual indication when the transfer is complete.

If you use the default 'rsync' method instead of the alternative 'rdiff-backup' method,
you can set environment variable PATH_TO_RSYNC to specify an alternative rsync tool to use.
This is important on Microsoft Windows, as Cygwin's rsync is known to have problems.
See script copy-with-rsync.sh for more information.


-------- update-several-mirrors.sh --------

This script template shows how to call update-file-mirror-by-modification-time.sh
several times in order to update the corresponding number of backup mirrors.

For extra comfort, you can remind and notify the user during the process.


-------- RenameWithLastModifiedDate.sh --------

Renames manually-created backup files like this:

  Prefix.txt.bak01  -> Prefix-2019-01-02-010203.txt
  Prefix.txt.bak02  -> Prefix-2019-01-03-010203.txt

The you can use Python tool 'rotate-backups' in oder to trim older backups by date.


Copyright (c) 2015-2019 R. Diez - Licensed under the GNU AGPLv3
