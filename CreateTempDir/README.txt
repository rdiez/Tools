
create-temp-dir.sh version 1.00
Copyright (c) 2023 R. Diez - Licensed under the GNU AGPLv3

Overview:

I often need a new temporary working directory to hold files related to some task at hand.
After years creating such directories manually, I felt it was time to automate it.

The directory names this script creates look like "tmp123 - 2022-12-31 - Some Task".
The '123' part is a monotonically-increasing number, and the "Some Task" suffix
describes the contents and comes from the optional argument to this script.

For convenience, the just-created directory is opened straight away
with the system's default file explorer. Set environment variable OPEN_FILE_EXPLORER_CMD
in order to use something else other than 'xdg-open'.

All these temporary directories live at a standard location, see variable DESTINATION_DIR
in the script source code. I normally keep them somewhere under $HOME, and not under
the system's '/tmp', where they may be automatically deleted by the OS. After all,
some matters take months to process, and I might want to look at the files say a year later.

Every now and then, I manually review the temporary directories and delete the ones
that are not worth keeping anymore. The recognisable directory name pattern
and the date help me quickly decide which directories are no longer relevant.

Occasionally, I trim, rename and move one of them to a more permanent location.
So far, this strategy has allowed me to strike a balance between quick availability
of recent information and long-term disk space requirements.

Syntax:
  create-temp-dir.sh <optional directory name suffix>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently 1.00)
 --license  prints license information

Usage example:
  ./create-temp-dir.sh "Today's Little Task"

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de
