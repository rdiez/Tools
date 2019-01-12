#!/bin/bash

# Copyright (c) 2018 R. Diez - Licensed under the GNU AGPLv3
#
# Include this file from .bashrc like this:
#   source "$HOME/bashrc-rdiez.sh"


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

if [[ $OSTYPE != "cygwin" ]]; then

  explorer ()
  {
    echo "Running the explorer() bash function..."

    if [ -z "$1" ]; then
      echo "Missing path."
      return 1
    fi

    # StartDetached.sh  nautilus --no-desktop --browser "$1"
    # StartDetached.sh  dolphin "$1"
    StartDetached.sh  thunar "$1"
  }

  export -f explorer


  apt-maintenance ()
  {
    ( # Start a subshell for error-handling purposes.
      # On Bash 4.4 we could use the new "local -" command instead.

      set -o errexit
      set -o nounset
      set -o pipefail

      echo

      # Command "sudo purge-old-kernels --keep 6 --assume-yes" does not work anymore on Ubuntu 18.04.
      # Purging old kernels should be handled by apt anyway, and that since older versions including 16.04.
      # The list of kernes to keep is auto-generated into this file:
      #   /etc/apt/apt.conf.d/01autoremove-kernels
      # After the apt commands below, we now remove old configuration files and print the number of kernels kept.
      # This way, if it grows too much, the user will hopefully realise
      if false; then
        echo "Purging old kernels..."
        sudo purge-old-kernels --keep 6 --assume-yes
        echo
      fi

      echo "Autoremoving..."
      sudo apt-get --assume-yes autoremove
      echo

      echo "Autocleaning..."
      sudo apt-get --assume-yes autoclean
      echo


      # See the comment above about purge-old-kernels for more information on the following steps.

      # apt seems to keep the configuration files for old kernels around. You normally do not need these files.
      # Remove them, because keeping them around takes space and causes confusion about which old kernels
      # are actually installed or not.
      echo "Removing configuration files for old kernels..."

      local LIST
      set +o errexit  # grep yields a non-zero exit code if it fails to match something.
      LIST="$(dpkg --list | grep linux-image | grep "^rc" | cut -d " " -f 3)"
      set -o errexit

      if [[ $LIST = "" ]]; then
        echo "No old kernel configuration files to delete."
      else
        echo "$LIST" | xargs sudo dpkg --purge
      fi
      echo

      if true; then
        echo "Remaining kernels:"
        dpkg --list | grep linux-image | grep --invert-match linux-image-extra
        echo
      fi

      echo "Finished apt maintenance."
    )
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
    echo "Call to diskusage is missing arguments."
    return
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


# ---- Permission check ----

if [[ $OSTYPE != "cygwin" ]]; then

  # On many systems all users have by default permission to see files under the home directories of other users,
  # or at least to traverse those home directories. I consider that a security risk. Therefore,
  # this scripts checks that is not the case, and warns otherwise.
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

  OCTAL_PERMISSIONS=$(stat --printf "%a" "$HOME")
  LAST_TWO_CHARS="${OCTAL_PERMISSIONS:(-2)}"
  if [[ $LAST_TWO_CHARS != "00" ]]; then
    echo "Warning: The home directory permissions are probably not secure."
    echo "Suggested fix: chmod 0700 \"\$HOME\""
  fi

fi


# ---- Emacs ----

if true; then

  export EMACS_BASE_PATH="$HOME/emacs-26.1-bin"

  export EDITOR="$EMACS_BASE_PATH/bin/emacsclient --no-wait"

  # sudo creates a temporary file, and then overwrites the edited file. Option "--no-wait" would break this behavior.
  export SUDO_EDITOR="$EMACS_BASE_PATH/bin/emacsclient"

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

PROMPT_COMMAND=_my_prompt_command


# In order to test with no colours, set TERM to "dumb".

if tput setaf 1 &>/dev/null; then
  declare -r _MY_PROMPT_COMMAND_CAN_COLOURS=true
else
  declare -r _MY_PROMPT_COMMAND_CAN_COLOURS=false
fi


_my_prompt_command ()
{
  local LAST_EXIT_CODE="$?"

  local green=""
  local blue=""
  local red=""
  local magenta=""
  local cyan=""
  local reset=""
  local bold=""
  local pwdcol=""

  if $_MY_PROMPT_COMMAND_CAN_COLOURS; then

    # If this terminal supports colours, assume it's compliant with Ecma-48 (ISO/IEC-6429).

    # "tput setaf" means "set foreground colour".

    red="$(tput setaf 1)"       # ESC[31m
    green="$(tput setaf 2)"     # ESC[32m
    # yellow="$(tput setaf 3)"  # ESC[33m
    blue="$(tput setaf 4)"      # ESC[34m
    magenta="$(tput setaf 5)"   # ESC[35m
    cyan="$(tput setaf 6)"      # ESC[36m

    reset="$(tput sgr0)"       # ESC[m  Alternatively, use ESC[0m for "normal style".
    bold="$(tput bold)"        # ESC[1m


    case "$TERM" in
      # My Emacs has a white background, and other terminals have a black background.
      # Depending on the background, I use different colours for the current directory.
      eterm-color) pwdcol="$blue";;
                *) pwdcol="$cyan";;
    esac

  fi

  local SEPARATOR="  "

  #  The \[ and \] symbols allow bash to understand which parts of the prompt cause no cursor movement; without them, lines will wrap incorrectly
  PS1='\['

  PS1+="$bold$magenta\\u"
  PS1+="${reset}"
  PS1+="@"
  PS1+="$bold$green"
  PS1+="\\h"
  PS1+="$SEPARATOR"
  PS1+="$pwdcol\\w$reset"

  if (( LAST_EXIT_CODE != 0 )); then
    PS1+="$SEPARATOR"
    PS1+="${bold}${red}[Last exit code: ${LAST_EXIT_CODE}]${reset}"
  fi

  PS1+='\]'

  PS1+="\\n\\$ "

  # If this is an xterm, set the window title to "user@host  dir".

  case "$TERM" in
    xterm*|rxvt*) PS1="\\[\\e]0;\\u@\\h$SEPARATOR\\w\\a\\]$PS1";;
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
