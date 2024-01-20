#!/bin/bash

# Version 1.04.
#
# Copyright (c) 2022-2024 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r -i EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit "$EXIT_CODE_ERROR"
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


update-and-reboot-or-shutdown ()
{
  local -r L_OP_ARG="$1"

  local CMD=""
  local TMP

  # About preventing interactive post-install configuration dialogs in packages such as postfix:
  #
  # Apart from package 'postfix', another example of such a dialog is:
  #
  #       If Docker is upgraded without restarting the Docker daemon, Docker will often
  #       have trouble starting new containers, and in some cases even maintaining the
  #       containers it is currently running. See https://launchpad.net/bugs/1658691 for
  #       an example of this breakage.
  #
  #       Normally, upgrading the package would simply restart the associated daemon(s).
  #       In the case of the Docker daemon, that would also imply stopping all running
  #       containers (which will only be restarted if they're part of a "service", have an
  #       appropriate restart policy configured, or have some other means of being
  #       restarted such as an external systemd unit).
  #
  #       Automatically restart Docker daemon?
  #               <Yes>      <No>
  #
  # Yet another example: package 'iptables-persistent' asks similarly for "Save current IPv6 rules?".
  #
  # apt-get's options '--assume-yes' and '--quiet' are not enough, you also need this environment variable:
  #
  # DEBIAN_FRONTEND=noninteractive
  #
  # Related note: You can change the default frontend with:  dpkg-reconfigure debconf --frontend=noninteractive

  CMD+="echo"

  CMD+=" && "

  declare -r LOG_FILENAME="$HOME/update-with-apt.sh.log"
  declare -r LOG_FILENAME_UNFILTERED="$HOME/update-with-apt.sh.unfiltered.log"

  printf -v TMP "echo Creating log file: %q" "$LOG_FILENAME"
  CMD+="$TMP"

  CMD+=" && "

  append_cmd_with_echo "" "export DEBIAN_FRONTEND=noninteractive"

  CMD+=" && "

  append_cmd_with_echo "sudo " "apt-get update"

  CMD+=" && "

  # - About preventing the apt configuration file questions
  #   (when a config file has been modified on this system but the package brings an updated version):
  #
  #   With --force-confdef, apt decides by itself when possible (in other words, when the original configuration file has not been touched).
  #   Otherwise, option --force-confold retains the old version of the file. The new version is installed with a .dpkg-dist suffix.
  #
  #   Is there a way to see whether any such .dpkg-dist files were created? Otherwise, I guess this would work:
  #     find /etc -type f -name '*.dpkg-*'
  #
  # - We could use the following option to save disk space:
  #   APT::Keep-Downloaded-Packages "0";
  #
  # - We could automatically remove unused dependencies:
  #   Unattended-Upgrade::Remove-Unused-Dependencies "true";

  local COMMON_OPTIONS="--quiet  -o Dpkg::Options::='--force-confdef'  -o Dpkg::Options::='--force-confold'  --assume-yes"

  if $ONLY_SIMULATE_UPGRADE; then
    COMMON_OPTIONS+="  --dry-run"
  fi

  if false; then

    # I stopped using "apt upgrade" because it does not remove packages if needed.
    #   I hit this issue because I had installed a PPA to keep LibreOffice more up to date.
    #   When this PPA switched between LibreOffice 6.3 to 6.4, related packages were "kept back"
    #   with no useful explanation. It turned out that package "uno-libs3" had to be uninstalled.
    #   I only found out with Synaptic. The  "Software Updater" application, which is /usr/bin/update-manager,
    #   described as "GNOME application that manages apt updates", was also unable to upgrade the system.
    #   This happend on Ubuntu MATE 18.04.4.
    #   There is no extra option like "--autoremove-packages-if-needed-for-upgrading",
    #   for such an automatic upgrade it is better to switch to "apt-get dist-upgrade", see below.
    #
    # The "--with-new-pkgs" option below means:
    #       Upgrade currently-installed packages and install new packages pulled in by updated dependencies.
    #   That is what "apt upgrade" does. Command "apt-get upgrade" does not do it by default.
    #   Without this option, you will often get the warning below, and some packages will not update anymore:
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


    # Detect and delete orphaned configuration files.
    #
    # Package status 'rc' below means:
    #   r: the package was marked for removal
    #   c: the configuration files are currently present in the system

    # shellcheck disable=SC2016
    CMD+='LIST="$(dpkg --list | grep "^rc" | cut -d " " -f 3)"'

    CMD+=" ; "  # No && because of the possible error code.

    CMD+="set -o errexit"

    CMD+=" && "

    # shellcheck disable=SC2016
    CMD+='if [[ $LIST = "" ]]; then echo "No orphaned package configuration files to delete."; else echo "Deleting orphaned package configuration files..." && echo "$LIST" | xargs dpkg --purge; fi'


    # Check how many kernels there are. Disabled at the moment.
    # Recent Ubuntu versions should clean up old kernels automatically.

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


  declare -r KEEP_UNFILTERED_LOG=false

  # Creating the log file here before running the command with 'sudo' has the nice side effect
  # that it will be created with the current user account. Otherwise, the file would be owned by root.

  local FILE_HEADER="Running command:"
  FILE_HEADER+=$'\n'
  # Perhaps we should mention here that we will be setting flags like 'pipefail' beforehand.
  FILE_HEADER+="$CMD"

  echo "$FILE_HEADER">"$LOG_FILENAME"

  if $KEEP_UNFILTERED_LOG; then
    echo "$FILE_HEADER">"$LOG_FILENAME_UNFILTERED"
  fi


  # I would like to get rid of log lines like these:
  #
  #   (Reading database ... ^M(Reading database ... 5%^M(Reading database ... 10%^M [...]
  #   Preparing to unpack .../00-ghostscript-x_9.26~dfsg+0-0ubuntu0.18.04.10_amd64.deb ...^M
  #   Unpacking ghostscript-x (9.26~dfsg+0-0ubuntu0.18.04.10) over (9.26~dfsg+0-0ubuntu0.18.04.9) ...^M
  #   Preparing to unpack .../01-ghostscript_9.26~dfsg+0-0ubuntu0.18.04.10_amd64.deb ...^M
  #
  # The first log line with the "Reading database" is actually much longer, I have cut it short in the excerpt above.
  # The ^M characters above are carriage return characters (CR, \r, 0x0D), often used in an interactive console to make
  # progress indicators overwrite the current text line.
  #
  # I looked at the whole log output, and there is a mix of 0x0A (LF) and 0x0D + 0x0A (CR+LF) line terminators,
  # with some 0x0D (CR) characters in the middle (the ^M characters) for the progress effect.
  # This is unexpected, for there should be no CR+LF line terminators in a Unix console environment.
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
  # I have not understood what apt-get's --show-progress does yet. I seems to have no effect on the output.
  #
  # In the end, I resorted to using 'sed' to break up such long lines at those CR characters, see below.
  # As an alternative, see my script "FilterTerminalOutputForLogFile.pl".
  #
  # The next time around I start modifying this part again, I should try filtering only the data that goes to the log file.
  # That means filtering after 'tee', instead of beforehand, so that the console output is not filtered.

  declare -r REPLACE_CR_WITH_LF=false

  if $REPLACE_CR_WITH_LF; then

    # This method REPLACE_CR_WITH_LF does not seem to work well. I am getting this effect on a text console:
    #
    #   (Reading database ...
    #                         (Reading database ... 5%
    #                                                 (Reading database ... 10%
    #                                                                          (Reading database ... 15%
    # I haven't understood yet why. The filtered log file seems fine and does not have that problem
    # whend dumped to the console.

    # The first 'sed' expression replaces all CR characters in the middle of a line with an LF character.
    # Those are all CR characters that are followed by some other character in the same line.
    local -r SED_EXPRESSION_1='s/\r\(.\)/\n\1/g'

    # The second 'sed' expression removes any remaining CR characters, which will always be at the end of a line.
    local -r SED_EXPRESSION_2='s/\r$//'

    printf -v SED_ARGS \
           -- \
           "-e %q -e %q" \
           "$SED_EXPRESSION_1" \
           "$SED_EXPRESSION_2"

  else

    # This code just adds an LF after any lone CR.
    #
    # The resulting output will leave any LF and CR+LF line terminators terminators, and replace
    # any CR in the middle with CR+LF. That means that the output will contain a mixture
    # of LF and CR+LF line terminators.
    # The result is not optimal, for the progress indications will be spilled over several lines
    # on the text console, but it work well enough.

    local -r SED_EXPRESSION='s/\r\(.\)/\r\n\1/g'

    printf -v SED_ARGS \
           -- \
           "-e %q" \
           "$SED_EXPRESSION"
  fi

  # Turn the standard error-detection flags on, although probably only 'pipefail' is important for the command we will be executing.
  local -r ERR_DETECT_FLAGS+="set -o errexit && set -o nounset && set -o pipefail"

  if false; then
    echo "Update command: $CMD"
    echo
  fi

  # Redirect stdin to </dev/null . Otherwise, some upgrade step may be tempted to prompt the user.
  # That would defeat the purpose of this script, which is "upgrade and then reboot or shutdown"
  # and not "randomly forever wait for user input".

  printf -v CMD \
         "%s && { %s ;} 2>&1 </dev/null | " \
         "$ERR_DETECT_FLAGS" \
         "$CMD"

  if $KEEP_UNFILTERED_LOG; then

    printf -v TMP \
           "tee --append -- %q | " \
           "$LOG_FILENAME_UNFILTERED"

    CMD+="$TMP"

  fi

  printf -v TMP \
         "sed --unbuffered %s | tee --append -- %q" \
         "$SED_ARGS" \
         "$LOG_FILENAME"

  CMD+="$TMP"

  if ! $ONLY_SIMULATE_UPGRADE; then
    CMD+=" && "
    append_cmd_with_echo "sudo " "shutdown $L_OP_ARG now"
  fi

  # We need to use 'sudo' only once for all commands. Otherwise, if the downloads take too long,
  # the user may be prompted for the sudo password again in the middle of the process.
  printf -v CMD "sudo bash -c %q" "$CMD"

  echo "$CMD"
  eval "$CMD"

  if $ONLY_SIMULATE_UPGRADE; then
    echo "Log file created: $LOG_FILENAME"
  fi
}


if (( $# == 0 )); then

  # In my experience, the system is not completely stable after updating packages.
  # So force the user to shutdown or to reboot.

  abort "Specify one of these: shutdown, reboot or dry-run."

fi

declare -r OPERATION="$1"

ONLY_SIMULATE_UPGRADE=false

case "$OPERATION" in
  reboot)   OPERATION_ARG="--reboot";;
  shutdown) OPERATION_ARG="--poweroff";;
  dry-run)  OPERATION_ARG="<none>"
            ONLY_SIMULATE_UPGRADE=true;;
  *) abort "Unknown operation \"$OPERATION\"."
esac

update-and-reboot-or-shutdown "$OPERATION_ARG"
