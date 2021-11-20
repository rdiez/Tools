
CheckIfAnyFilesModifiedRecently.sh version 1.03
Copyright (c) 2018 R. Diez - Licensed under the GNU AGPLv3

This tool helps implement an early warning if a directory has not been updated recently as it should.

Say you have automated some back up operation. You have verified that it works.
You have tested restoring the backup once. You may even retest every month or every year.
If the backup fails, you get an automatic e-mail. Everything is covered for. Or is it?

What if the backup fails, and the automatic e-mail fails too?
You will certainly find out at the next manual check. But that means you did not create any backups for a month.

You cannot manually check everything every day. But you cannot really rely on automatic notifications either.
You could send an automatic e-mail notification every day, so that you notice if they stop coming.
But then you have to centralise all checks, or you will get an e-mail per host computer, which can be too many.
And such automatic system may be hard to maintain.
Besides, doing a full backup restore test every day for all backups can be an unjustifiable system load.

A good compromise can be to check daily if at least some files are still being updated at regular intervals
at the backup destination directories. And this is what this script helps automate.
The goal is to implement a cross-check system that provides early warnings for most failures at very low cost.

Some common files are automatically ignored:
- Any filenames starting with a dot (Unix hidden files, like .Trash-1000 or .directory)
- Thumbs.db (Windows thumbnail cache files)

Syntax:
  CheckIfAnyFilesModifiedRecently.sh <options...> <--> <directory name>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently 1.03)
 --license  prints license information
 --since-minutes=xx   at least one file must have changed in the last xx minutes

Usage example:
  ./CheckIfAnyFilesModifiedRecently.sh --since-minutes=$(( 7 * 24 * 60 )) -- "MyBackupDir"

See SanityCheckRotatingBackup.sh for an example on how to run this script for several directories.
That example code also shows how to check that the number of files and subdirectories
inside some directories is within the given limits.

Exit status: 0 means success, any other value means failure.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

