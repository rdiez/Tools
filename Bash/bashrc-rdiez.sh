#!/bin/bash

# Copyright (c) 2018-2023 R. Diez - Licensed under the GNU AGPLv3
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

_is_var_set ()
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

    if ! _is_var_set "OPEN_FILE_EXPLORER_CMD"; then
      echo "Environment variable OPEN_FILE_EXPLORER_CMD not set." >&2
      return 1
    fi

    local CMD
    printf -v CMD  "%q -- %q"  "$OPEN_FILE_EXPLORER_CMD" "$1"
    echo "$CMD"
    eval "$CMD"
  }


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

    local -r REMINDER_TEXT="Update the system with update-with-apt.sh ."

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

    at -M "$TIMESPEC" <<<"$CMD"
  }

fi


myips ()
{
  # List all IP addresses in a shorter, more readable format than "ip addr".
  # The loopback interface and IPv6 link-local addresses are omitted.
  #
  # Later note: This command provides a good IP address overview per interface:
  #   ip -brief address

  # Option --field-separator="." works only for IPv4 adresses, and not for IPv6 addresses,
  # but I haven't figured out a way to overcome this limitation yet.

  hostname -I | tr  ' '  '\n' | sort --field-separator="."
}


follow-syslog ()
{
  local CMD="tail -F /var/log/syslog | LogPauseDetector.pl"

  echo "$CMD"
  echo
  eval "$CMD"
}


# ---- Miscellaneous ----

# This is so that command 'ls' shows the time like "2021-01-02 20:15" by default.
# This is equivalent to option "--time-style=long-iso".
export TIME_STYLE="long-iso"

# This is so that commands df, du and ls show thousands separators in the file sizes.
export BLOCK_SIZE=\'1

if [[ $OSTYPE = "cygwin" ]]; then

  # I normally run a local X server.
  export DISPLAY=:0.0

  # You probably want to set environment variable in ~/.bashrc . If not set,
  # set a value here, mainly as a reminder that you should do it.

  if ! _is_var_set "PATH_TO_RSYNC"; then
    export PATH_TO_RSYNC="/cygdrive/f/Ruben/SoftLib/Tools/Diff and Sync Tools/cwRsync_5.5.0_x86_Free/bin/rsync"
  fi

else

  export PATH="$HOME/rdiez/utils:$PATH"

fi


# Do not save the command history to a file.
unset HISTFILE


# ---- Home directory permissions check ----

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
    echo "Suggested fix:"
    echo "  chmod u+rwx,g-rwx,o-rwx \"\$HOME\""
    echo "Equivalent to:"
    echo "  chmod 0700 \"\$HOME\""
  fi

fi


# ---- Root ownership check inside the home directory  ----

if [[ $OSTYPE != "cygwin" ]]; then

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

fi


# ---- Emacs ----

if _is_var_set "EMACS_BASE_PATH"; then

  EMACS_CLIENT="$EMACS_BASE_PATH/bin/emacsclient"

  if ! [ -x "$EMACS_CLIENT" ]; then
    echo "Warning: Environment variable EMACS_CLIENT seems wrong."
  fi

  # Some tools, like "virsh snapshot-edit", expect the editor command to wait until the user closes the file,
  # so do not use flag '--no-wait' here.
  printf -v EDITOR "%q" "$EMACS_CLIENT"
  export EDITOR

  # Tool 'sudoedit' creates a temporary file, and after the user has finished editing it,
  # it overwrites the original file. Using option "--no-wait" here would break this method.
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

_prepare_prompt ()
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

_prepare_prompt

PROMPT_COMMAND=_my_prompt_command

_my_prompt_command ()
{
  local LAST_EXIT_CODE="$?"

  PS1="$PROMPT_PREFIX"

  if (( LAST_EXIT_CODE != 0 )); then
    PS1+="$PROMPT_SEPARATOR"
    PS1+="${PROMPT_ERROR_LEFT}[Last exit code: ${LAST_EXIT_CODE}"

    if (( LAST_EXIT_CODE > 128 )); then
      local -i SIGNAL_NUMBER=$(( LAST_EXIT_CODE - 128 ))
      local SIGNAL_NAME

      # We say "maybe" because there is no way to tell exit code 129 from exit code 128 + SIGHUP(1).
      if SIGNAL_NAME="$(kill -l $SIGNAL_NUMBER 2>/dev/null)"; then
        PS1+=", maybe died from signal $SIGNAL_NAME ($SIGNAL_NUMBER)"
      else
        PS1+=", maybe died from signal $SIGNAL_NUMBER"
      fi
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
