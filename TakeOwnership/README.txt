
takeownership.sh version 1.00
Copyright (c) 2015 R. Diez - Licensed under the GNU AGPLv3

This script is a convenient shortcut for the following commands:

1) If a filename is a regular file:
     sudo chown "$SUDO_USER"  "filename" ...
     sudo chgrp "$SUDO_GROUP" "filename" ...

  But note that the syntax above does not actually work, as we need to take $SUDO_USER
  after 'sudo' has run (and not before), and $SUDO_GROUP does not actually exist.
  This script does it properly though.

2) If a filename is a directory:
  Same commands with option "--recursive".

Note that "takeownership.sh dir" has the same effect as "takeownership.sh dir/". That is,
appending a '/' to a directory name has no effect.
