#!/bin/bash

# mount-windows-shares-sudo.sh version 1.62
# Copyright (c) 2014-2024 R. Diez - Licensed under the GNU AGPLv3
#
# Mounting Windows shares under Linux can be a frustrating affair.
# At some point in time, I decided to write this script template
# to ease the pain.
#
# This script helps in the following scenario:
# - You need to mount a given set of Windows file shares every day.
# - You do not mind using a text console.
# - You wish to mount with the traditional Linux method (you need Linux root password).
# - You want the choice to store your Windows account passwords on this script,
#   which is convenient but not very safe, or to enter the password every time,
#   so that the system forgets it straight away.
# - Sometimes  mounting or unmounting a Windows share fails, for example with
#   error message "device is busy", so you need to retry.
#   This script should skip already-mounted shares, so that simply retrying
#   eventually works without further manual intervention.
# - Every now and then you add or remove a network share, but by then
#   you have already forgotten all the mount details and don't want
#   to consult the man pages again.
#
# You'll have to edit this script in order to add your particular Windows shares.
# However, the only thing you will probably ever need to change
# is at the bottom of routine user_settings below, look for "specify your mounts here".
#
# With no arguments, or with argument 'mount', this script mounts all shares it knows about.
# Specify argument "umount" or "unmount" in order to unmount all shares.
# Use argument "sudoers" to generate entries suitable for config file /etc/sudoers,
# so that you do not need to type your 'sudo' password every time.
#
# If you are having trouble unmounting a mount point because it is still in use,
# commands "lsof" or "fuser --verbose --mount <mount point>"  might help. Alternatively,
# this script could use umount's "lazy unmount" option, but then you should add a waiting loop
# with a time-out at the end. Otherwise, you cannot be sure whether the mount points have been
# unmounted or not when this script ends.
# In case you want to manually issue such "lazy" unmount commands, you can try these:
#   sudo umount --all --types cifs --lazy
#   sudo umount --all --types cifs --lazy --force
#
# If 'mount' fails to mount a file system of type "cifs", perhaps with error message "wrong fs type",
# your system is probably  missing the 'mount.cifs' tool. On Ubuntu/Debian systems, the package to install
# is called 'cifs-utils'.
#
# In order for Windows hostnames to resolve on your Linux system, you will probably have to install package
# libnss-winbind and edit file /etc/nsswitch.conf accordingly.
#
# A better alternative would be to use a graphical tool like Gigolo, which can
# automatically mount your favourite shares on start-up. Gigolo uses the FUSE-based
# mount system, which does not require the root password in order to mount Windows shares.
# Unfortunately, I could not get it to work reliably unter Ubuntu 14.04 as of May 2014.


set -o errexit
set -o nounset
set -o pipefail

user_settings ()
{
  # About variable WINDOWS_DOMAIN below:
  #
  #   If there is no Windows Domain, this would be the Windows computer name (hostname).
  #   Apparently, the workgroup name works too. In fact, I do not think this name
  #   matters at all if there is no domain. It is best to use the computer name,
  #   especially if you are connecting to different computers, as the password prompt
  #   will then provide a hint about which computer the password is for.
  #
  #
  # About variable WINDOWS_PASSWORD below:
  #
  #   If you do not want to be prompted for your Windows password every time,
  #   you will have to store your password in variable WINDOWS_PASSWORD below.
  #
  #   Avoid using passwords that begin with a space or have a comma (','),
  #   as it may not work depending on the PASSWORD_METHOD further below.
  #
  #   Special password "prompt" means that the user will be prompted for the password.
  #
  #   SECURITY WARNING: If you choose not to prompt for the Windows password every time,
  #                     and you store the password below, anyone that can read this script
  #                     can also find out your password.
  #
  #
  # About the add_mount lines below:
  #
  #   Arguments to add_mount() are:
  #   1) Windows path to mount (a network path).
  #   2) Mount directory, a local directory which must be empty and will be created if it does not exist.
  #   3) Mount options:
  #
  #     - Specify at least "rw" for 'read/write', or alternatively "ro" for 'read only'.
  #
  #     - You can also specify the SMB protocol version, like "vers=2.1" for Windows 7 and newer,
  #       or "vers=3.1.1" for Windows 10.
  #
  #       Linux can auto-negotiate from September 2017 the highest SMB version >= 2.1 possible if you specify "vers=default".
  #       Nowadays (as of 2023) you do not even need "vers=default", negotiation happens automatically.
  #       The exact version 2.0 did not work for me, at least against an older Buffalo NAS that only supported SMB 2.0.
  #       In order to check the negotiated SMB version, look for "vers=" in /proc/mounts
  #       or in the output of 'findmnt --notruncate'.
  #
  #       Older versions of 'mount.cifs' use version 1.0 by default, but such old SMB protocol versions
  #       may have been disabled on the servers because of long-standing security issues.
  #       See the man page for 'mount.cifs' for more information about SMB protocol versions.
  #
  #     - You should request encryption with option 'seal'. Encryption is only available from SMB 3.0
  #       (from Windows 8 and Windows Server 2012).
  #
  #     - Controlling the unresponsive server timeout:
  #
  #       Setting 'echo_interval' determines the interval at which echo requests
  #       are sent to the server on an idling connection.
  #
  #       The Linux Kernel's CIFS client will wait 2 * echo_interval before marking a connection as unresponsive.
  #       The default echo_interval is 60 seconds, so a connection will timeout in 2 minutes, which is too long.
  #       As a result, any random process accessing the mount point may hang for that long. If that process
  #       happens to be your desktop environment's file manager, which perhaps also manages your desktop icons,
  #       then the whole desktop will hang during that time.
  #
  #       Keep in mind that setting echo_interval to 4 will also make the client send packets every 4 seconds
  #       to keep idle connections alive. If all clients start doing this, it might overload the network or the server.
  #
  #       After the first timeout on a CIFS mount point, further attempts to use it will all time out in about 10 seconds,
  #       regardless of the echo_interval value. Every mount point seems to have its own timeout, even if several of them
  #       refer to the same server. Timeout error messages are usually "Resource temporarily unavailable" or "Host is down".
  #
  #       If the Windows server becomes reachable again after a network glitch, requests on the affected mount points
  #       start succeeding once more (at least with SMB protocol version 2.1).
  #
  #       The CIFS server timeout also affects shutting down Linux, because that involves unmounting all mount points,
  #       which communicates with the SMB server.  Therefore, if you set echo_interval too high, and a server
  #       happens to be unresponsive during shutdown, Linux may wait for a long time before powering itself off,
  #       even if there are no read or write operations queued on the related mount point.
  #       That is very annoying.
  #
  #       All these notes are mostly based on empirical research. I haven't found yet a good overview of
  #       the timeout behaviour of the Linux Kernel's CIFS client.
  #       I tried seeking for help in 2017 in the linux-cifs mailing list at vger.kernel.org,
  #       but my e-mails bounced back with error message "the policy analysis reported:
  #       Your address is not liked source for email". This issue has been reported oft, and I also e-mailed
  #       webmaster@kernel.org about it, but they do not seem to care. Many other mailing lists I use
  #       do not have this problem.
  #       Later note: I have tried posting to the mailing list again in February 2024, and another user confirmed
  #       the lack of immediate error for connections which have already timed out, and even offered a patch.
  #
  #   4) Autopen option: "AutoOpen" or "NoAutoOpen" (case insensitive)
  #
  #      Sometimes you just want to mount a single share in order to manually use it straight away. In this case,
  #      it is often convenient to automatically open a file explorer window on the mount point.
  #
  #      By default, the mount point directory is opened with 'xdg-open', but you can set
  #      environment variable OPEN_FILE_EXPLORER_CMD to choose a different command.
  #      The command specified in OPEN_FILE_EXPLORER_CMD gets 2 arguments: the first one is '--',
  #      and the second one is the directory name. Therefore, the tool you specify must support
  #      the popular '--' separator between command-line options and filename arguments.
  #      You could also use script open-file-explorer.sh in this repository, which
  #      tries to detect the current desktop environment in order to automatically choose
  #      the best tool to open a file manager on a particular directory.

  # These are just examples, look for "specify your mounts here" further below.
  if false; then

    # See above for information about the following variables and mount options.

    WINDOWS_DOMAIN="MY_DOMAIN"
    WINDOWS_USER="MY_LOGIN"
    WINDOWS_PASSWORD="prompt"

    add_mount "//SERVER1/ShareName1/Dir1" "$HOME/WindowsShares/Server1/ShareName1Dir1" "rw,seal"                 "NoAutoOpen"
    add_mount "//SERVER2/ShareName2/Dir2" "$HOME/WindowsShares/Server2/ShareName2Dir2" "rw,seal,echo_interval=4" "NoAutoOpen"

    # If you use more than one Windows account, you have to repeat everything above for each account. For example:

    WINDOWS_DOMAIN="MY_DOMAIN_2"
    WINDOWS_USER="MY_LOGIN_2"
    WINDOWS_PASSWORD="prompt"

    add_mount "//SERVER3/ShareName3/Dir3" "$HOME/WindowsShares/Server3/ShareName3Dir3" "rw,seal"                 "NoAutoOpen"
    add_mount "//SERVER4/ShareName4/Dir4" "$HOME/WindowsShares/Server4/ShareName4Dir4" "rw,seal,echo_interval=4" "NoAutoOpen"

  fi

  # The line below generates a reasonable error message but no ShellCheck warnings.
  #
  # This placeholder strategy makes it easy to synchronise changes: when this script template
  # is upgraded, the lines below should be the only thing the user has modified and needs to keep,
  # everything else around can be upgraded without worry.

  "---> Remove this line and specify your mounts here, for example by copying and modifying the examples above."
}


declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r MOUNT_CMD="mount"
declare -r UNMOUNT_CMD="umount"

declare -r SPECIAL_PROMPT_WINDOWS_PASSWORD="prompt"


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit 1
}


str_starts_with ()
{
  # $1 = string
  # $2 = prefix

  # From the bash manual, "Compound Commands" section, "[[ expression ]]" subsection:
  #   "Any part of the pattern may be quoted to force the quoted portion to be matched as a string."
  # Also, from the "Pattern Matching" section:
  #   "The special pattern characters must be quoted if they are to be matched literally."

  if [[ $1 == "$2"* ]]; then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


str_ends_with ()
{
  # $1 = string
  # $2 = suffix

  case "$1" in
     *$2) return $BOOLEAN_TRUE;;
     *)   return $BOOLEAN_FALSE;;
  esac
}


is_dir_empty ()
{
  shopt -s nullglob
  shopt -s dotglob  # Include hidden files.

  # Command 'local' is in a separate line, in order to prevent masking any error from the external command (or operation) invoked.
  local -a FILES
  FILES=( "$1"/* )

  if (( ${#FILES[@]} == 0 )); then
    return $BOOLEAN_TRUE
  else
    if false; then
      echo "Files found: ${FILES[*]}"
    fi
    return $BOOLEAN_FALSE
  fi
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


escape_for_sudoers ()
{
  local STR="$1"

  # Escaping of some characters only works separately.
  STR="${STR//\\/\\\\}"  # \ -> \\
  STR="${STR//\*/\\*}"   # * -> \*
  STR="${STR//\?/\\?}"   # ? -> \?

  local CHARACTERS_TO_ESCAPE=",:=[]!"

  local -i CHARACTERS_TO_ESCAPE_LEN="${#CHARACTERS_TO_ESCAPE}"
  local -i INDEX

  for (( INDEX = 0 ; INDEX < CHARACTERS_TO_ESCAPE_LEN ; ++INDEX )); do

    local CHAR="${CHARACTERS_TO_ESCAPE:$INDEX:1}"

    STR="${STR//$CHAR/\\$CHAR}"

  done

  ESCAPED_STR="$STR"
}


declare -A ALL_WINDOWS_PASSWORDS=()  # Associative array.

get_windows_password ()
{
  local MOUNT_WINDOWS_DOMAIN="$1"
  local MOUNT_WINDOWS_USER="$2"
  local MOUNT_WINDOWS_PASSWORD="$3"

  if [[ $MOUNT_WINDOWS_PASSWORD != "$SPECIAL_PROMPT_WINDOWS_PASSWORD" ]]; then
    RETRIEVED_WINDOWS_PASSWORD="$MOUNT_WINDOWS_PASSWORD"
    return
  fi

  local KEY="$MOUNT_WINDOWS_DOMAIN/$MOUNT_WINDOWS_USER"

  if test "${ALL_WINDOWS_PASSWORDS[$KEY]+string_returned_ifexists}"; then
    RETRIEVED_WINDOWS_PASSWORD="${ALL_WINDOWS_PASSWORDS[$KEY]}"
    return
  fi

  read -r -s -p "Please enter the password for Windows account $MOUNT_WINDOWS_DOMAIN\\$MOUNT_WINDOWS_USER: " RETRIEVED_WINDOWS_PASSWORD
  printf "\\n"

  ALL_WINDOWS_PASSWORDS["$KEY"]="$RETRIEVED_WINDOWS_PASSWORD"
}


# If we try to mount or unmount while the current directory is below
# the mount point, there is going to be trouble, so prevent it.

check_working_dir_not_under_dir ()
{
  local REF_DIR="$1"

  local REF_DIR_ABS
  local PWD_ABS

  REF_DIR_ABS="$(readlink --canonicalize-missing --verbose -- "$REF_DIR")"
  PWD_ABS="$(readlink --canonicalize-missing --verbose -- "$PWD")"

  if str_starts_with "$PWD_ABS" "$REF_DIR_ABS"; then
    abort "The current directory is located under the mount point."
  fi
}


declare -a MOUNT_ARRAY=()

declare -i MOUNT_ENTRY_ARRAY_ELEM_COUNT=7

add_mount ()
{
  if (( $# != 4 )); then
    abort "Wrong number of arguments passed to add_mount()."
  fi

  # Do not allow a terminating slash. Otherwise, we'll have trouble comparing
  # the paths with the contents of /proc/mounts.

  if str_ends_with "$1" "/"; then
    abort "Windows share paths must not end with a slash (/) character. The path was: $1"
  fi

  if str_ends_with "$2" "/"; then
    abort "Mount points must not end with a slash (/) character. The path was: $2"
  fi

  local MOUNT_AUTO_OPEN_LOWER_CASE="${4,,}"
  local AUTO_OPEN

  case "$MOUNT_AUTO_OPEN_LOWER_CASE" in
    autoopen)    AUTO_OPEN=true;;
    noautoopen)  AUTO_OPEN=false;;
    *) abort "Error: Invalid auto-open option \"$4\".";;
  esac

  MOUNT_ARRAY+=( "$1" "$2" "$3" "$WINDOWS_DOMAIN" "$WINDOWS_USER" "$WINDOWS_PASSWORD" "$AUTO_OPEN" )
}


create_mount_point_dir ()
{
  local -r MOUNT_POINT="$1"

  mkdir --parents -- "$MOUNT_POINT"

  # It is recommended that the mount point directory is read only.
  # This way, if mounting the Windows file share fails, other processes will not inadvertently write to your local disk.
  #
  # Removing the execute ('x') permission is actually a stronger variant of "read only". With only the read permission ('r'),
  # you can list the files inside the directory, but you cannot access their dates, sizes or permissions.
  # In fact, removing the write ('w') permission is actually unnecessary, because 'w' has no effect without 'x'.
  if true; then
    chmod a-wx "$MOUNT_POINT"
  fi
}


mount_elem ()
{
  local MOUNT_ELEM_NUMBER="$1"
  local WINDOWS_SHARE="$2"
  local MOUNT_POINT="$3"
  local MOUNT_OPTIONS="$4"
  local MOUNT_WINDOWS_DOMAIN="$5"
  local MOUNT_WINDOWS_USER="$6"
  local MOUNT_WINDOWS_PASSWORD="$7"
  local MOUNT_AUTO_OPEN="$8"
  local AUTO_OPEN_ENABLED="$9"

  local WINDOWS_SHARE_QUOTED
  local MOUNT_POINT_QUOTED
  printf -v WINDOWS_SHARE_QUOTED "%q" "$WINDOWS_SHARE"
  printf -v MOUNT_POINT_QUOTED   "%q" "$MOUNT_POINT"

  # Separate both directories with extra spaces, so that it is easier to tell them apart
  # and copy them from the console if needed. They can be pretty long and sometimes
  # I had difficulty isolating them.
  local CMD="-t cifs  $WINDOWS_SHARE_QUOTED  $MOUNT_POINT_QUOTED  -o "

  # We would normally surround each argument in quotes, like this:  user="xxx",uid="yyy", domain="zzz".
  # However, that would not work with the sudoers file.
  CMD+="user=$MOUNT_WINDOWS_USER"
  CMD+=",uid=$UID"
  CMD+=",domain=$MOUNT_WINDOWS_DOMAIN"

  # Linux users will not usually run any programs off a Windows share.
  # However, all files have the "execute" permission set by default,
  # which is a little risky, and sometimes annoying. For example,
  # the file manager usually prompts whether you want to
  # run a text file (!), or open it in a text editor.
  #
  # Option 'noexec' does not actually clear our view of the "execute"
  # permission bit, but it does prevent direct execution. The file manager
  # should then be smart enough not to prompt anymore when opening a text file.
  #
  # Option 'file_mode=0666' clears our view of the "execute" permission bit,
  # so that it always appears unset.
  # The octal mask 666 clears the lowest bit ('x') of all
  # three 'user', 'group' and 'other' permission sets.
  # Note that mount option 'fmask' has been deprecated in favour of 'file_mode'.
  CMD+=",noexec"
  CMD+=",file_mode=0666"

  # We would usually specify here option 'noatime', but it is apparently ignored.
  # It probably has no effect on SMB/CIFS mounts.

  CMD+=",$MOUNT_OPTIONS"
  # Note that depending on PASSWORD_METHOD, an extra option is appended to CMD later.

  # Other alternatives to consider:
  # - Passing the password via stdin, which is risky, as mount.cifs could decide in the future to ask something else.
  # - Use the password=arg option, which is insecure. The password cannot contain a comma (',') then.
  local PASSWORD_METHOD="environment"

  if [[ $MODE == "sudoers" ]]; then

    case "$PASSWORD_METHOD" in

      environment)

        local MOUNT_CMD_FULL_PATH

        set +o errexit

        MOUNT_CMD_FULL_PATH="$(type -p "$MOUNT_CMD")"

        local TYPE_EXIT_CODE="$?"

        set -o errexit

        if (( TYPE_EXIT_CODE != 0 )); then
          abort "Command \"$MOUNT_CMD\" not found."
        fi

        local ESCAPED_STR
        if false; then
          CMD+=" Test \\ Test , Test : Test = Test [ Test ] Test ! Test * Test ?"
        fi
        escape_for_sudoers "$CMD"

        echo "$USER ALL=(root) NOPASSWD:SETENV: $MOUNT_CMD_FULL_PATH $ESCAPED_STR"

        ;;

      credentials-file)

        # The problem is argument "credentials=tmpfilename" that gets appended to CMD below.
        abort "For the sudoers file, only the password method 'environment' is currently supported."
        ;;

      *) abort "Internal error: Invalid password method \"$PASSWORD_METHOD\".";;
    esac

  else

    if test "${DETECTED_MOUNT_POINTS[$MOUNT_POINT]+string_returned_ifexists}"; then

      local MOUNTED_REMOTE_DIR="${DETECTED_MOUNT_POINTS[$MOUNT_POINT]}"

      if [[ $MOUNTED_REMOTE_DIR != "$WINDOWS_SHARE" ]]; then
        abort "Mount point \"$MOUNT_POINT\" already mounted. However, it does not reference \"$WINDOWS_SHARE\" as expected, but \"$MOUNTED_REMOTE_DIR\" instead."
      fi

      printf "%i: Already mounted \"%s\" on \"%s\".\\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT"

    else

      CREATED_MSG=""

      # If the mount point happens to exist as a broken symlink, it was probably left behind
      # by sibling script mount-windows-shares-gvfs.sh , so delete it.
      if [ -h "$MOUNT_POINT" ] && [ ! -e "$MOUNT_POINT" ]; then

        rm -f -- "$MOUNT_POINT"

        create_mount_point_dir "$MOUNT_POINT"
        CREATED_MSG=" (removed existing broken link, then created)"

      elif [ -e "$MOUNT_POINT" ]; then

       if ! [ -d "$MOUNT_POINT" ]; then
         abort "Mount point \"$MOUNT_POINT\" is not a directory."
       fi

       if ! is_dir_empty "$MOUNT_POINT"; then
         abort "Mount point \"$MOUNT_POINT\" is not empty (already mounted?). While not strictly a requirement for mounting purposes, this script does not expect a non-empty mount point."
       fi

      else

        create_mount_point_dir "$MOUNT_POINT"
        CREATED_MSG=" (created)"

      fi

      printf "%i: Mounting \"%s\" on \"%s\"%s...\\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT" "$CREATED_MSG"

      check_working_dir_not_under_dir "$MOUNT_POINT"

      get_windows_password "$MOUNT_WINDOWS_DOMAIN" "$MOUNT_WINDOWS_USER" "$MOUNT_WINDOWS_PASSWORD"

      case "$PASSWORD_METHOD" in

        environment)

          # It is unfortunate that we need to use "--preserve-env", as we only need to pass the single environment
          # variable PASSWD. Passing all other environment variables is an unnecessary security risk.
          # Be careful not to pass PASSWD as a command-line argument to sudo, because then your Windows password
          # would be visible to all users.
          #
          # From sudo version 1.8.21, available from Ubuntu 18.04, you can use --preserve-env=PASSWD
          # to just pass that single variable. I was the one to request that sudo feature just because of this script! 8-)

          local PASSWD
          export PASSWD="$RETRIEVED_WINDOWS_PASSWORD"

          SUDO_MOUNT_CMD="sudo --preserve-env -- $MOUNT_CMD $CMD"

          # Note that this is not exactly what is actually executed, because of PASSWD.
          # But the user should be able to copy the command from the text output and run it manually,
          # only he will get prompted for the Windows share password.
          echo "sudo -- $MOUNT_CMD $CMD"

          eval "$SUDO_MOUNT_CMD"

          unset -v PASSWD  # Just in case, keep the password as little time as possible in an exported variable.

          ;;

        credentials-file)

          # Due to a limitation in mount.cifs, the password cannot begin with a space when using this method.

          local CREDENTIALS_TMP_FILENAME
          CREDENTIALS_TMP_FILENAME="$(mktemp --tmpdir "tmp.$SCRIPT_NAME.XXXXXXXXXX.txt")"

          if false; then
            echo "CREDENTIALS_TMP_FILENAME: $CREDENTIALS_TMP_FILENAME"
          fi

          CMD+=",credentials=\"$CREDENTIALS_TMP_FILENAME\""

          echo "password=$RETRIEVED_WINDOWS_PASSWORD" >"$CREDENTIALS_TMP_FILENAME"

          # After this point, make sure to delete the temporary file even if a command fails.

          set +o errexit

          eval "sudo -- $MOUNT_CMD $CMD"

          local SUDO_EXIT_CODE="$?"

          set -o errexit

          rm -- "$CREDENTIALS_TMP_FILENAME"

          if (( SUDO_EXIT_CODE != 0 )); then
            return "$SUDO_EXIT_CODE"
          fi

          ;;

        *) abort "Internal error: Invalid password method \"$PASSWORD_METHOD\".";;
      esac


      if $MOUNT_AUTO_OPEN && $AUTO_OPEN_ENABLED; then
        local CMD_OPEN_FOLDER

        if is_var_set "OPEN_FILE_EXPLORER_CMD"; then
          printf -v CMD_OPEN_FOLDER  "%q -- %q"  "$OPEN_FILE_EXPLORER_CMD"  "$MOUNT_POINT"
        else
          # Unfortunately, xdg-open as of version 1.1.3 does not support the usual '--' separator
          # between command-line options and filename arguments.
          printf -v CMD_OPEN_FOLDER  "xdg-open %q"  "$MOUNT_POINT"
        fi

        echo
        echo "$CMD_OPEN_FOLDER"
        eval "$CMD_OPEN_FOLDER"
      fi

    fi
  fi
}


unmount_elem ()
{
  local MOUNT_ELEM_NUMBER="$1"
  local WINDOWS_SHARE="$2"
  local MOUNT_POINT="$3"

  local MOUNT_POINT_QUOTED
  printf -v MOUNT_POINT_QUOTED "%q" "$MOUNT_POINT"

  local CMD="-t cifs $MOUNT_POINT_QUOTED"

  if [[ $MODE == "sudoers" ]]; then

    local UNMOUNT_CMD_FULL_PATH

    set +o errexit

    UNMOUNT_CMD_FULL_PATH="$(type -p "$UNMOUNT_CMD")"

    local TYPE_EXIT_CODE="$?"

    set -o errexit

    if (( TYPE_EXIT_CODE != 0 )); then
      abort "Command \"$UNMOUNT_CMD\" not found."
    fi

    local ESCAPED_STR
    escape_for_sudoers "$CMD"

    echo "$USER ALL=(root) NOPASSWD: $UNMOUNT_CMD_FULL_PATH $ESCAPED_STR"

  else

    if test "${DETECTED_MOUNT_POINTS[$MOUNT_POINT]+string_returned_ifexists}"; then

      local MOUNTED_REMOTE_DIR="${DETECTED_MOUNT_POINTS[$MOUNT_POINT]}"

      if [[ $MOUNTED_REMOTE_DIR != "$WINDOWS_SHARE" ]]; then
        abort "Mount point \"$MOUNT_POINT\" does not reference \"$WINDOWS_SHARE\" as expected, but \"$MOUNTED_REMOTE_DIR\" instead."
      fi

      printf "%i: Unmounting \"%s\"...\\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE"

      check_working_dir_not_under_dir "$MOUNT_POINT"

      SUDO_UNMOUNT_CMD="sudo -- $UNMOUNT_CMD $CMD"

      echo "$SUDO_UNMOUNT_CMD"
      eval "$SUDO_UNMOUNT_CMD"

      # We do not need to delete the mount point directory after unmounting. However, if you are
      # experimenting with other mounting methods, like the sibling "-gvfs" script, you will
      # appreciate that this script cleans up after unmounting, because other scripts may attempt
      # to create links with the same names and fail if empty mount point directories are left behind.
      #
      # In any case, removing unused mount points normally reduces unwelcome clutter.
      #
      # We should remove more than the last directory component, see option '--parents' in the 'mkdir' invocation,
      # but we do not have the flexibility in this script yet to know where to stop.
      rmdir -- "$MOUNT_POINT"

    else
      printf "%i: Not mounted \"%s\".\\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE"
    fi
  fi
}


# According to the Linux kernel 3.16 documentation, /proc/mounts uses the same format as fstab,
# which should only escape spaces in the mount point (the second field, fs_file).
# However, another source in the Internet listed the following escaped characters:
# - space (\040)
# - tab (\011)
# - newline (\012)
# - backslash (\134)
# That makes sense, so I guess the fstab documentation is wrong.
# Note that command 'umount' works with the first field (fs_spec) in /etc/mtab, but it takes spaces
# instead of the escape sequence \040.
#
# The kernel documentation does not mention the fact either that the first field (fs_spec)
# gets escaped too, at least for CIFS (Windows shares) mount points.
#
# This routine unescapes all octal numeric values with the form "\" + 3 octal digits, not just the ones
# listed above. It is not clear from the fstab documentation how escaping sequences are generated.

unescape_path()
{
  local STILL_TO_PROCESS="$1"
  local RESULT=""

  # It is not easy to parse strings in bash. There is no "non-greedy" support for regular expressions.
  # You cannot replace several matches with the result of a function call on the matched text.
  # Going character-by-character is very slow in a shell script.
  # Bash can unescape a similar format with printf "%b", but it does not exactly match our escaping specification.

  local REGULAR_EXPRESSION="\\\\([0-7][0-7][0-7])(.*)"
  local UNESCAPED_CHAR
  local -i LEN_BEFORE_MATCH

  while [[ $STILL_TO_PROCESS =~ $REGULAR_EXPRESSION ]]; do
    if false; then
      echo "Matched: \"${BASH_REMATCH[1]}\", \"${BASH_REMATCH[2]}\""
    fi

    LEN_BEFORE_MATCH=$(( ${#STILL_TO_PROCESS} - 4 - ${#BASH_REMATCH[2]}))
    RESULT+="${STILL_TO_PROCESS:0:LEN_BEFORE_MATCH}"
    printf -v UNESCAPED_CHAR "%b" "\\0${BASH_REMATCH[1]}"
    RESULT+="$UNESCAPED_CHAR"
    STILL_TO_PROCESS=${BASH_REMATCH[2]}
  done

  RESULT+="$STILL_TO_PROCESS"

  UNESCAPED_PATH="$RESULT"
}


test_unescape_path ()
{
  unescape_path "Test\\0121"  # Tests an embedded new-line character.
  echo "\"$UNESCAPED_PATH\""

  unescape_path "Test\\1341"  # "Test\1"
  echo "\"$UNESCAPED_PATH\""

  unescape_path "Test\\0401"  # "Test 1"
  echo "\"$UNESCAPED_PATH\""

  unescape_path "\\040\\0401\\040\\0402\\040\\040"  # "  1  2  "
  echo "\"$UNESCAPED_PATH\""

  unescape_path "Test\\040äöüßÄÖÜñÑ\\0402"  # "Test äöüßÄÖÜñÑ 2"
  echo "\"$UNESCAPED_PATH\""

  unescape_path "Test040"  # "Test040"
  echo "\"$UNESCAPED_PATH\""
}

if false; then
  test_unescape_path
  abort "Finished testing."
fi


declare -A  DETECTED_MOUNT_POINTS  # Associative array.

read_proc_mounts ()
{
  # We are reading /proc/mounts because it is maintained by the kernel and has the most accurate information.
  # An alternative would be reading /etc/mtab, but that is maintained in user space by 'mount' and
  # may become out of sync.

  # Read the whole /proc/swaps file at once.
  local PROC_MOUNTS_FILENAME="/proc/mounts"
  local PROC_MOUNTS_CONTENTS
  PROC_MOUNTS_CONTENTS="$(<$PROC_MOUNTS_FILENAME)"

  # Split on newline characters.
  local PROC_MOUNTS_LINES
  mapfile -t PROC_MOUNTS_LINES <<< "$PROC_MOUNTS_CONTENTS"

  local PROC_MOUNTS_LINE_COUNT="${#PROC_MOUNTS_LINES[@]}"

  local LINE
  local PARTS
  local REMOTE_DIR
  local MOUNT_POINT

  for ((i=0; i<PROC_MOUNTS_LINE_COUNT; i+=1)); do
    LINE="${PROC_MOUNTS_LINES[$i]}"

    IFS=$' \t' read -r -a PARTS <<< "$LINE"

    REMOTE_DIR_ESCAPED="${PARTS[0]}"
    MOUNT_POINT_ESCAPED="${PARTS[1]}"

    unescape_path "$REMOTE_DIR_ESCAPED"
    REMOTE_DIR="$UNESCAPED_PATH"

    unescape_path "$MOUNT_POINT_ESCAPED"
    MOUNT_POINT="$UNESCAPED_PATH"

    DETECTED_MOUNT_POINTS["$MOUNT_POINT"]="$REMOTE_DIR"

  done

  if false; then
    echo "Contents of DETECTED_MOUNT_POINTS:"
    for key in "${!DETECTED_MOUNT_POINTS[@]}"; do
      printf -- "- %s=%s\\n" "$key" "${DETECTED_MOUNT_POINTS[$key]}"
    done
  fi
}


# ------- Entry point -------

if (( UID == 0 )); then
  # This script uses variable UID as a parameter to 'mount'. Maybe we could avoid using it,
  # if 'mount' can reliably infer the UID.
  abort "The user ID is zero, are you running this script as root?"
fi


ERR_MSG="Only one optional argument is allowed: 'mount' (the default), 'mount-no-open', 'unmount' / 'umount' or 'sudoers'."

if (( $# == 0 )); then

  MODE=mount
  AUTO_OPEN_ENABLED=true

elif (( $# == 1 )); then

  case "$1" in
    mount)         MODE=mount
                   AUTO_OPEN_ENABLED=true;;

    mount-no-open) MODE=mount
                   AUTO_OPEN_ENABLED=false;;

    unmount)  MODE=unmount;;
    umount)   MODE=unmount;;
    sudoers)  MODE=sudoers;;
    *) abort "Wrong argument \"$1\". $ERR_MSG";;
  esac

else
  abort "Invalid arguments. $ERR_MSG"
fi


# This script runs command "mount -t cifs", which gets mapped to the 'mount.cifs' tool.
# Unfortunately, this mapping is performed blindly. If 'mount.cifs' is not currently installed
# on the system, you get a generic error message about the 'cifs' type being invalid.
#
# There is a comment at the top of this script that talks about it, but you do not normally
# look at it when faced with a strange error message.
#
# Therefore, I have decided to explicitly check for the presence of 'mount.cifs'.
#

declare -r MOUNT_CIFS_TOOL="$MOUNT_CMD.cifs"

command -v "$MOUNT_CIFS_TOOL" >/dev/null 2>&1  ||  abort "Tool '$MOUNT_CIFS_TOOL' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu the associated package is called \"cifs-utils\"."


user_settings


declare -i MOUNT_ARRAY_ELEM_COUNT="${#MOUNT_ARRAY[@]}"
declare -i MOUNT_ENTRY_REMINDER="$(( MOUNT_ARRAY_ELEM_COUNT % MOUNT_ENTRY_ARRAY_ELEM_COUNT ))"

if (( MOUNT_ENTRY_REMINDER != 0 )); then
  abort "Invalid element count, array MOUNT_ARRAY is malformed."
fi

read_proc_mounts


# If we wanted, we could always prompt for the sudo password upfront as follows, but we may not need it after all.
#   sudo bash -c "echo \"This is just to request the root password if needed. sudo will cache it during the next minutes.\" >/dev/null"

if [[ $MODE == "sudoers" ]]; then
  echo
  echo "# The following entries were generated by script $SCRIPT_NAME:"
fi

for ((i=0; i<MOUNT_ARRAY_ELEM_COUNT; i+=MOUNT_ENTRY_ARRAY_ELEM_COUNT)); do

  MOUNT_ELEM_NUMBER="$((i/MOUNT_ENTRY_ARRAY_ELEM_COUNT+1))"
  WINDOWS_SHARE="${MOUNT_ARRAY[$i]}"
  MOUNT_POINT="${MOUNT_ARRAY[$((i+1))]}"
  MOUNT_OPTIONS="${MOUNT_ARRAY[$((i+2))]}"
  MOUNT_WINDOWS_DOMAIN="${MOUNT_ARRAY[$((i+3))]}"
  MOUNT_WINDOWS_USER="${MOUNT_ARRAY[$((i+4))]}"
  MOUNT_WINDOWS_PASSWORD="${MOUNT_ARRAY[$((i+5))]}"
  MOUNT_AUTO_OPEN="${MOUNT_ARRAY[$((i+6))]}"

  case "$MODE" in
     mount)   mount_elem "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT" "$MOUNT_OPTIONS" "$MOUNT_WINDOWS_DOMAIN" "$MOUNT_WINDOWS_USER" "$MOUNT_WINDOWS_PASSWORD" "$MOUNT_AUTO_OPEN" "$AUTO_OPEN_ENABLED";;
     unmount) unmount_elem "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT";;
     sudoers) mount_elem "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT" "$MOUNT_OPTIONS" "$MOUNT_WINDOWS_DOMAIN" "$MOUNT_WINDOWS_USER" "$MOUNT_WINDOWS_PASSWORD" "$MOUNT_AUTO_OPEN" false
              unmount_elem "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT";;
     *) abort "Internal error: Invalid mode \"$MODE\".";;
  esac

done

if [[ $MODE == "sudoers" ]]; then
  echo
fi
