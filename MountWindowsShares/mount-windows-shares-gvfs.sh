#!/bin/bash

# mount-windows-shares-gvfs.sh version 1.12
# Copyright (c) 2014-2023 R. Diez - Licensed under the GNU AGPLv3
#
# Warning: I had a number of problems mit GVfs years ago,
#          so I stopped using this script template for a while.
#          In August 2023 I modified this script to use the newer 'gio'
#          command instead, in the hope that such problems had been fixed
#          in the meantime. However, 'gio' remains full of quirks and limitations,
#          so I still do not recommend using GVfs.
#
# Mounting Windows shares under Linux can be a frustrating affair.
# At some point in time, I decided to write this script template
# to ease the pain.
#
# This script helps in the following scenario:
# - You need to mount a given set of Windows file shares every day.
# - You have just one Windows account for all of them.
# - You do not mind using a text console.
# - You wish to mount with FUSE / GVfs, so that you do NOT need the root password.
#   This script uses tool 'gio mount'.
# - You want your own symbolic link for every mount point, and not the unreadable
#   link that GVfs creates somewhere weird.
# - You do not want to store your root or Windows account password on the local
#   Linux PC. That means you want to enter the password every time, and the system
#   should forget it straight away.
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
#
# A more comfortable alternative would be to use a graphical tool like Gigolo, which can
# automatically mount your favourite shares on start-up. Gigolo uses the FUSE-based
# mount system too, which does not require the root password in order to mount Windows shares.
# Unfortunately, I could not get it to work reliably unter Ubuntu 14.04 as of Mai 2014.
#
# PREREQUISITES:
#
# - You have to install GVfs and FUSE support on your Linux OS beforehand. On Ubuntu/Debian,
#   installing packages 'gvfs-backends' and 'gvfs-fuse' should do the trick.
#   You can install them with the following command:
#     sudo apt-get install gvfs-backends gvfs-fuse
#
# - (No longer necessary from Ubuntu 15.10) Your user account must be a member of the "fuse" group.
#   You can do that with the following command:
#     sudo adduser "$USER" fuse
#
# CAVEATS:
#
# - This script uses tool 'gio', which was added to GNOME version 3.22.
#   For example, Ubuntu 16.04 does not have 'gio' yet, only the older version 'gvfs-mount',
#   but Ubuntu 22.04 does have 'gio'.
#
# - If you enter the wrong passsword, tool 'gio' will apparently prompt again, failing straight away.
#   This is what it looks like:
#     1: Mounting: //my-server/my-share
#     gio mount -- smb://MY-DOMAIN\;my-user@my-server/my-share
#     Authentication Required
#     Enter password for share "my-share" on "my-server":
#     Password:
#     Authentication Required
#     Enter password for share "my-share" on "my-server":
#     Password:
#
#   To avoid confusion, 'gio' should actually say that the first password you supplied was
#   wrong before prompting again. Or it should realise of the end-of-file condition and not prompt anymore.
#
# - GVfs seems moody. Sometimes, making a connection takes a long time without any explanation.
#   You will eventually get a timeout error message, but it is too long, it can take minutes.
#   Trying to access the mount points immediately after establishing the connection often
#   fails straight away with a generic "Input/output error".
#
#   On Kubuntu 14.04.1, I tend to get the following error message once per session, and then never again:
#     "Error mounting location: No such interface 'org.gtk.vfs.MountTracker' on object at path /org/gtk/vfs/mounttracker"
#
#   For more GVfs trouble, unresolved for years, see:
#   - Fuse prefix is not recognized for symlinked files during GFile object creation
#     https://gitlab.gnome.org/GNOME/gvfs/-/issues/283
#   - Add operations to support O_WRONLY and O_RDWR in fuse daemon
#     https://gitlab.gnome.org/GNOME/gvfs/-/issues/249
#
# - I could not connect to a Windows share with the german character "Eszett" (aka "scharfes S").
#   This character looks like the "beta" greek letter. I could not do it with tools 'gigolo' or
#   'smb4k' either, so something is probably wrong deep down in the system. I tested with Kubuntu 14.04
#   in Oct 2014, later with Xubuntu 16.04.2 LTS and gvfs-mount 1.28.2 in July 2017,
#   and again with Ubuntu MATE 22.04.3 with gio version 2.72.4.
#   Other international characters, like the German "a mit Umlaut" or the Spanish
#   "Latin Small Letter N with Tilde", do work fine.
#
# - If a GVfs mount goes away in the meantime, running this script with the "unmount" argument
#   will leave the corresponding symbolic link behind.
#   The script could just delete any such links by name, but that may be wrong, as they may be pointing
#   to somewhere else useful at the moment.
#   The best way would be to parse the link targets, and check out if they match the expected Windows share.
#   However, such a corner case was not worth the development effort. Patches are welcome!
#
# - I could not find a way to pass mount options like requesting encryption, or to set
#   a connection timeout per connection.
#
#   Note that settings in /etc/samba/smb.conf do have an effect on 'gio', so I guess 'gio'
#   is using Samba's libsmbclient.
#
#   I recommend turning on connection encryption in /etc/samba/smb.conf like this:
#
#     [global]
#     client smb encrypt = required
#
#   You would think that you need to use 'desired' instead of 'required'
#   if you still have legacy SMB 1 servers, which cannot encrypt, but it does not seem to be the case.
#
#   You may want to lower the connection timeout, at the cost of some extra network traffic.
#   The default connection timeout is too high, so that an unresponsive server may
#   free desktop applications like the file manager. For example:
#
#     [global]
#     socket options = SO_KEEPALIVE  TCP_KEEPIDLE=4  TCP_KEEPCNT=2  TCP_KEEPINTVL=2
#
#   It is not clear from the client side what SMB protocol version 'gio' uses, but you can check it
#   on the Windows side with this PowerShell command:
#
#     Get-SmbSession | Select-Object -Property *
#
#   Tool 'gio' version 2.72.4 which comes with Ubuntu 22.04 is able to use SMB version 3.1.1 .
#
#
# USEFUL COMMANDS FOR TROUBLESHOOTING PURPOSES:
#
# - Print details on all connections:
#   gio mount --list --detail
#
# - Disconnect all GVfs SMB mounts:
#   gio mount --unmount --unmount-scheme=smb
#
# - If you are having trouble unmounting a GVfs mount point because it is still in use,
#   command "lsof | grep smb-share:" might help. Tool "gio mount --unmount" does not seem
#   to have a "lazy unmount" option like 'umount' has, but maybe option '--force' does the trick.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


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
  #   Special password "prompt" means that the user will be prompted for the password.
  #
  #   SECURITY WARNING: If you choose not to prompt for the Windows password every time,
  #                     and you store the password below, anyone that can read this script
  #                     can also find out your password.
  #
  #   GVfs should be able to stores passwords in the GNOME keyring,
  #   but it does not seem like gio can use the keyring automatically.
  #   There is also the question about which keyring you are using (the KDE and GNOME
  #   desktop environments have different keyrings).
  #
  #
  # About the add_mount lines below:
  #
  #   Arguments to add_mount() are:
  #
  #   1) Windows server name (host name).
  #
  #   2) Name of the Windows share to mount.
  #      Note that mounting just a subdirectory beneath a Windows share is not supported.
  #      If you specify "Share1/subdir2/subdir3", gio will mount "Share1", and the script's logic will get confused.
  #
  #   3) Symbolic link to be created on the local host. The default GVfs mount point is some weird
  #      directory under GVFS_MOUNT_LIST_DIR (see below), so a link of your own will make it easier to find.
  #
  #   4) Mount options. At present, you must always pass option "rw".
  #
  #   5) Autopen option: "AutoOpen" or "NoAutoOpen" (case insensitive)
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

    add_mount "Server1" "ShareName1" "$HOME/WindowsShares/Server1ShareName1" "rw" "AutoOpen"
    add_mount "Server2" "ShareName2" "$HOME/WindowsShares/Server2ShareName2" "rw" "NoAutoOpen"


    # If you use more than one Windows account, you have to repeat everything above for each account. For example:

    WINDOWS_DOMAIN="MY_DOMAIN_2"
    WINDOWS_USER="MY_LOGIN_2"
    WINDOWS_PASSWORD="prompt"

    add_mount "Server3" "ShareName3" "$HOME/WindowsShares/Server3ShareName3" "rw" "NoAutoOpen"
    add_mount "Server4" "ShareName4" "$HOME/WindowsShares/Server4ShareName4" "rw" "NoAutoOpen"

  fi


  # The line below generates a reasonable error message but no ShellCheck warnings.
  #
  # This placeholder strategy makes it easy to synchronise changes: when this script template
  # is upgraded, the lines below should be the only thing the user has modified and needs to keep,
  # everything else around can be upgraded without worry.

  "---> Remove this line and specify your mounts here, for example by copying and modifying the examples above."
}


declare -r BOOLEAN_TRUE=0
declare -r BOOLEAN_FALSE=1

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r SPECIAL_PROMPT_WINDOWS_PASSWORD="prompt"

declare -r GVFS_MOUNT_TOOL="gio"


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit 1
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


str_is_equal_no_case ()
{
  local NOCASE1="${1^^}"
  local NOCASE2="${2^^}"

  if [[ $NOCASE1 == "$NOCASE2" ]]; then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


str_ends_with ()
{
  # $1 = string
  # $2 = suffix

  # From the bash manual, "Compound Commands" section, "[[ expression ]]" subsection:
  #   "Any part of the pattern may be quoted to force the quoted portion to be matched as a string."
  # Also, from the "Pattern Matching" section:
  #   "The special pattern characters must be quoted if they are to be matched literally."

  if [[ $1 == *"$2" ]]; then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
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


escape_str ()
{
  local STR="$1"

  local -i STRLEN="${#STR}"

  local ESCAPED=""

  local -i INDEX
  for (( INDEX = 0 ; INDEX < STRLEN ; ++INDEX )); do

    local CHAR="${STR:$INDEX:1}"

    if [[ $CHAR = "%" ]]; then
      local ESCAPED_CHAR
      printf -v ESCAPED_CHAR "%%%02x" "'$CHAR"
      ESCAPED+="$ESCAPED_CHAR"
    else
      ESCAPED+="$CHAR"
    fi

  done

  echo "$ESCAPED"
}


unescape_str ()
{
  local STR="$1"

  local -i STRLEN="${#STR}"

  local UNESCAPED=""

  local -i INDEX
  for (( INDEX = 0 ; INDEX < STRLEN ; )); do

   local CHAR="${STR:$INDEX:1}"

   if [[ $CHAR = "%" ]]; then
     if (( INDEX + 2 >= STRLEN )); then
       abort "Invalid escape sequence."
     fi

     # Skip the '%' character.
     INDEX=$(( INDEX + 1 ))

     local VALUE_STR="${STR:$INDEX:2}"

     # Skip the 2 hex digits.
     INDEX=$(( INDEX + 2 ))

     local DECODED_VAL
     printf -v DECODED_VAL "%d" "0x$VALUE_STR"

     if (( DECODED_VAL > 127 )); then
       abort "Error unescaping string: UTF-8 encoding not supported yet."
     fi

     local CHAR_VAL
     printf -v CHAR_VAL "%b" "\\x$VALUE_STR"

     UNESCAPED+="$CHAR_VAL"

   else

     UNESCAPED+="$CHAR"
     INDEX=$(( INDEX + 1 ))

   fi

  done

  echo "$UNESCAPED"
}


format_windows_share_path ()
{
  echo "//$1/$2"
}


build_uri ()
{
  printf "smb://%s;%s@%s/%s" "$(escape_str "$1")" "$(escape_str "$2")" "$(escape_str "$3")" "$(escape_str "$4")"
}


declare -A ALL_WINDOWS_PASSWORDS=()  # Associative array.

get_windows_password ()
{
  # We cannot let 'gio' ask for the Windows password, because it will not cache it like "sudo" does,
  # so the user would have to enter the password several times in a row.
  #
  # I tried activating GNOME's keyring and managing it with "seahorse", but I found it a pain and gave up.
  # You have to manually deal with default and non-default keyrings, and it was not reliable.
  #
  # We could use tool 'expect' in order to feed 'gio' the password, but that would break if
  # the prompt text changes (for example, if it gets localised).
  #
  # 'gio' offers no way to take a password, other than redirecting its stdin, which is what
  # this script does.
  #
  # The best solution would be to write a tool that uses the native GNOME GLIB GIO API. The trouble is,
  # writing and distributing a C++ program for that purpose is cumbersome, and it is not clear to me yet
  # whether Perl bindings exist and are always installed.

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


declare -a MOUNT_ARRAY=()

add_mount ()
{
  if (( $# != 5 )); then
    abort "Wrong number of arguments passed to add_mount()."
  fi


  # If you specify a network address with subdirectories like "Share1/subdir2/subdir3",
  # tool 'gio' as of version 2.72.4 will mount "Share1", and the script's logic will get confused.
  # Therefore, reject network address with subdirectories.
  # You would not normally use backslashes in a path in this script, but check for them too, just in case.
  if [[ "$2" == */* ]] || [[ "$2" == *\\* ]]; then
    abort "Network path \"$2\" contains subdirectories."
  fi


  # Do not allow a terminating slash. Otherwise, we'll have trouble comparing
  # the paths with the existing mounted shares.

  if str_ends_with "$2" "/"; then
    abort "Windows share paths must not end with a slash (/) character. The path was: $1"
  fi

  if str_ends_with "$3" "/"; then
    abort "Mount points must not end with a slash (/) character. The path was: $2"
  fi


  local MOUNT_AUTO_OPEN_LOWER_CASE="${5,,}"
  local AUTO_OPEN

  case "$MOUNT_AUTO_OPEN_LOWER_CASE" in
    autoopen)    AUTO_OPEN=true;;
    noautoopen)  AUTO_OPEN=false;;
    *) abort "Error: Invalid auto-open option \"$5\".";;
  esac


  MOUNT_ARRAY+=( "$1" "$2" "$3" "$4" "$WINDOWS_DOMAIN" "$WINDOWS_USER" "$WINDOWS_PASSWORD" "$AUTO_OPEN" )
}


mount_elem ()
{
  local MOUNT_ELEM_NUMBER="$1"
  local WINDOWS_SERVER="$2"
  local SHARE_NAME="$3"
  local MOUNT_POINT="$4"
  local MOUNT_OPTIONS="$5"
  local MOUNT_DOMAIN="$6"
  local MOUNT_USER="$7"
  local MOUNT_WINDOWS_PASSWORD="$8"

  local WINDOWS_SHARE_PATH
  WINDOWS_SHARE_PATH="$(format_windows_share_path "$WINDOWS_SERVER" "$SHARE_NAME")"

  if [[ $MOUNT_OPTIONS != "rw" ]]; then
    local ERR_MSG="Invalid options of \"$MOUNT_OPTIONS\" specified for windows share \"$WINDOWS_SHARE_PATH\"."
    ERR_MSG+=" There does not seem to be a way to specify mount options with tool '$GVFS_MOUNT_TOOL'."
    ERR_MSG+=" Therefore, this script only allows option \"rw\", which is what one is normally used to with the standard 'mount' tool."
    abort "$ERR_MSG"
  fi

  local -i FOUND_POS
  find_gvfs_mount_point "$WINDOWS_SERVER" "$SHARE_NAME" "$MOUNT_DOMAIN" "$MOUNT_USER"

  if (( FOUND_POS != -1 )); then

    printf "%i: Already mounted: %s\\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE_PATH"

  else

    printf "%i: Mounting: %s\\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE_PATH"

    # If the remote host is not reachable, 'gio' tends to output a very general error message
    # like "Failed to mount Windows share: Invalid argument", at least with gvfs-mount version 1.28.2
    # shipped with Xubuntu 16.04.
    # With 'gio' version 2.72.4, shipped with Ubuntu MATE 22.04.3, you get an "Authentication Required"
    # message, a password prompt, and then error message "Failed to mount Windows share: Invalid argument".
    #
    # Such behaviour is confusing.
    # In order to help troubleshoot mounting problems, the following option allows you to check
    # first whether the remote host is reachable.
    local METHOD_TO_CHECK_FIRST_IF_REACHABLE=net-lookup-and-ping

    case "$METHOD_TO_CHECK_FIRST_IF_REACHABLE" in
      none)  # Not doing any such check upfront is usually rather unhelpful.
             ;;

      ping)
          # ping is rather unreliable on my Xubuntu 16.04 at resolving the Windows hostname to an IP address.
          # You may have to avoid using 'ping' if the remote host is configured (for example, via the Windows firewall)
          # not to answer to ping requests, or if ping requests are often dropped in your network.
          # We are discarding ping's stdout because it is too verbose. Fortunately, 'ping' writes its
          # error messages to stderr.
          ping  -c 1  -W 1 -- "$WINDOWS_SERVER" >/dev/null || abort "Host \"$WINDOWS_SERVER\" is not reachable with \"ping\".";;

      net-lookup)
          # This method does not check whether the remote host is actually reachable, but it is better than nothing.
          # We could skip this check if the user supplied an IP address, instead of a hostname.
          net lookup host "$WINDOWS_SERVER" >/dev/null;;

      net-lookup-and-ping)
          # We could skip the "net lookup host" step if the user supplied an IP address, instead of a hostname.
          local IP_ADDR
          # Tool 'net' version 4.15.13-Ubuntu, shipped with Ubuntu MATE 22.04.3,
          # appends a spurious "#20" to the error message, like this:
          #   Didn't find MY-SERVER#20
          # We could generate a better error message here, or at least prefix it with the right server name.
          IP_ADDR="$(net lookup host "$WINDOWS_SERVER")"
          ping  -c 1  -W 1 -- "$IP_ADDR" >/dev/null || abort "Host \"$WINDOWS_SERVER\" ($IP_ADDR) is not reachable with \"ping\".";;
    esac


    get_windows_password "$MOUNT_DOMAIN" "$MOUNT_USER" "$MOUNT_WINDOWS_PASSWORD"


    local URI
    URI="$(build_uri "$MOUNT_DOMAIN" "$MOUNT_USER" "$WINDOWS_SERVER" "$SHARE_NAME")"

    local CMD
    printf -v CMD  "%q mount -- %q"  "$GVFS_MOUNT_TOOL"  "$URI"

    if true; then
      echo "$CMD"
    fi

    # Capture the whole interaction with 'gio' into a variable, and do not show the output initially. Otherwise,
    # the password prompt that gets automatically answered with the stdin pipe would confuse the user.
    # If the command fails, then show the whole interaction, however confusing. If we only showed stderr, it is harder
    # for the user to find out what went wrong.
    CMD+=" 2>&1 <<<\"$RETRIEVED_WINDOWS_PASSWORD\""

    local CMD_OUTPUT
    local CMD_EXIT_CODE

    set +o errexit
    CMD_OUTPUT="$(eval "$CMD")"
    CMD_EXIT_CODE="$?"
    set -o errexit

    if (( CMD_EXIT_CODE != 0 )); then
      echo "$CMD_OUTPUT" >&2
      abort "Command \"$GVFS_MOUNT_TOOL\" failed with exit code $CMD_EXIT_CODE."
    fi
  fi
}


# This routine exists just to generate a better error message if 'readlink' fails,
# and to check that the returned path is not empty.

get_link_target ()
{
  set +o errexit

  # It looks like readlink's flag '--canonicalize'" makes it actually try to access the remote server.
  # I have removed that flag, because we do not actually need the absolute, canonical path here.
  # This way, readlink should always succeed, even if the remote server is not accessible yet.

  EXISTING_LINK_TARGET="$(readlink --verbose -- "$1")"

  local EXIT_CODE="$?"

  set -o errexit

  if (( EXIT_CODE != 0 )); then
    abort "Cannot read the target for symbolic link \"$1\", readlink failed with exit code $EXIT_CODE."
  fi

  if [[ $EXISTING_LINK_TARGET = "" ]]; then
    abort "Cannot read the target for symbolic link \"$1\", readlink returned an empty string for that symlink."
  fi
}


create_link ()
{
  local MOUNT_ELEM_NUMBER="$1"
  local WINDOWS_SERVER="$2"
  local SHARE_NAME="$3"
  local MOUNT_POINT="$4"
  local MOUNT_DOMAIN="$5"
  local MOUNT_USER="$6"

  local WINDOWS_SHARE_PATH
  WINDOWS_SHARE_PATH="$(format_windows_share_path "$WINDOWS_SERVER" "$SHARE_NAME")"

  local -i FOUND_POS
  find_gvfs_mount_point "$WINDOWS_SERVER" "$SHARE_NAME" "$MOUNT_DOMAIN" "$MOUNT_USER"

  if (( FOUND_POS == -1 )); then
    abort "$(printf "The directory entry for share \"%s\" was not found in GVfs mount directory \"$GVFS_MOUNT_LIST_DIR\". Check out the PREREQUISITES section in this script for more information." "$WINDOWS_SHARE_PATH")"
  fi

  local NEW_LINK_TARGET="$GVFS_MOUNT_LIST_DIR/${DETECTED_MOUNT_POINTS[$FOUND_POS]}"

  if [ -h "$MOUNT_POINT" ]; then

    # The file exists and is a symbolic link.

    local EXISTING_LINK_TARGET
    get_link_target "$MOUNT_POINT"

    if [[ $EXISTING_LINK_TARGET == "$NEW_LINK_TARGET" ]]; then
      printf "%i: Symlink already existed: \"%s\" -> \"%s\"\\n" "$MOUNT_ELEM_NUMBER" "$MOUNT_POINT" "$WINDOWS_SHARE_PATH"
    else
      printf "%i: Rewriting symlink: \"%s\" -> \"%s\"\\n" "$MOUNT_ELEM_NUMBER" "$MOUNT_POINT" "$WINDOWS_SHARE_PATH"
      rm -- "$MOUNT_POINT"
      ln --symbolic -- "$NEW_LINK_TARGET" "$MOUNT_POINT"
    fi

  elif [ -e "$MOUNT_POINT" ]; then

    abort "Error creating symbolic link for share \"$WINDOWS_SHARE_PATH\": File \"$MOUNT_POINT\" exists but is not a symbolic link. I am not sure whether I should delete it."

  else

    printf "%i: Creating symlink \"%s\" -> \"%s\"\\n" "$MOUNT_ELEM_NUMBER" "$MOUNT_POINT" "$WINDOWS_SHARE_PATH"
    mkdir --parents -- "$(dirname "$MOUNT_POINT")"
    ln --symbolic -- "$NEW_LINK_TARGET" "$MOUNT_POINT"

  fi
}


unmount_elem ()
{
  local MOUNT_ELEM_NUMBER="$1"
  local WINDOWS_SERVER="$2"
  local SHARE_NAME="$3"
  local MOUNT_POINT="$4"
  local MOUNT_DOMAIN="$5"
  local MOUNT_USER="$6"

  local WINDOWS_SHARE_PATH
  WINDOWS_SHARE_PATH="$(format_windows_share_path "$WINDOWS_SERVER" "$SHARE_NAME")"

  local -i FOUND_POS
  find_gvfs_mount_point "$WINDOWS_SERVER" "$SHARE_NAME" "$MOUNT_DOMAIN" "$MOUNT_USER"

  if (( FOUND_POS == -1 )); then

    printf "%i: Not mounted \"%s\".\\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE_PATH"

    # Note that, if a dangling symbolic link for this share exists, it is left behind.
    # See the CAVEATS section above for more information.

  else

    local HAS_PRINTED_INDEX=false

    if [ -h "$MOUNT_POINT" ]; then

      # The file exists and is a symbolic link.

      local EXPECTED_LINK_TARGET="$GVFS_MOUNT_LIST_DIR/${DETECTED_MOUNT_POINTS[$FOUND_POS]}"

      local EXISTING_LINK_TARGET
      get_link_target "$MOUNT_POINT"

      if [[ $EXISTING_LINK_TARGET == "$EXPECTED_LINK_TARGET" ]]; then
        printf "%i: Deleting symbolic link \"%s\" -> \"%s\"...\\n" "$MOUNT_ELEM_NUMBER" "$MOUNT_POINT" "$WINDOWS_SHARE_PATH"
        HAS_PRINTED_INDEX=true
        rm -- "$MOUNT_POINT"
      else
        abort "Error deleting symbolic link for share \"$WINDOWS_SHARE_PATH\": Symlink \"$MOUNT_POINT\" is pointing to an unexpected location. I am not sure whether I should delete it."
      fi

    elif [ -e "$MOUNT_POINT" ]; then

      # The file exists.
      abort "Error deleting symbolic link for share \"$WINDOWS_SHARE_PATH\": File \"$MOUNT_POINT\" exists but is not a symbolic link."

    else
      printf "%i: Symbolic link did not exist: %s\\n" "$MOUNT_ELEM_NUMBER" "$MOUNT_POINT"
      HAS_PRINTED_INDEX=true
    fi

    if $HAS_PRINTED_INDEX; then
      local INDEX_PREFIX=""
    else
      local INDEX_PREFIX
      printf -v INDEX_PREFIX  "%i: "  "$MOUNT_ELEM_NUMBER"
    fi

    printf "%sUnmounting \"%s\"...\\n" "$INDEX_PREFIX" "$WINDOWS_SHARE_PATH"

    local URI
    URI="$(build_uri "$MOUNT_DOMAIN" "$MOUNT_USER" "$WINDOWS_SERVER" "$SHARE_NAME")"

    local CMD
    printf -v CMD \
           "%q mount --unmount -- %q" \
           "$GVFS_MOUNT_TOOL" \
           "$URI"

    if true; then
      echo "$CMD"
    fi

    eval "$CMD"

  fi
}


process_name_value_pair ()
{
  local NAME="$1"
  local VALUE="$2"

  UNESCAPED_VALUE="$(unescape_str "$VALUE")"

  if false; then
    echo "VALUE: $VALUE"
    echo "UNESCAPED_VALUE: $UNESCAPED_VALUE"
  fi

  case "$NAME" in
    domain)  PARSED_DOMAIN="$UNESCAPED_VALUE";;
    server)  PARSED_SERVER="$UNESCAPED_VALUE";;
    share)   PARSED_SHARE="$UNESCAPED_VALUE";;
    user)    PARSED_USER="$UNESCAPED_VALUE";;
    *)  abort "Error parsing a GVfs directory entry: Unknown component name of \"$NAME\". This script probably needs updating.";;
  esac
}


parse_gvfs_component_string ()
{
  local COMPONENT_LIST_STR="$1"

  # Split on commas. I could not find any documentation about the .gvfs directory entries,
  # so I hope that any commas that might appear in any of the components get escaped.
  # Alternative split implementations: Bash 4 has 'readarray', or you could also use IFS together with "read -a".
  local COMPONENT_LIST
  IFS="," read -r -a COMPONENT_LIST <<< "$COMPONENT_LIST_STR"

  local COMPONENT_COUNT="${#COMPONENT_LIST[@]}"

  if false; then
    echo "COMPONENT_LIST_STR: $COMPONENT_LIST_STR"
    echo "COMPONENT_LIST with $COMPONENT_COUNT elements:"
    printf -- "- %s\\n" "${COMPONENT_LIST[@]}"
  fi

  local PARSED_DOMAIN=""
  local PARSED_SERVER=""
  local PARSED_SHARE=""
  local PARSED_USER=""

  local i
  for ((i=0; i<COMPONENT_COUNT; i+=1)); do
    local COMPONENT_STR="${COMPONENT_LIST[$i]}"

    local NAME="${COMPONENT_STR%%=*}"
    local VALUE="${COMPONENT_STR#*=}"

    if false; then
      echo "NAME: $NAME"
      echo "VALUE: $VALUE"
    fi

    process_name_value_pair "$NAME" "$VALUE"
  done

  if false; then
    echo "PARSED_SHARE: $PARSED_SHARE"
  fi

  DETECTED_MOUNT_POINT_DOMAINS+=( "$PARSED_DOMAIN" )
  DETECTED_MOUNT_POINT_SERVERS+=( "$PARSED_SERVER" )
  DETECTED_MOUNT_POINT_SHARES+=( "$PARSED_SHARE" )
  DETECTED_MOUNT_POINT_USERS+=( "$PARSED_USER" )
}


read_gvfs_mounts ()
{
  declare -ag DETECTED_MOUNT_POINTS=()
  declare -ag DETECTED_MOUNT_POINT_DOMAINS=()
  declare -ag DETECTED_MOUNT_POINT_SERVERS=()
  declare -ag DETECTED_MOUNT_POINT_SHARES=()
  declare -ag DETECTED_MOUNT_POINT_USERS=()

  if ! [ -e "$GVFS_MOUNT_LIST_DIR" ]; then
    return
  fi

  pushd "$GVFS_MOUNT_LIST_DIR" >/dev/null

  local PREFIX="smb-share:"
  local -i PREFIX_LEN="${#PREFIX}"

  shopt -s nullglob

  local FILENAME
  for FILENAME in *; do

    if ! str_starts_with "$FILENAME" "$PREFIX"; then
      continue
    fi

    DETECTED_MOUNT_POINTS+=( "$FILENAME" )

    local FILENAME_WITHOUT_PREFIX="${FILENAME:$PREFIX_LEN}"

    parse_gvfs_component_string "$FILENAME_WITHOUT_PREFIX"

  done

  popd >/dev/null

  # Print the list of detected GVfs mount points for debugging purposes.
  if false; then

    local DETECTED_MOUNT_POINT_COUNT="${#DETECTED_MOUNT_POINT_DOMAINS[@]}"

    echo
    echo "Detected GVfs mount points under directory: $GVFS_MOUNT_LIST_DIR"

    if (( DETECTED_MOUNT_POINT_COUNT == 0 )); then
      echo "(none)"
    else
      local i
      for ((i=0; i<DETECTED_MOUNT_POINT_COUNT; i+=1)); do
        local DETECTED_DOMAIN="${DETECTED_MOUNT_POINT_DOMAINS[$i]}"
        local DETECTED_SERVER="${DETECTED_MOUNT_POINT_SERVERS[$i]}"
        local DETECTED_SHARE="${DETECTED_MOUNT_POINT_SHARES[$i]}"
        local DETECTED_USER="${DETECTED_MOUNT_POINT_USERS[$i]}"

        printf "%s  as user %s\\n" \
               "//$DETECTED_DOMAIN/$DETECTED_SERVER/$DETECTED_SHARE" \
               "$DETECTED_USER"
      done
    fi

    echo

  fi
}


find_gvfs_mount_point ()
{
  local SERVER_NAME="$1"
  local SHARE_NAME="$2"
  local MOUNT_DOMAIN="$3"
  local MOUNT_USER="$4"

  local DETECTED_MOUNT_POINT_COUNT="${#DETECTED_MOUNT_POINT_DOMAINS[@]}"

  local i
  for ((i=0; i<DETECTED_MOUNT_POINT_COUNT; i+=1)); do
    local DETECTED_DOMAIN="${DETECTED_MOUNT_POINT_DOMAINS[$i]}"
    local DETECTED_SERVER="${DETECTED_MOUNT_POINT_SERVERS[$i]}"
    local DETECTED_SHARE="${DETECTED_MOUNT_POINT_SHARES[$i]}"
    local DETECTED_USER="${DETECTED_MOUNT_POINT_USERS[$i]}"

    if ! str_is_equal_no_case "$DETECTED_DOMAIN" "$MOUNT_DOMAIN"; then
      continue
    fi

    if ! str_is_equal_no_case "$DETECTED_SERVER" "$SERVER_NAME"; then
      continue
    fi

    if ! str_is_equal_no_case "$DETECTED_SHARE" "$SHARE_NAME"; then
      continue
    fi

    if ! str_is_equal_no_case "$DETECTED_USER" "$MOUNT_USER"; then
      local WINDOWS_SHARE_PATH
      WINDOWS_SHARE_PATH="$(format_windows_share_path "$WINDOWS_SERVER" "$SHARE_NAME")"

      abort "Windows share \"$WINDOWS_SHARE_PATH\" is mounted with user name \"$DETECTED_USER\", instead of the expected user name of \"$MOUNT_USER\"."
    fi

    FOUND_POS="$i"
    return
  done

  FOUND_POS="-1"
}


# ------- Entry point -------

if (( UID == 0 )); then
  # This script uses variable UID to locate the GVfs mount point.
  # You shoud not run this script as root anyway, as FUSE is designed
  # to allow normal users to mount filesystems.
  abort "The user ID is zero, are you running this script as root? You probably should not."
fi

ERR_MSG="Only one optional argument is allowed: 'mount' (the default), 'mount-no-open' or 'unmount' / 'umount'."

if (( $# == 0 )); then

  SHOULD_MOUNT=true
  AUTO_OPEN_ENABLED=true

elif (( $# == 1 )); then

  if [[ $1 = "mount" ]]; then
    SHOULD_MOUNT=true
    AUTO_OPEN_ENABLED=true
  elif [[ $1 = "mount-no-open" ]]; then
    SHOULD_MOUNT=true
    AUTO_OPEN_ENABLED=false
  elif [[ $1 = "unmount" ]]; then
    SHOULD_MOUNT=false
  elif [[ $1 = "umount" ]]; then
    SHOULD_MOUNT=false
  else
    abort "Wrong argument \"$1\". $ERR_MSG"
  fi
else
  abort "Invalid arguments. $ERR_MSG"
fi


user_settings


if ! is_var_set "XDG_RUNTIME_DIR"; then
  abort "Environment variable XDG_RUNTIME_DIR is not set."
fi

# This is where your system creates the GVfs directory entries with the mount point information:
declare -r GVFS_MOUNT_LIST_DIR="$XDG_RUNTIME_DIR/gvfs"
# Known locations are:
#   /run/user/$UID/gvfs   # For Ubuntu from version 16.04, including 22.04.
#   /run/user/$USER/gvfs  # For Ubuntu versions 12.10, 13.04 and 13.10.
#   $HOME/.gvfs           # For Ubuntu 12.04 and older.

if false; then
  echo "GVfs mount directory: $GVFS_MOUNT_LIST_DIR"
fi


declare -i MOUNT_ARRAY_ELEM_COUNT="${#MOUNT_ARRAY[@]}"
declare -i MOUNT_ENTRY_ARRAY_ELEM_COUNT=8
declare -i MOUNT_ENTRY_REMINDER="$(( MOUNT_ARRAY_ELEM_COUNT % MOUNT_ENTRY_ARRAY_ELEM_COUNT ))"

if [ $MOUNT_ENTRY_REMINDER -ne 0  ]; then
  abort "Invalid element count, array MOUNT_ARRAY is malformed."
fi

if ! type "$GVFS_MOUNT_TOOL" >/dev/null 2>&1 ;
then
  abort "Tool \"$GVFS_MOUNT_TOOL\" is not installed on this system. Check out the PREREQUISITES section in this script for more information."
fi

if ! [ -d "$GVFS_MOUNT_LIST_DIR" ]; then
  # I am not sure whether the 'gvfs' directory always gets automatically created on start-up.
  :

  # MSG="The GVfs mount directory \"$GVFS_MOUNT_LIST_DIR\" does not exist."
  # MSG+=" Either it is somewhere else on your system, in which case you have to edit this script,"
  # MSG+=" or the \"POSIX compatibility layer for GVfs\" is not installed (its Debian package name is 'gvfs-fuse')."
  # abort "$MSG"
fi

read_gvfs_mounts

if false; then
  if $SHOULD_MOUNT; then
    echo "Mounting..."
  else
    echo "Unmounting..."
  fi
fi

for ((i=0; i<MOUNT_ARRAY_ELEM_COUNT; i+=MOUNT_ENTRY_ARRAY_ELEM_COUNT)); do

  MOUNT_ELEM_NUMBER="$((i/MOUNT_ENTRY_ARRAY_ELEM_COUNT+1))"
  WINDOWS_SERVER="${MOUNT_ARRAY[$i]}"
  SHARE_NAME="${MOUNT_ARRAY[$((i+1))]}"
  MOUNT_POINT="${MOUNT_ARRAY[$((i+2))]}"
  MOUNT_OPTIONS="${MOUNT_ARRAY[$((i+3))]}"
  MOUNT_DOMAIN="${MOUNT_ARRAY[$((i+4))]}"
  MOUNT_USER="${MOUNT_ARRAY[$((i+5))]}"
  MOUNT_PASSWORD="${MOUNT_ARRAY[$((i+6))]}"

  if $SHOULD_MOUNT; then
    mount_elem "$MOUNT_ELEM_NUMBER" "$WINDOWS_SERVER" "$SHARE_NAME" "$MOUNT_POINT" "$MOUNT_OPTIONS" "$MOUNT_DOMAIN" "$MOUNT_USER" "$MOUNT_PASSWORD"
  else
    unmount_elem "$MOUNT_ELEM_NUMBER" "$WINDOWS_SERVER" "$SHARE_NAME" "$MOUNT_POINT" "$MOUNT_DOMAIN" "$MOUNT_USER"
  fi

done

if $SHOULD_MOUNT; then

  # When mounting, the symbolic links are created all together at the end.
  # The reason is that we need to re-read the list of mount points, see below.

  echo
  if false; then
    echo "Creating symbolic links..."
  fi

  # We need to re-read the list of mount points, because we do not know the directory
  # names which GVfs has just created for the new mounts.
  read_gvfs_mounts

  for ((i=0; i<MOUNT_ARRAY_ELEM_COUNT; i+=MOUNT_ENTRY_ARRAY_ELEM_COUNT)); do

    MOUNT_ELEM_NUMBER="$((i/MOUNT_ENTRY_ARRAY_ELEM_COUNT+1))"
    WINDOWS_SERVER="${MOUNT_ARRAY[$i]}"
    SHARE_NAME="${MOUNT_ARRAY[$((i+1))]}"
    MOUNT_POINT="${MOUNT_ARRAY[$((i+2))]}"
    MOUNT_DOMAIN="${MOUNT_ARRAY[$((i+4))]}"
    MOUNT_USER="${MOUNT_ARRAY[$((i+5))]}"

    create_link "$MOUNT_ELEM_NUMBER" "$WINDOWS_SERVER" "$SHARE_NAME" "$MOUNT_POINT" "$MOUNT_DOMAIN" "$MOUNT_USER"
  done

  if $AUTO_OPEN_ENABLED; then

    for ((i=0; i<MOUNT_ARRAY_ELEM_COUNT; i+=MOUNT_ENTRY_ARRAY_ELEM_COUNT)); do

      MOUNT_POINT="${MOUNT_ARRAY[$((i+2))]}"
      MOUNT_AUTO_OPEN="${MOUNT_ARRAY[$((i+7))]}"

      if $MOUNT_AUTO_OPEN; then

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

    done

  fi

fi

if false; then
  if $SHOULD_MOUNT; then
    echo "Finished mounting and creating symbolic links."
  else
    echo "Finished unmounting."
  fi
fi
