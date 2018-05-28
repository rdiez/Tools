#!/bin/bash

# mount-windows-shares-gvfs.sh version 1.08
# Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3
#
# Mounting Windows shares under Linux can be a frustrating affair.
# At some point in time, I decided to write this script template
# to ease the pain.
#
# This script helps in the following scenario:
# - You need to mount a given set of Windows file shares every day.
# - You have just one Windows account for all of them.
# - You do not mind using a text console.
# - You wish to mount with FUSE / GVFS, so that you do NOT need the root password.
#   This script uses tool 'gvfs-mount'.
# - You want your own symbolic link for every mountpoint, and not the unreadable
#   link that GVFS creates somewhere weird.
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
# With no arguments, or with argument 'mount', this script mounts all shares it knows about.
# Specify argument "umount" or "unmount" in order to unmount all shares.
#
# If you are having trouble unmounting a GVFS mountpoint because it is still in use,
# command "lsof | grep ^gvfs" might help. Tool "gvfs-mount --unmount" does not seem
# to have a "lazy unmount" option like 'umount' has, but maybe "--force" does the trick.
# You can unmount all GVFS SMB shares at once with the following command:
#   gvfs-mount --unmount-scheme=smb
#
# You'll have to edit this script in order to add your particular Windows shares.
# However, the only thing you will probably ever need to change
# is routine user_settings() below.
#
# A better alternative would be to use a graphical tool like Gigolo, which can
# automatically mount your favourite shares on start-up. Gigolo uses the FUSE-based
# mount system too, which does not require the root password in order to mount Windows shares.
# Unfortunately, I could not get it to work reliably unter Ubuntu 14.04 as of Mai 2014.
#
# PREREQUISITES:
#
# - You have to install GVFS and FUSE support on your Linux OS beforehand. On Debian, the packages
#   are called "gvfs-bin", "gvfs-backends" and "gvfs-fuse". You can install them with the
#   following command:
#     sudo apt-get install gvfs-bin gvfs-backends gvfs-fuse
#
# - (No longer necessary from Ubuntu 15.10) Your user account must be a member of the "fuse" group.
#   You can do that with the following command:
#     sudo adduser "$USER" fuse
#
# CAVEATS:
#
# - This script uses 'gvfs-mount', which has been deprecated in favour of a new 'gio' tool. The gio
#   tool was added in GNOME 3.22, and gvfs-mount was turned into a shell script that redirects to gio
#   in GNOME 3.24. Ubuntu 16.04 LTS does not have gio yet.
#
# - If you type the wrong password, tool 'gvfs-mount' will enter an infinite loop (as of Kubuntu 14.04 in Oct 2014,
#   gvfs version 1.20.1). As a result, this script will appear to hang.
#   The reason is that gvfs-mount does not realise when the stdin file descriptor reaches the end of file,
#   which is the case as this scripts redirects stdin in order to feed it with the password.
#   The only way out is to press Ctrl+C to interrupt the script together with all its child processes.
#   I reported this issue (see bug 742942 in https://bugzilla.gnome.org/) and it has been fixed for version 1.23).
#
#   The version that comes with Ubuntu 16.04 does have this fix. The only issue left is that no error message
#   is generated when gvfs-mount exits in this way. This is what the interaction looks like:
#     Mounting...
#     1: Mounting: //my-server/my-share
#     gvfs-mount -- smb://MY-DOMAIN\;my-user@my-server/my-share
#     Password required for share my-share on my-server
#     Password:
#     Password required for share my-share on my-server
#     Password:
#   The second password prompt hits then end-of-file on stdin. To avoid confusion, gvfs-mount should actually say
#   that the first password you supplied was wrong before prompting again. And it should print some error message
#   too about exiting because of an end-of-file condition.
#
# - GVFS seems moody. Sometimes, making a connection takes a long time without any explanation.
#   You will eventually get a timeout error message, but it is too long, it can take minutes.
#   Trying to access the mountpoints immediately after establishing the connection often
#   fails straight away with a generic "Input/output error".
#
#   On Kubuntu 14.04.1, I tend to get the following error message once per session, and then never again:
#     "Error mounting location: No such interface 'org.gtk.vfs.MountTracker' on object at path /org/gtk/vfs/mounttracker"
#
# - I could not connect to a Windows share with the german character "Eszett" (aka "scharfes S").
#   This character looks like the "beta" greek letter. I could not do it with tools 'gigolo' or
#   'smb4k' either, so something is probably wrong deep down in the system. I tested with Kubuntu 14.04
#   in Oct 2014, and again with Xubuntu 16.04.2 LTS and gvfs-mount 1.28.2 in July 2017.
#   Other international characters, like the German "a mit Umlaut", do work fine.
#
# - If a GVFS mount goes away in the meantime, running this script with the "unmount" argument
#   will leave the corresponding symbolic link behind.
#   The script could just delete any such links by name, but that may be wrong, as they may be pointing
#   to somewhere else useful at the moment.
#   The best way would be to parse the link targets, and check out if they match the expected Windows share.
#   However, such a corner case was not worth the development effort. Patches are welcome!

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


user_settings ()
{
  # Specify here your Windows account details.

  WINDOWS_DOMAIN="MY_DOMAIN"  # If there is no Windows Domain, this would be the Windows computer name (hostname).
                              # Apparently, the workgroup name works too. In fact, I do not think this name
                              # matters at all if there is no domain. It is best to use the computer name,
                              # especially if you are connecting to different computers, as the password prompt
                              # will then provide a hint about which computer the password is for.
  WINDOWS_USER="MY_LOGIN"

  # If you do not want to be prompted for your Windows password every time,
  # you will have to store your password in variable WINDOWS_PASSWORD below.
  # SECURITY WARNING: If you choose not to prompt for the Windows password every time,
  #                   and you store the password below, anyone that can read this script
  #                   can also find out your password.
  # Special password "prompt" means that the user will be prompted for the password.
  #
  # gvfs-mount is actually designed to retrieve the password automatically from the keyring,
  # but I do not know whether gvfs-mount can add passwords to the keyring automatically.
  # There is also the question about which keyring you are using (the KDE and GNOME
  # desktop environments have different keyrings).

  WINDOWS_PASSWORD="prompt"


  # Specify here the network shares to mount or unmount.
  #
  # Arguments to add_mount() are:
  # 1) Windows server name (host name).
  # 2) Name of the Windows share to mount.
  #    Note that mounting just a subdirectory beneath a Windows share is not supported.
  # 3) Symbolic link to be created on the local host. The default GVFS mountpoint is some weird
  #    directory under GVFS_MOUNT_LIST_DIR (see below), so a link of your own will make it easier to find.
  # 4) Options. At present, you must always pass option "rw".

  # Subdirectory "WindowsShares" below must already exist.
  add_mount "Server1" "ShareName1" "$HOME/WindowsShares/Server1ShareName1" "rw"
  add_mount "Server2" "ShareName2" "$HOME/WindowsShares/Server2ShareName2" "rw"


  # If you use more than one Windows account, you have to repeat everything above for each account. For example:
  #
  #  WINDOWS_DOMAIN="MY_DOMAIN_2"
  #  WINDOWS_USER="MY_LOGIN_2"
  #  WINDOWS_PASSWORD="prompt"
  #
  # add_mount "Server3" "ShareName3" "$HOME/WindowsShares/Server3ShareName3" "rw"
  # add_mount "Server4" "ShareName4" "$HOME/WindowsShares/Server4ShareName4" "rw"


  # This is where your system creates the GVFS directory entries with the mountpoint information:
  GVFS_MOUNT_LIST_DIR="/run/user/$UID/gvfs"
  # Other possible locations are:
  #   GVFS_MOUNT_LIST_DIR="/run/user/$USER/gvfs"  # For Ubuntu versions 12.10, 13.04 and 13.10.
  #   GVFS_MOUNT_LIST_DIR="$HOME/.gvfs"  # For Ubuntu 12.04 and older.
}


BOOLEAN_TRUE=0
BOOLEAN_FALSE=1

SPECIAL_PROMPT_WINDOWS_PASSWORD="prompt"

GVFS_MOUNT_TOOL="gvfs-mount"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
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
  # We cannot let gvfs-mount ask for the Windows password, because it will not cache it like "sudo" does,
  # so the user would have to enter the password several times in a row.
  #
  # I tried activating GNOME's keyring and managing it with "seahorse", but I found it a pain and gave up.
  # You have to manually deal with default and non-default keyrings, and it was not reliable.
  #
  # We could use tool 'expect' in order to feed gvfs-mount the password, but that would break if
  # the prompt text changes (for example, if it gets localised).
  #
  # gvfs-mount offers no way to take a password, other than redirecting its stdin, which is what
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
  printf "If mounting takes too long, you might have typed the wrong password (a buggy \"%s\" will make this script hang)...\\n"  "$GVFS_MOUNT_TOOL"

  ALL_WINDOWS_PASSWORDS["$KEY"]="$RETRIEVED_WINDOWS_PASSWORD"
}


declare -a MOUNT_ARRAY=()

add_mount ()
{
  if [ $# -ne 4 ]; then
    abort "Wrong number of arguments passed to add_mount()."
  fi

  # Do not allow a terminating slash. Otherwise, we'll have trouble comparing
  # the paths with the existing mounted shares.

  if str_ends_with "$2" "/"; then
    abort "Windows share paths must not end with a slash (/) character. The path was: $1"
  fi

  if str_ends_with "$3" "/"; then
    abort "Mountpoints must not end with a slash (/) character. The path was: $2"
  fi

  MOUNT_ARRAY+=( "$1" "$2" "$3" "$4" "$WINDOWS_DOMAIN" "$WINDOWS_USER" "$WINDOWS_PASSWORD")
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


    # If the remote host is not reachable, gvfs-mount tends to output a very general error message
    # like "Failed to mount Windows share: Invalid argument", at least with gvfs-mount version 1.28.2
    # shipped with Xubuntu 16.04.
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
          IP_ADDR="$(net lookup host "$WINDOWS_SERVER")"
          ping  -c 1  -W 1 -- "$IP_ADDR" >/dev/null || abort "Host \"$WINDOWS_SERVER\" ($IP_ADDR) is not reachable with \"ping\".";;
    esac


    get_windows_password "$MOUNT_DOMAIN" "$MOUNT_USER" "$MOUNT_WINDOWS_PASSWORD"


    local URI
    URI="$(build_uri "$MOUNT_DOMAIN" "$MOUNT_USER" "$WINDOWS_SERVER" "$SHARE_NAME")"

    local CMD
    printf -v CMD  "%q -- %q"  "$GVFS_MOUNT_TOOL"  "$URI"

    if true; then
      echo "$CMD"
    fi

    # Capture the whole interaction with gvfs-mount into a variable, and do not show the output initially. Otherwise,
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

    if [ $CMD_EXIT_CODE -ne 0 ]; then
      echo "$CMD_OUTPUT" >&2
      abort "Command \"$GVFS_MOUNT_TOOL\" failed with exit code $CMD_EXIT_CODE."
    fi
  fi
}


# This routine exists because sometimes I have seen "readlink -f" failing to deliver the symlink target
# without printing any error message at all. Sometimes, trying to access a just-mounted Windows share
# yields error "cannot access /run/user/1000/gvfs/smb-share:domain=blah,server=blah,share=blah,user=blah: Input/output error",
# and seemingly this causes "readlink -f" to silently fail. At least it returns a non-zero status code.
#
# It looks like readlink's flag "-f" makes it actually try to access the remote server. I have removed that flag,
# because we do not actually need the absolute, canonical path here. This way, readlink always succeed,
# even if the remote server is not accessible yet.

get_link_target ()
{
  set +o errexit

  EXISTING_LINK_TARGET="$(readlink "$1")"

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
    abort "$(printf "The directory entry for share \"%s\" was not found in GVFS mount directory \"$GVFS_MOUNT_LIST_DIR\". Check out the PREREQUISITES section in this script for more information." "$WINDOWS_SHARE_PATH")"
  fi

  local NEW_LINK_TARGET="$GVFS_MOUNT_LIST_DIR/${DETECTED_MOUNT_POINTS[$FOUND_POS]}"

  if [ -h "$MOUNT_POINT" ]; then

    # The file exists and is a symbolic link.

    local EXISTING_LINK_TARGET
    get_link_target "$MOUNT_POINT"

    if [[ $EXISTING_LINK_TARGET == "$NEW_LINK_TARGET" ]]; then
      printf "%i: \"%s\" -> \"%s\" (symlink already existed)\\n" "$MOUNT_ELEM_NUMBER" "$MOUNT_POINT" "$WINDOWS_SHARE_PATH"
    else
      printf "%i: \"%s\" -> \"%s\" (rewriting symlink)\\n" "$MOUNT_ELEM_NUMBER" "$MOUNT_POINT" "$WINDOWS_SHARE_PATH"
      rm -- "$MOUNT_POINT"
      ln --symbolic -- "$NEW_LINK_TARGET" "$MOUNT_POINT"
    fi

  elif [ -e "$MOUNT_POINT" ]; then

    abort "Error creating symbolic link for share \"$WINDOWS_SHARE_PATH\": File \"$MOUNT_POINT\" exists but is not a symbolic link. I am not sure whether I should delete it."

  else

    printf "%i: \"%s\" -> \"%s\" (creating symlink)\\n" "$MOUNT_ELEM_NUMBER" "$MOUNT_POINT" "$WINDOWS_SHARE_PATH"
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

    printf "%i: \"%s\" was not mounted.\\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE_PATH"

    # Note that, if a dangling symbolic link for this share exists, it is left behind.
    # See the CAVEATS section above for more information.

  else

    if [ -h "$MOUNT_POINT" ]; then

      # The file exists and is a symbolic link.

      local EXPECTED_LINK_TARGET="$GVFS_MOUNT_LIST_DIR/${DETECTED_MOUNT_POINTS[$FOUND_POS]}"

      local EXISTING_LINK_TARGET
      get_link_target "$MOUNT_POINT"

      if [[ $EXISTING_LINK_TARGET == "$EXPECTED_LINK_TARGET" ]]; then
        printf "%i: Deleting symbolic link \"%s\" -> \"%s\"...\\n" "$MOUNT_ELEM_NUMBER" "$MOUNT_POINT" "$WINDOWS_SHARE_PATH"
        rm -- "$MOUNT_POINT"
      else
        abort "Error deleting symbolic link for share \"$WINDOWS_SHARE_PATH\": Symlink \"$MOUNT_POINT\" is pointing to an unexpected location. I am not sure whether I should delete it."
      fi

    elif [ -e "$MOUNT_POINT" ]; then

      # The file exists.
      abort "Error deleting symbolic link for share \"$WINDOWS_SHARE_PATH\": File \"$MOUNT_POINT\" exists but is not a symbolic link."

    fi

    printf "%i: Unmounting \"%s\"...\\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE_PATH"

    local URI
    URI="$(build_uri "$MOUNT_DOMAIN" "$MOUNT_USER" "$WINDOWS_SERVER" "$SHARE_NAME")"

    local CMD
    printf -v CMD  "%q --unmount -- %q"  "$GVFS_MOUNT_TOOL"  "$URI"

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
    *)  abort "Error parsing a GVFS directory entry: Unknown component name of \"$NAME\". This script probably needs updating.";;
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
}


find_gvfs_mount_point ()
{
  local SERVER_NAME="$1"
  local SHARE_NAME="$2"
  local MOUNT_DOMAIN="$3"
  local MOUNT_USER="$4"

  local DETECTED_MOUNTPOINT_COUNT="${#DETECTED_MOUNT_POINT_DOMAINS[@]}"

  local i
  for ((i=0; i<DETECTED_MOUNTPOINT_COUNT; i+=1)); do
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

if [ $UID -eq 0 ]; then
  # This script uses variable UID to locate the GVFS mountpoint.
  # You shoud not run this script as root anyway, as FUSE is designed
  # to allow normal users to mount filesystems.
  abort "The user ID is zero, are you running this script as root? You probably should not."
fi


if [ $# -eq 0 ]; then

  SHOULD_MOUNT=true

elif [ $# -eq 1 ]; then

  if [[ $1 = "mount" ]]; then
    SHOULD_MOUNT=true
  elif [[ $1 = "unmount" ]]; then
    SHOULD_MOUNT=false
  elif [[ $1 = "umount" ]]; then
    SHOULD_MOUNT=false
  else
    abort "Wrong argument \"$1\", only optional argument \"unmount\" (or \"umount\") is valid."
  fi
else
  abort "Invalid arguments, only one optional argument \"unmount\" (or \"umount\") is valid."
fi


user_settings


declare -i MOUNT_ARRAY_ELEM_COUNT="${#MOUNT_ARRAY[@]}"
declare -i MOUNT_ENTRY_ARRAY_ELEM_COUNT=7
declare -i MOUNT_ENTRY_REMINDER="$(( MOUNT_ARRAY_ELEM_COUNT % MOUNT_ENTRY_ARRAY_ELEM_COUNT ))"

if [ $MOUNT_ENTRY_REMINDER -ne 0  ]; then
  abort "Invalid element count, array MOUNT_ARRAY is malformed."
fi

if ! type "$GVFS_MOUNT_TOOL" >/dev/null 2>&1 ;
then
  abort "Tool \"$GVFS_MOUNT_TOOL\" is not installed on this system. Check out the PREREQUISITES section in this script for more information."
fi

if ! [ -d "$GVFS_MOUNT_LIST_DIR" ]; then
  # I am not sure whether the gvfs directory always gets automatically created on start-up.
  :

  # MSG="The GVFS mount directory \"$GVFS_MOUNT_LIST_DIR\" does not exist."
  # MSG+=" Either it is somewhere else on your system, in which case you have to edit this script,"
  # MSG+=" or the \"POSIX compatibility layer for GVFS\" is not installed (its Debian package name is 'gvfs-fuse')."
  # abort "$MSG"
fi

read_gvfs_mounts

if $SHOULD_MOUNT; then
  echo "Mounting..."
else
  echo "Unmounting..."
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
  echo "Creating symbolic links..."

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
fi

if $SHOULD_MOUNT; then
  echo "Finished mounting and creating symbolic links."
else
  echo "Finished unmounting."
fi
