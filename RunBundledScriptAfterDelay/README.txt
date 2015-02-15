
RunBundledScriptAfterDelay.sh
Copyright (c) 2015 R. Diez - Licensed under the GNU AGPLv3

This tool runs a script with the given command-line arguments after a delay (see 'sleep').
The script to run needs not be a full path, as this tool will change to the directory where
it resides before attempting to run the script. Symbolic links are correctly resolved
along the filepath used to run the tool.

Example:

  /somewhere/RunBundledScriptAfterDelay.sh  0.5s  ./test.sh a b c

That example is equivalent to:

  sleep 0.5s
  cd "/somewhere"
  ./test.sh a b c

The main usage scenario is when running a user-defined script from KDE's autostart with a delay.
If the script does not use a configuration file under the user's home directory, but expects
to find its data where it is located, this tool helps, as KDE does not properly resolve
symlinks when running an autostart entry.

KDE autostart HINT: When adding to KDE autostart, leave option "Create as symlink" ticked,
                    otherwise this script gets copied (!) to some obscure KDE folder, and then the
                    copy becomes easily stale.
