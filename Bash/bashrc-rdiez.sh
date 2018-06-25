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

fi


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

  # On many systems all users have by default permission to see files under the home directories of other users.
  # Check that this is not the case.
  OCTAL_PERMISSIONS=$(stat --printf "%a" "$HOME")
  LAST_TWO_CHARS="${OCTAL_PERMISSIONS:(-2)}"
  if [[ $LAST_TWO_CHARS != "00" ]]; then
    echo "Warning: The home directory permissions are probably not secure."
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

set_my_prompt ()
{
  if tput setaf 1 &>/dev/null; then

    # If this terminal supports colours, assume it's compliant with Ecma-48 (ISO/IEC-6429).

    # "tput setaf" means "set foreground colour".

    local green
    local blue
    local magenta
    local cyan

    # red="$(tput setaf 1)"     # ESC[31m
    green="$(tput setaf 2)"     # ESC[32m
    # yellow="$(tput setaf 3)"  # ESC[33m
    blue="$(tput setaf 4)"      # ESC[34m
    magenta="$(tput setaf 5)"   # ESC[35m
    cyan="$(tput setaf 6)"      # ESC[36m

    local reset
    local bold
    reset="$(tput sgr0)"       # ESC[m  Alternatively, use ESC[0m for "normal style".
    bold="$(tput bold)"        # ESC[1m

    local pwdcol

    case "$TERM" in
      # My Emacs has a white background, and other terminals have a black background.
      eterm-color) pwdcol="$blue";;
                *) pwdcol="$cyan";;
    esac

    #  The \[ and \] symbols allow bash to understand which parts of the prompt cause no cursor movement; without them, lines will wrap incorrectly
    local -r prompt_begin='\['
    local -r prompt_end='\]'

    PS1="$prompt_begin$bold$magenta\\u$green@\\h:$pwdcol\$PWD$reset$prompt_end\\n\\$ "

  else
    PS1='\u@\h:$PWD\n\$ '
  fi


  # If this is an xterm, set the window title to user@host: dir

  case "$TERM" in
    xterm*|rxvt*) PS1="\\[\\e]0;\\u@\\h: \$PWD\\a\\]$PS1";;
               *) ;;
  esac
}

set_my_prompt


# ---- Readline ----

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


# ---- End ----

if $BASH_RC_RDIEZ_VERBOSE; then
  echo "Finished running ${BASH_SOURCE[0]} ."
fi

unset BASH_RC_RDIEZ_VERBOSE
