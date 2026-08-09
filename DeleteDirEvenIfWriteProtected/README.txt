
This script deletes the given directories with 'rm', even if the directories
or any subdirectories within are marked as read-only.

That is, this script does a "chmod a+w" beforehand
on the specified directories and all their subdirectories.
