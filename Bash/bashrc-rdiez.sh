#!/bin/bash

# Copyright (c) 2018-2019 R. Diez - Licensed under the GNU AGPLv3
#
# Include this file from .bashrc like this:
#   export EMACS_BASE_PATH="$HOME/emacs-26.2-bin"  # Optional.
#   source "$HOME/some/path/bashrc-rdiez.sh"


# If not running interactively, don't do anything.

case $- in
  *i*) ;;
    *) return;;
esac


# ---- Begin ----

BASH_RC_RDIEZ_VERBOSE=false

if $BASH_RC_RDIEZ_VERBOSE; then
  echo "Running ${BASH_SOURCE[0]} ..."
fi


# ---- Functions ----

is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


if [[ $OSTYPE != "cygwin" ]]; then

  # Opens a file explorer on the given file or directory.

  explorer ()
  {
    echo "Running the explorer() Bash function..."

    if [ -z "$1" ]; then
      echo "Missing path." >&2
      return 1
    fi

    if ! is_var_set "OPEN_FILE_EXPLORER_CMD"; then
      echo "Environment variable OPEN_FILE_EXPLORER_CMD not set." >&2
      return 1
    fi

    local CMD
    printf -v CMD  "%q -- %q"  "$OPEN_FILE_EXPLORER_CMD" "$1"
    echo "$CMD"
    eval "$CMD"
  }

  export -f explorer


  apt-maintenance ()
  {
    # If you regularly use the update-and-xxx routines, you do not need to run this routine often,
    # because they perform the same steps after the upgrade.

    ( # Start a subshell for error-handling purposes.
      # On Bash 4.4 we could use the new "local -" command instead.

      set -o errexit
      set -o nounset
      set -o pipefail

      echo

      # Command "sudo purge-old-kernels --keep 6 --assume-yes" does not work anymore on Ubuntu 18.04.
      # See also this bug report:
      #   purge-old-kernels is superseded by "apt autoremove
      #   https://bugs.launchpad.net/ubuntu/+source/byobu/+bug/1686138
      #
      # Purging old kernels should be handled by apt anyway, and that since older versions including 16.04.
      # The list of kernels to keep is auto-generated into this file:
      #   /etc/apt/apt.conf.d/01autoremove-kernels
      # After the apt commands below, we now remove old configuration files and print the number of kernels kept.
      # This way, if it grows too much, the user will hopefully realise.
      if false; then
        echo "Purging old kernels..."
        sudo purge-old-kernels --keep 6 --assume-yes
        echo
      fi

      echo "Autoremoving..."

      # I am using option '--purge' because keeping configuration files for automatically installed and
      # later automatically uninstalled packages seems like a waste of space. If you don't use --purge,
      # configuration files for old kernel versions will be kept around, and that accumulates over the years.
      # For example:
      #   Purging configuration files for linux-image-4.15.0-108-generic (4.15.0-108.109) ...
      #   Purging configuration files for linux-image-4.15.0-109-generic (4.15.0-109.110) ...
      #   Purging configuration files for linux-image-4.15.0-111-generic (4.15.0-111.112) ...
      #   <...any many more...>
      # You can easily see such leftovers with Synaptic by applying filter "Not installed (residual config)".

      sudo apt-get --assume-yes  --purge  autoremove

      echo

      echo "Autocleaning..."
      sudo apt-get --assume-yes  autoclean

      echo

      if true; then

        # Ubuntu automatically removes old kernels, but keeps their configuration files for around.
        # You normally do not need these files. If you do not remove them every now and then,
        # they accumulate over the years.
        #
        # This does not apply to kernels only, but to any other package type.
        #
        # Old package configuration files are removed automatically with "autoremove --purge",
        # like the routines in this script do. But remember that the Ubuntu autoupdater may
        # remove packages automatically, or you may remove packages with some other means
        # and forget to remove their configuration files (to 'purge' them).
        #
        # Running "autoremove --purge" afterwards will not remove configuration files for packages
        # that were removed in the past.
        #
        # You can easily see orphan configuration files with Synaptic by applying filter "Not installed (residual config)".
        #
        # We remove them here, because keeping them around takes disk space and causes confusion about which old kernels
        # are actually installed or not, or about which packages are actually installed and used.
        #
        # There is of course a risk that you remove a configuration file that you modifed and wanted to keep.
        #
        # Example output:
        #   Purging configuration files for linux-image-4.15.0-108-generic (4.15.0-108.109) ...
        #   Purging configuration files for linux-image-4.15.0-109-generic (4.15.0-109.110) ...
        #   Purging configuration files for linux-image-4.15.0-111-generic (4.15.0-111.112) ...

        echo "Removing configuration files for already-uninstalled packages..."

        # Alternative command to delete orphaned package configuration files:
        #     aptitude purge ?config-files
        #   Argument "?config-files" above means "packages that were removed but not purged".

        local LIST
        set +o errexit  # grep yields a non-zero exit code if it fails to match something.
        LIST="$(dpkg --list | grep "^rc" | cut -d " " -f 3)"
        set -o errexit

        if [[ $LIST = "" ]]; then
          echo "No orphaned package configuration files to delete."
        else
          echo "Deleting orphaned package configuration files..."
          echo "$LIST" | xargs sudo dpkg --purge
        fi

        echo

        if false; then
          echo "Remaining kernels:"
          dpkg --list | grep linux-image | grep --invert-match linux-image-extra
          echo
        fi
      fi

      echo "Finished apt maintenance."
    )
  }


  update-reminder ()
  {
    # This reminder only works if you are still logged on locally at the given time,
    # see DISPLAY below.

    local -r REMINDER_TEXT="Update the system - see update-and-reboot() and update-and-shutdown()."

    local CMD
    printf -v CMD \
           "export DISPLAY=%q && DesktopNotification.sh %q" \
           "$DISPLAY" \
           "$REMINDER_TEXT"

    if false; then
      echo "$CMD"
    fi

    if false; then
      # Use 'now' to test this routine.
      local -r TIMESPEC="now"
    else
      local -r TIMESPEC="11:57"
    fi

    at "$TIMESPEC" <<<"$CMD"
  }


  append_cmd_with_echo ()
  {
    local PREFIX_FOR_ECHO="$1"
    local CMD_TO_APPEND="$2"

    local ECHO_CMD

    printf -v ECHO_CMD "echo %q" "$PREFIX_FOR_ECHO$CMD_TO_APPEND"

    # Ouput an empty line to separate this command from the previous one.
    CMD+="echo"

    CMD+=" && "

    CMD+="$ECHO_CMD"

    CMD+=" && "

    CMD+="$CMD_TO_APPEND"
  }

  update-and-reboot ()
  {
    # Actually, it would be nice to avoid rebooting if no updates at all were applied.
    # I did ask this question on Ubuntu's Launchpad:
    #
    #   Is there a way to find out whether any package has bee updated? I do not trust the system after an update, I want
    #   to reboot if some package has been updated, even if the systems thinks a reboot is not necessary.
    #
    #   https://answers.launchpad.net/ubuntu/+source/unattended-upgrades/+question/680565
    #
    # If you know of a good way to achieve this (but please no log grepping hacks), drop me a line.

    _update-and-reboot-or-shutdown "--reboot"
  }

  update-and-shutdown ()
  {
    _update-and-reboot-or-shutdown "--poweroff"
  }

  _update-and-reboot-or-shutdown ()
  {
    local OPERATION="$1"

    local CMD=""

    append_cmd_with_echo "sudo " "apt-get update"
    CMD+=" && "

    # This is useful when developing this script.
    local -r ONLY_SIMULATE_UPGRADE=false

    # - Avoiding the apt configuration file questions (when a config file has been modified on this system but the package brings an updated version):
    #   With --force-confdef, apt decides by itself when possible (in other words, when the original configuration file has not been touched).
    #   Otherwise, option --force-confold retains the old version of the file. The new version is installed with a .dpkg-dist suffix.
    #
    #   - Is there a way to see whether any such .dpkg-dist files were created? Otherwise:
    #     find /etc -type f -name '*.dpkg-*'
    #
    # - We could use the following option to save disk space:
    #   APT::Keep-Downloaded-Packages "0";

    local COMMON_OPTIONS="--quiet  -o Dpkg::Options::='--force-confdef'  -o Dpkg::Options::='--force-confold'  --assume-yes"

    if $ONLY_SIMULATE_UPGRADE; then
      COMMON_OPTIONS+="  --dry-run"
    fi

    if false; then

      # I stopped using "apt upgrade" because it does not remove packages if needed.
      # I hit this issue because I had installed a PPA to keep LibreOffice more up to date.
      # When this PPA switched between LibreOffice 6.3 to 6.4, related packages were "kept back"
      # with no useful explanation. It turned out that package "uno-libs3" had to be uninstalled.
      # I only found out with Synaptic. The  "Software Updater" application, which is /usr/bin/update-manager,
      # described as "GNOME application that manages apt updates", was also unable to upgrade the system.
      # This happend on Ubuntu MATE 18.04.4.
      # There is no extra option like "--autoremove-packages-if-needed-for-upgrading",
      # for such an automatic upgrade it is better to switch to "apt-get dist-upgrade", see below.

      # - The "--with-new-pkgs" option means:
      #       Upgrade currently-installed packages and install new packages pulled in by updated dependencies.
      #   That is what "apt upgrade" does. Command "apt-get upgrade" does not do it by default.
      #   Without this option, you will often get this warning, and some packages will not update anymore:
      #       The following packages have been kept back:
      #       (list of packages that were not updated)
      #   That happens for example if a Linux kernel update changes the ABI, because it needs to install new packages then.
      #   Option "--with-new-pkgs" maps to "APT::Get::Upgrade-Allow-New".

      append_cmd_with_echo "sudo " "apt-get upgrade  --with-new-pkgs  $COMMON_OPTIONS"

    else

      # "apt full-upgrade" is equivalent to "apt-get dist-upgrade".

      append_cmd_with_echo "sudo " "apt-get dist-upgrade  $COMMON_OPTIONS"

    fi

    CMD+=" && "

    append_cmd_with_echo "sudo " "apt-get --assume-yes  --purge  autoremove"

    CMD+=" && "

    append_cmd_with_echo "sudo " "apt-get --assume-yes  autoclean"

    if true; then

      CMD+=" && "

      CMD+="echo"  # Empty line.

      CMD+=" && "

      CMD+='{ '  # Only scoping for variables etc. Probably not strictly necessary.

      CMD+="set +o errexit"  # grep yields a non-zero exit code if it fails to match something.

      CMD+=" && "

      # shellcheck disable=SC2016
      CMD+='LIST="$(dpkg --list | grep "^rc" | cut -d " " -f 3)"'

      CMD+=" ; "  # No && because of the possible error code.

      CMD+="set -o errexit"

      CMD+=" && "

      # shellcheck disable=SC2016
      CMD+='if [[ $LIST = "" ]]; then echo "No orphaned package configuration files to delete."; else echo "Deleting orphaned package configuration files..." && echo "$LIST" | xargs dpkg --purge; fi'

      if false; then

        CMD+=" && "

        CMD+="echo"  # Empty line.

        CMD+=" && "

        CMD+='echo "Remaining kernels:"'

        CMD+=" && "

        CMD+="dpkg --list | grep linux-image | grep --invert-match linux-image-extra"

      fi

      CMD+=' ;}'

    fi


    declare -r LOG_FILENAME="$HOME/update-and-reboot.log"

    # Creating the log file here before running the command with 'sudo' has the nice side effect
    # that it will be created with the current user account. Otherwise, the file would be owned by root.
    {
      echo "Running command:"
      # Perhaps we should mention here that we will be setting flags like 'pipefail' beforehand.
      echo "$CMD"
    } >"$LOG_FILENAME"


    # I would like to get rid of log lines like these:
    #
    #   (Reading database ... ^M(Reading database ... 5%^M(Reading database ... 10%^M [...]
    #   Preparing to unpack .../00-ghostscript-x_9.26~dfsg+0-0ubuntu0.18.04.10_amd64.deb ...^M
    #   Unpacking ghostscript-x (9.26~dfsg+0-0ubuntu0.18.04.10) over (9.26~dfsg+0-0ubuntu0.18.04.9) ...^M
    #   Preparing to unpack .../01-ghostscript_9.26~dfsg+0-0ubuntu0.18.04.10_amd64.deb ...^M
    #
    # The first log line with the "Reading database" is actually much longer, I have cut it short in the excerpt above.
    # The ^M characters above are carriage return characters (CR, \r), often used in an interactive console to make
    # progress indicators overwrite the current text line.
    #
    # Unfortunately, there seems to be no apt-get option to stop using that CR trick in the progress messages.
    # Other tools are smart enough to stop doing that if the output is not a terminal, which is our case,
    # as we are piping through 'tee'.
    #
    # Adding one '--quiet' option has not much effect on my Ubuntu 18.04 system. It does seem to suppress some percentage
    # indicators in lines like "Reading package lists...", when running on a terminal, but it does not prevent the progress messages
    # with the CR character trick in lines like "Reading database" or "Preparing to unpack".
    # Adding 2 '--quiet' options is too much, for it prevents the names of the packages being updated to appear in the log file.
    #
    # I have not understood what --show-progress does yet. I seems to have no effect on the output.
    #
    # In the end, I resorted to turning those CR characters into LF with the 'sed' tool.
    # As an alternative, see my script "FilterTerminalOutputForLogFile.pl".
    #
    # The first 'sed' expression replaces all CR characters in the middle of a line with an LF character.
    # Those are all CR characters that are followed by some other character in the same line.

    local -r SED_EXPRESSION_1='s/\r\(.\)/\n\1/g'
    # The second 'sed' expression removes any remaining LF characters, which will always be at the end of a line.
    local -r SED_EXPRESSION_2='s/\r$//'

    # Turn the standard error-detection flags on, although probably only 'pipefail' is important for the command we will be executing.
    local -r ERR_DETECT_FLAGS+="set -o errexit && set -o nounset && set -o pipefail"

    printf -v CMD \
           "%s && { %s ;} 2>&1 | sed --unbuffered -e %q -e %q | tee --append %q" \
           "$ERR_DETECT_FLAGS" \
           "$CMD" \
           "$SED_EXPRESSION_1" \
           "$SED_EXPRESSION_2" \
           "$LOG_FILENAME"

    if ! $ONLY_SIMULATE_UPGRADE; then
      CMD+=" && "
      append_cmd_with_echo "sudo " "shutdown $OPERATION now"
    fi

    printf -v CMD "sudo bash -c %q" "$CMD"

    echo "$CMD"
    eval "$CMD"
  }

fi


myips ()
{
  # List all IP addresses in a shorter, more readable format than "ip addr".
  # The loopback interface and IPv6 link-local addresses are omitted.

  hostname -I | tr  ' '  '\n'
}


diskusage ()
{
  if ((  $# == 0 )); then
    echo "Call to diskusage is missing arguments." >&2
    return 1
  fi

  local QUOTED_PARAMS

  printf  -v QUOTED_PARAMS " %q"  "$@"

  local CMD

  CMD="du  --bytes  --human-readable  --summarize  --si  $QUOTED_PARAMS  |  sort  --reverse  --human-numeric-sort"

  echo "$CMD"
  eval "$CMD"
}


# ---- Miscellaneous ----

# This is so that commands df, du and ls show thousands separators in the file sizes.
export BLOCK_SIZE=\'1

if [[ $OSTYPE = "cygwin" ]]; then

  # I normally run a local X server.
  export DISPLAY=:0.0

  export PATH_TO_RSYNC="/cygdrive/f/Ruben/Softlib/Tools/Diff and Sync Tools/cwRsync_5.5.0_x86_Free/bin/rsync"

else

  export PATH="$HOME/rdiez/utils:$PATH"

fi


# Do not save the command history to a file.
unset HISTFILE


# ---- Permission check ----

if [[ $OSTYPE != "cygwin" ]]; then

  # On many systems all users have by default permission to see files under the home directories of other users,
  # or at least to traverse those home directories. I consider that a security risk. This article has more information:
  #   Private home directories for Ubuntu 21.04 onwards?
  #   https://discourse.ubuntu.com/t/private-home-directories-for-ubuntu-21-04-onwards/19533
  # Therefore, this scripts checks that is not the case, and warns otherwise.
  #
  # Beware with unexpected permission changes. For example, say you create a KVM virtual machine
  # with virt-manager, and want to use an ISO image to boot your virtual machine from
  # that is located somewhere under your home directory. virt-manager will then prompt you:
  #
  #   The emulator may not have search permissions for the path '/home/user/blah/blah'.
  #   Do you want to correct this now?
  #
  # What virt-manager is not clearly telling you is that your virtual machine will run under another user account,
  # so that "correcting" the permissions means giving access to your home directory to that other user account.
  #
  # Remember that you can use ACLs to grant a particular user permission for your home directory, see command ''setfacl''.

  OCTAL_PERMISSIONS=$(stat --printf "%a" "$HOME")
  LAST_TWO_CHARS="${OCTAL_PERMISSIONS:(-2)}"
  if [[ $LAST_TWO_CHARS != "00" ]]; then
    echo "Warning: The home directory permissions are probably not secure."
    echo "Suggested fix: chmod 0700 \"\$HOME\""
  fi

fi


# ---- Root ownership check  ----

# On Ubuntu, it is rather common to end up with the following directories owned by root:
#
#   ~/.cache/dconf
#   ~/.gvfs
#   ~/.dbus
#
# This causes problems sooner or later. In order to avoid creating these directories, use my xsudo.sh
# script when running GUI tools. There may be other ways for this problem to happen without GUI tools.
#
# This code checks every time whether root owns such directories, in order to issue an early warning.
# Do not recurse through too many directories here, or you will unduly slow down the logging process.
#
# Skip this check if we are currently running as root (for example, by running command "sudo bash").

if (( EUID != 0 )); then

  printf  -v FIND_CMD  "find  %q  %q  -mindepth 1  -maxdepth 1  ! -user %q  -print  -quit" \
          "$HOME" \
          "$HOME/.cache" \
          "$USER"

  FIRST_FILENAME_FOUND="$(eval "$FIND_CMD")"

  if [[ -n $FIRST_FILENAME_FOUND ]]; then
    echo "Warning: The following file or directory is not owned by the current user account:"
    echo "  $FIRST_FILENAME_FOUND"
  fi

fi


# ---- Emacs ----

if is_var_set "EMACS_BASE_PATH"; then

  EMACS_CLIENT="$EMACS_BASE_PATH/bin/emacsclient"

  if ! [ -x "$EMACS_CLIENT" ]; then
    echo "Warning: Environment variable EMACS_CLIENT seems wrong."
  fi

  # Some tools, like "virsh snapshot-edit", expect the editor command to wait until the user closes the file.
  # printf -v EDITOR "%q --no-wait" "$EMACS_CLIENT"
  printf -v EDITOR "%q" "$EMACS_CLIENT"
  export EDITOR

  # sudo creates a temporary file, and then overwrites the edited file. Option "--no-wait" would break this behavior.
  printf -v SUDO_EDITOR "%q" "$EMACS_CLIENT"
  export SUDO_EDITOR

  export PATH="$EMACS_BASE_PATH/bin:$PATH"

fi


# ---- Aliases ----

alias sd='StartDetached.sh'

# -F, --classify: append indicator (one of */=>@|) to entries
# --file-type: likewise, except do not append '*'
alias l="ls -la --file-type --color=auto"
alias dir=l

if [[ $OSTYPE = "cygwin" ]]; then
  alias start=cygstart  #  The cygstart command mimics the Windows native start command, for example: alias cygstart file.txt
fi


# ---- Prompt ----

# In order to test with no colours, set TERM to "dumb".

prepare_prompt ()
{
  # Run the following commands (like tput) only once, and not every time Bash needs a prompt.
  # Otherwise, you will notice a delay on Cygwin, because forking is expensive there.

  if tput setaf 1 &>/dev/null; then
    local -r MY_PROMPT_COMMAND_CAN_COLOURS=true
  else
    local -r MY_PROMPT_COMMAND_CAN_COLOURS=false
  fi

  local green=""
  local blue=""
  local red=""
  local magenta=""
  local cyan=""
  local reset=""
  local bold=""
  local pwdcol=""

  if $MY_PROMPT_COMMAND_CAN_COLOURS; then

    # If this terminal supports colours, assume it's compliant with Ecma-48 (ISO/IEC-6429).

    # "tput setaf" means "set foreground colour".

    red="$(tput setaf 1)"       # ESC[31m
    green="$(tput setaf 2)"     # ESC[32m
    # yellow="$(tput setaf 3)"  # ESC[33m
    blue="$(tput setaf 4)"      # ESC[34m
    magenta="$(tput setaf 5)"   # ESC[35m
    cyan="$(tput setaf 6)"      # ESC[36m

    reset="$(tput sgr0)"        # ESC[m  Alternatively, use ESC[0m for "normal style".
    bold="$(tput bold)"         # ESC[1m

    case "$TERM" in
      # My Emacs has a white background, and other terminals have a black background.
      # Depending on the background, I use different colours for the current directory.
      eterm-color) pwdcol="$blue";;
                *) pwdcol="$cyan";;
    esac

  fi

  declare -g -r PROMPT_SEPARATOR="  "

  local PREFIX

  #  The \[ and \] symbols allow bash to understand which parts of the prompt cause no cursor movement; without them, lines will wrap incorrectly
  PREFIX='\['

  PREFIX+="$bold$magenta\\u"
  PREFIX+="${reset}"
  PREFIX+="@"
  PREFIX+="$bold$green"
  PREFIX+="\\h"
  PREFIX+="$PROMPT_SEPARATOR"
  PREFIX+="$pwdcol\\w$reset"

  declare -g -r PROMPT_PREFIX="$PREFIX"
  declare -g -r PROMPT_ERROR_LEFT="${bold}${red}"
  declare -g -r PROMPT_ERROR_RIGHT="${reset}"
}

prepare_prompt

PROMPT_COMMAND=_my_prompt_command

_my_prompt_command ()
{
  local LAST_EXIT_CODE="$?"

  PS1="$PROMPT_PREFIX"

  if (( LAST_EXIT_CODE != 0 )); then
    PS1+="$PROMPT_SEPARATOR"
    PS1+="${PROMPT_ERROR_LEFT}[Last exit code: ${LAST_EXIT_CODE}"

    if (( LAST_EXIT_CODE > 128 )); then
      # We say "maybe" because there is no way to tell exit code 129 from exit code 128 + SIGHUP(1).
      PS1+=", maybe died from signal $(kill -l $(( LAST_EXIT_CODE - 128 )))($(( LAST_EXIT_CODE - 128 )))"
    fi

    PS1+="]${PROMPT_ERROR_RIGHT}"
  fi

  PS1+='\]'

  PS1+="\\n\\$ "

  # If this is an xterm, set the window title to "user@host dirname".
  # We need to do this on every prompt, because some program may have changed it
  # in the meantime.

  case "$TERM" in
    xterm*|rxvt*) PS1="\\[\\e]0;\\u@\\h$PROMPT_SEPARATOR\\w\\a\\]$PS1";;
               *) ;;
  esac
}


# ---- Readline ----

# Bash checks environment variable INSIDE_EMACS and parses a little of it, and also checks
# whether environment variable TERM is "dumb", in which case it disables line editing.
# Unfortunately, the decision whether to disable line editing is not made directly
# available to shell scripts.
#
# Duplicating the exact logic here is complicated, and it can change at any point in time.
# One option is just to do a simple check on TERM:  if [[ $TERM != "dumb" ]]; then ...
#
# The Bash maintainer told me of the following indirect method:
#   You can already check whether 'vi' or 'emacs' is enabled. If neither is
#   enabled, line editing is not enabled.
# This method will break if any new editing modes come, which, given the current Bash development status,
# is rather unlikely. Therefore, for the time being, this method should be OK.
#
# Without this check, if you open a shell with Emacs 'shell' command, Bash disables
# line editing, and then you will get the following warning when running the commands below:
#   bash: bind: warning: line editing not enabled

if shopt -o -q emacs || shopt -o -q vi; then

  if [ -f "$HOME/.inputrc" ]; then
    echo "Warning: $HOME/.inputrc exists, but it is probably no longer necessary."
  fi

  bind 'set completion-ignore-case on'

  # When completing, add a slash ('/') at the end of a directory name.
  bind 'set mark-directories on'

  # Cycle through ambiguous completions instead of displaying a list.
  bind 'TAB:menu-complete'

  # Shift+Tab takes you to the previous autocompletion suggestion.
  bind '"\e[Z":menu-complete-backward'

  # Whether the first tab keypress should stop at the common prefix, before cycling to the first
  # hit of the ambiguous prefix.
  bind 'set menu-complete-display-prefix off'

fi


# ---- End ----

if $BASH_RC_RDIEZ_VERBOSE; then
  echo "Finished running ${BASH_SOURCE[0]} ."
fi

unset BASH_RC_RDIEZ_VERBOSE
