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


  update-reminder ()
  {
    # This reminder only works if you are still logged on locally at the given time,
    # see DISPLAY below.

    local -r REMINDER_TEXT="Update the system - see update-and-reboot()."

    local CMD
    printf -v CMD \
           "export DISPLAY=$DISPLAY && DesktopNotification.sh %q" \
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
    local CMD=""

    append_cmd_with_echo "sudo " "apt-get update"
    CMD+=" && "

    # - About the "--force-confdef" and "--force-confold" options:
    #   Avoiding the apt configuration file questions (when a config file has been modified on this system but the package brings an updated version):
    #   With --force-confdef, apt decides by itself when possible (in other words, when the original configuration file has not been touched).
    #   Otherwise, option --force-confold retains the old version of the file. The new version is installed with a .dpkg-dist suffix.
    #
    # - Is there a way to see whether any such .dpkg-dist files were created? Otherwise:
    #   find /etc -type f -name '*.dpkg-*'
    #
    # - The "--with-new-pkgs" option means:
    #       Upgrade currently-installed packages and install new packages pulled in by updated dependencies.
    #   That is what "apt upgrade" does. Command "apt-get upgrade" does not do it by default.
    #   Without this option, you will often get this warning, and some packages will not update anymore:
    #       The following packages have been kept back:
    #       (list of packages that were not updated)
    #   That happens for example if a Linux kernel update changes the ABI, because it needs to install new packages then.
    #   Option "--with-new-pkgs" maps to "APT::Get::Upgrade-Allow-New".
    #
    # - We could use the following option to save disk space:
    #   APT::Keep-Downloaded-Packages "0";

    append_cmd_with_echo "sudo " "apt-get upgrade  --quiet  --with-new-pkgs  -o Dpkg::Options::='--force-confdef'  -o Dpkg::Options::='--force-confold'  --assume-yes"

    CMD+=" && "
    append_cmd_with_echo "sudo " "apt-get autoremove --assume-yes"
    CMD+=" && "
    append_cmd_with_echo "sudo " "apt-get autoclean --assume-yes"


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
    #
    # The first 'sed' expression replaces all CR characters in the middle of a line with an LF character.
    # Those are all CR characters that are followed by some other character in the same line.
    local -r SED_EXPRESSION_1='s/\r\(.\)/\n\1/g'
    # The second 'sed' expression removes any remailing LF characters, which will always be at the end of a line.
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

    if true; then
      CMD+=" && "
      append_cmd_with_echo "sudo " "shutdown --reboot now"
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

if is_var_set "EMACS_BASE_PATH"; then

  # Some tools, like "virsh snapshot-edit", expect the editor command to wait until the user closes the file.
  # export EDITOR="$EMACS_BASE_PATH/bin/emacsclient --no-wait"
  export EDITOR="$EMACS_BASE_PATH/bin/emacsclient"

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
