#!/bin/bash

# This is a script I have used for a while in order to build OpenWrt.
#
# I am no longer using it, but I wanted to keep it because it has code and information
# about building OpenWrt, and about Firejail, that I may need again in the future.

# Copyright (c) 2019-2020 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r -i EXIT_CODE_ERROR=1

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r TRACE_MAKE=false

declare -r ENABLE_CCACHE=false


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  command -v "$TOOL_NAME" >/dev/null 2>&1  ||  abort "Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
}


delete_dir_if_exists ()
{
  # $1 = dir name

  if [ -d "$1" ]
  then
    echo "Deleting directory \"$1\" ..."

    rm -rf -- "$1"

    # Sometimes under Windows/Cygwin, directories are not immediately deleted,
    # which may cause problems later on.
    if [ -d "$1" ]; then abort "Cannot delete directory \"$1\"."; fi
  fi
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
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


is_tool_installed ()
{
  if command -v "$1" >/dev/null 2>&1 ;
  then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


add_make_parallel_jobs_flag ()
{
  local -n VAR="$1"

  local SHOULD_ADD_PARALLEL_FLAG=true

  if is_var_set "MAKEFLAGS"
  then

    if false; then
      echo "MAKEFLAGS: $MAKEFLAGS"
    fi

    # The following string search is not 100 % watertight, as MAKEFLAGS can have further arguments at the end like " -- VAR1=VALUE1 VAR2=VALUE2 ...".
    if [[ $MAKEFLAGS =~ --jobserver-fds= || $MAKEFLAGS =~ --jobserver-auth= ]]
    then
      # echo "Called from a makefile with parallel jobs enabled."
      SHOULD_ADD_PARALLEL_FLAG=false
    fi
  fi

  if $SHOULD_ADD_PARALLEL_FLAG; then
    local MAKE_J_VAL

    # This is probably not the best heuristic for make -j , but it's better than nothing.
    MAKE_J_VAL="$(( $(getconf _NPROCESSORS_ONLN) + 1 ))"

    printf  -v VAR -- "%s  --output-sync=recurse -j %q"  "$VAR"  "$MAKE_J_VAL"
  fi
}


quote_and_append_args ()
{
  local -n VAR="$1"
  shift

  local STR

  # Shell-quote all arguments before joining them into a single string.
  printf -v STR  "%q "  "$@"

  # Remove the last character, which is one space too much.
  STR="${STR::-1}"

  if [ -z "$VAR" ]; then
    VAR="$STR"
  else
    VAR+="  $STR"
  fi
}


run_with_sentinel ()
{
  local OPERATION_NAME="$1"
  local SENTINEL_FILENAME="$2"
  local CODE_TO_EVAL="$3"

  if [ -f "$SENTINEL_DIR/$SENTINEL_FILENAME" ]; then
     echo "Operation \"$OPERATION_NAME\" skipped because it has already been performed."
     return
  fi

  echo "Starting operation \"$OPERATION_NAME\"..."

  eval "$CODE_TO_EVAL"

  echo "Finished operation \"$OPERATION_NAME\"."

  echo "Finsished." > "$SENTINEL_DIR/$SENTINEL_FILENAME"
}


declare -r OPENWRT_REPO_NAME=openwrt

declare -A FEED_PACKAGE_REPOS  # Associative array.
FEED_PACKAGE_REPOS["packages"]="https://git.openwrt.org/feed/packages.git"
FEED_PACKAGE_REPOS["luci"]="https://git.openwrt.org/project/luci.git"
FEED_PACKAGE_REPOS["routing"]="https://git.openwrt.org/feed/routing.git"
FEED_PACKAGE_REPOS["telephony"]="https://git.openwrt.org/feed/telephony.git"

operation_update_all_clones ()
{
  pushd "$ALL_REPO_CLONES_DIR" >/dev/null

  local REPO_SUBDIR
  local CMD

  if false; then

    shopt -s nullglob

    for REPO_SUBDIR in ./*; do
      echo "REPO_SUBDIR: $REPO_SUBDIR"
    done

  else

    update_git_repo "$OPENWRT_REPO_NAME"

    local REPO_SUBDIR

    for REPO_SUBDIR in "${!FEED_PACKAGE_REPOS[@]}"; do
      update_git_repo "$REPO_SUBDIR"
    done

  fi

  popd >/dev/null
}


# I wanted to make sure that the build system does not write anything outside its sandbox.
# The easiest way to achieve it is with Firejail.

build_firejail_cmd ()
{
  verify_tool_is_installed "firejail" "firejail"

  FIREJAIL_CMD="firejail"

  # Without --quiet, Firejail prints the command and some other output.
  quote_and_append_args  FIREJAIL_CMD  "--quiet"

  # The default profile is very restrictive.
  quote_and_append_args  FIREJAIL_CMD  "--noprofile"

  # The build process needs no special capabilities.
  quote_and_append_args  FIREJAIL_CMD  "--caps.drop=all"

  # The build  process needs no new privileges.
  quote_and_append_args  FIREJAIL_CMD  "--nonewprivs"

  # The default seccomp restrictions should be OK.
  quote_and_append_args  FIREJAIL_CMD  "--seccomp"

  # This tends to fail and get ignored on Ubuntu.
  # It turns out that the combination "--read-only=/ --noroot" is known to fail as of 14.04.2020.
  # Apparently, there have been attempts to get this fixed.
  quote_and_append_args  FIREJAIL_CMD  "--noroot"

  # Watch out: The order of the --read-only and --read-write arguments may be important.

  if false; then

    local -r TEMP_DIR="${TMPDIR:-/tmp}"

    # Something as simple as this:
    #   firejail --noprofile --read-only=/ --read-write=/tmp
    # is known to be broken with Firejail version 0.9.62, which is the latest as of 14.04.2020,
    # and has already been fixed in git master.
    quote_and_append_args  FIREJAIL_CMD  "--read-only=/"
    quote_and_append_args  FIREJAIL_CMD  "--read-write=$TEMP_DIR"

  else

    # This protection is not ideal, but it shoudl suffice for our purposes.

    quote_and_append_args  FIREJAIL_CMD  "--read-only=$HOME"
    quote_and_append_args  FIREJAIL_CMD  "--read-write=$SCRIPT_DIR_ABS"

  fi
}


run_cmd_in_sandbox_no_net ()
{
  local CMD="$1"

  local FIREJAIL_CMD
  build_firejail_cmd

  quote_and_append_args  FIREJAIL_CMD  "--net=none"

  FIREJAIL_CMD+=" -- "

  echo "$FIREJAIL_CMD$CMD"
  eval "$FIREJAIL_CMD$CMD"
}


run_cmd_in_sandbox ()
{
  local CMD="$1"

  local FIREJAIL_CMD
  build_firejail_cmd

  FIREJAIL_CMD+=" -- "

  echo "$FIREJAIL_CMD$CMD"
  eval "$FIREJAIL_CMD$CMD"
}


update_git_repo ()
{
  local DIR="$1"

  echo "Updating repository $DIR ..."

  echo

  pushd "$DIR" >/dev/null

  CMD="git fetch"

  echo "$CMD"
  eval "$CMD"

  echo

  # Switch "--ff-only" prevents unnecessary merge commits that tend to clutter the Git history while providing no real value.

  CMD="git merge --ff-only FETCH_HEAD"

  echo "$CMD"
  eval "$CMD"

  popd >/dev/null
}


declare -r USE_LOCAL_REPO_CLONES=true

operation_clone_openwrt_repo ()
{
  local CHECKOUT_COMMIT="$1"

  if false; then
    if test -d "$REPO_DIR"
    then
      abort "The following directory already exists: $REPO_DIR"
    fi
  else
    delete_dir_if_exists "$REPO_DIR"
  fi


  local CMD

  CMD="git clone"

  # We cannot clone the local master package repositories with Git's "file://" protocol, because the clone of a cloned
  # Git repository drops branches compared to the original repository. See "git clone --mirror" for more information.
  # These missing branches become aparent later on, as the main OpenWrt repository references particular commit IDs
  # in the package repositories that are no longer present in the second-generation clones.
  #
  # If you clone a repository specified with a local file path, Git uses hardlinks, and the whole repository
  # is then completely "cloned". This works under Linux if the master repositories reside in the same filesystem.
  #
  # We could still haved cloned the main OpenWrt repository with "file://", but it is not worth having different repositories
  # cloned in different ways.

  quote_and_append_args  CMD  "--branch" "$CHECKOUT_COMMIT"

  # If we are not using the "file://" protocol when cloning, so Git would show the following warning:
  #   warning: --depth is ignored in local clones; use file:// instead.
  if false; then
    quote_and_append_args  CMD  "--depth=1"
  fi

  if $USE_LOCAL_REPO_CLONES; then
    quote_and_append_args  CMD  "$ALL_REPO_CLONES_DIR_ABS/$OPENWRT_REPO_NAME"
  else
    quote_and_append_args  CMD  "https://git.openwrt.org/openwrt/openwrt.git/"
  fi

  quote_and_append_args  CMD  "$REPO_DIR"

  echo "$CMD"
  eval "$CMD"


  # I have kept this code in case we need again in the future.
  if false; then
    pushd "$REPO_DIR" >/dev/null

    CMD="git checkout"

    quote_and_append_args  CMD  "$CHECKOUT_COMMIT"

    echo "$CMD"
    eval "$CMD"

    popd >/dev/null

  fi
}


# I am not sure that cleaning the repository does help. It is probably safer
# to re-clone the original repository, which is no longer a very slow operationg,
# because the original repository is now yet another clone on the local disk.

operation_clean_openwrt_repo ()
{
  pushd "$REPO_DIR" >/dev/null

  # Any changes to tracked files in the working tree and index are discarded.
  # We would normally use "origin/master" here, but that does not exist when cloning/checking out
  # a particular commit/tag.
  git reset --hard HEAD

  # git-clean: Remove untracked files from the working tree.
  #   -d: Remove untracked directories in addition to untracked files.
  #   -x: Don’t use the standard ignore rules read from .gitignore etc.
  #   -f: Force.
  git clean -d -x -f

  popd >/dev/null
}


# Setting this information is convenient if you want to contribute patches.

operation_set_repo_user ()
{
  pushd "$REPO_DIR" >/dev/null

  git config user.name  "$GIT_REPO_USER_NAME"
  git config user.email "$GIT_REPO_EMAIL"

  popd >/dev/null
}


operation_set_openwrt_version ()
{
  pushd "$REPO_DIR" >/dev/null

  # A typical OpenWrt version string is "r9299-83bcacb521". The OpenWrt version is then 'OpenWrt SNAPSHOT r9299-83bcacb521'.
  # The Linux Kernel stores a version like "gcc version 7.4.0 (OpenWrt GCC 7.4.0 r9299-83bcacb521)".
  #
  # OpenWrt's script scripts/getver.sh is rather brittle. For example, it does not cope well with
  # shallow clones of Git repositories. I reported this on the OpenWrt devel mailing list:
  #
  #   Invalid revision range
  #   Mon Jan 21 02:42:37 PST 2019
  #   https://lists.openwrt.org/pipermail/openwrt-devel/2019-January/015548.html
  #
  # Therefore, it is best to set our version string upfront.
  # Such a version string also reminds us that this is not an official OpenWrt build.

  declare -r VERSION_STRING="$USER-TestBuild"
  echo "Setting version to '$VERSION_STRING'."
  echo "$VERSION_STRING" >"version"

  popd >/dev/null
}


operation_patch_repo ()
{
  rm -- "$REPO_DIR/scripts/timestamp.pl"

  local -r ENV_VAR_NAME="MY_TOOLS_DIR"

  if ! is_var_set "$ENV_VAR_NAME"; then
    abort "Environment variable $ENV_VAR_NAME is not set."
  fi

  ln --symbolic  "${!ENV_VAR_NAME}/Timestamp/timestamp.pl"  "$REPO_DIR/scripts/timestamp.pl"

  sed --binary --regexp-extended --in-place  --expression='/SIGNATURE:=/a'"\\" --expression='SIGNATURE:=12345678'  "$REPO_DIR/target/linux/x86/image/Makefile"
}


operation_update_feeds ()
{
  pushd "$REPO_DIR" >/dev/null

  if $USE_LOCAL_REPO_CLONES; then

    # Parse file feeds.conf.default and generate a feeds.conf file where the remote URLs we know of
    # have been changed to local file paths.

    local -r FEEDS_CONF_FILENAME="feeds.conf"
    local -r FEEDS_CONF_DEFAULT_FILENAME="feeds.conf.default"

    local FEEDS_CONF_DEFAULT_CONTENTS
    FEEDS_CONF_DEFAULT_CONTENTS="$(<"$FEEDS_CONF_DEFAULT_FILENAME")"

    # Split on newline characters.
    local FEEDS_CONF_DEFAULT_LINES
    mapfile -t FEEDS_CONF_DEFAULT_LINES <<< "$FEEDS_CONF_DEFAULT_CONTENTS"

    local -r FEEDS_CONF_DEFAULT_LINE_COUNT="${#FEEDS_CONF_DEFAULT_LINES[@]}"

    # Truncate the output file if it exists.
    echo -n > "$FEEDS_CONF_FILENAME"

    # A Git repository URL may have a suffix like "^efa6e5445adda9c6545f551808829ec927cbade8" with a Git commit ID.
    local -r URL_WITH_GIT_COMMIT_ID_REGEX='(.*)\^(.*)'

    for ((i=0; i<FEEDS_CONF_DEFAULT_LINE_COUNT; i+=1)); do
      local LINE="${FEEDS_CONF_DEFAULT_LINES[$i]}"

      if str_starts_with "$LINE" "#"; then
        continue;
      fi

      local PARTS
      IFS=$' \t' read -r -a PARTS <<< "$LINE"

      local PART_COUNT="${#PARTS[@]}"

      if (( PART_COUNT != 3 )); then
        abort "Error in file \"$FEEDS_CONF_DEFAULT_FILENAME\": Unexpected component count in line: ${PARTS[*]}"
      fi

      local REPO_TYPE="${PARTS[0]}"
      if [[ $REPO_TYPE != "src-git" ]]; then
        abort "Error in file \"$FEEDS_CONF_DEFAULT_FILENAME\": Unexpected repository type \"$REPO_TYPE\" parsing line: ${PARTS[*]}"
      fi

      local REPO_NAME="${PARTS[1]}"

      if ! test "${FEED_PACKAGE_REPOS[$REPO_NAME]+string_returned_ifexists}"; then
        abort "Error in file \"$FEEDS_CONF_DEFAULT_FILENAME\": Unknown repository \"$REPO_NAME\" parsing line: ${PARTS[*]}"
      fi

      local REPO_URL="${PARTS[2]}"
      local GIT_COMMIT_ID

      if [[ $REPO_URL =~ $URL_WITH_GIT_COMMIT_ID_REGEX ]]; then
        GIT_COMMIT_ID="^${BASH_REMATCH[2]}"
      else
        GIT_COMMIT_ID=""
      fi

      {
        # See the comment in operation_clone_openwrt_repo() about why we are not using the "file://" protocoll when cloning with Git.
        # src-git probably won't cut it, because script scripts/feeds does a shallow clone, but we need
        # to check out a specific commit ID later on.
        echo "src-git-full $REPO_NAME $ALL_REPO_CLONES_DIR_ABS/$REPO_NAME$GIT_COMMIT_ID"
      } >>"$FEEDS_CONF_FILENAME"

    done
  fi

  local CMD

  CMD="./scripts/feeds update -a"

  if $USE_LOCAL_REPO_CLONES; then
    run_cmd_in_sandbox_no_net "$CMD"
  else
    run_cmd_in_sandbox "$CMD"
  fi

  popd >/dev/null
}


operation_install_feeds ()
{
  pushd "$REPO_DIR" >/dev/null

  local CMD
  CMD="./scripts/feeds install -a"

  run_cmd_in_sandbox_no_net "$CMD"

  popd >/dev/null
}


operation_generate_x86_target_config ()
{
  pushd "$REPO_DIR" >/dev/null

  # Notes kept:
  #
  # - How to automate the menuconfig:
  #
  #     make menuconfig
  #     ... manually create the configuration ...
  #     ./scripts/diffconfig.sh >my_config_seed
  #
  #   If you are modifying the seed in this script, you can temporarily turn on
  #   the part below that runs diffconfig.sh , so that you can check
  #   that your seed consistently produces the same seed again.
  #
  #   OpenWrt's configuration system changes. It may be a good idea to check that
  #   the old configuration seed still works as intended.
  #
  # - OpenWrt script scripts/package-metadata.pl seems able to parse "make menuconfig" information.
  #       See also script scripts/kconfig.pl .
  #
  # - The Linux kernel repository contains a script called "scripts/config" that you can use
  #   to modify an existing configuration file.


  local -r CONFIG_FILE=".config"
  # echo "The configuration file for the x86 target is \"$CONFIG_FILE\"."

  # I am not sure whether the OpenWrt build system checks if ccache is available on the host,
  # so check it ourselves.
  if $ENABLE_CCACHE; then
    verify_tool_is_installed "ccache" "ccache"
  fi


  # Generate the configuration seed.
  {
    echo "CONFIG_TARGET_x86=y"
    echo "CONFIG_TARGET_x86_64=y"
    echo "CONFIG_TARGET_x86_64_Generic=y"

    # CONFIG_DEVEL must be set in "make menuconfig" in order to access CONFIG_DOWNLOAD_FOLDER and CONFIG_CCACHE,
    # although CONFIG_DEVEL itself does not actually seem necessary during the build.
    echo "CONFIG_DEVEL=y"

    # The double quotation marks around the value are necessary.
    echo "CONFIG_DOWNLOAD_FOLDER=\"$SCRIPT_DIR_ABS/$DOWNLOAD_FOLDER_DIR\""

    # The double quotation marks around the value are necessary.
    echo "CONFIG_GRUB_TIMEOUT=\"0\""


   if $ENABLE_CCACHE; then

     # Using ccache actually requires more investigation:
     #
     # There have been discussions and changes about ccache in 2020 in the OpenWrt project,
     # so maybe all of the information below is outdated now.
     #
     # There seems to be 2 ccache areas, and configuration setting CONFIG_CCACHE seems to enable both of them.
     #
     # Area 1) Host compilation.
     #         The OpenWrt build system downloads and builds many of the host build tools it needs,
     #         for example, a newer version of ccache itself.
     #         It is unclear from what point OpenWrt uses its own ccache, as opposed to the systems' ccache.
     #         The ccache hit rate in this area seems very low. I wonder why.
     #         One test I could do is to uninstall the system's ccache and see whether OpenWrt tries to use it.
     #
     # Area 2) Target compilation.
     #         In this area, ccache is only worth using if you are cleaning and rebuilding the target executables
     #         on the same sandbox over and over. Sharing ccache's cache between sandboxes could be problematic.
     #
     # In addition to the "version" file, we could also generate or overwrite file "version.date".
     # That could give ccache a better chance at really caching compilations.
     # This file is present in release branches, but not in the 'master' branch.
     # For more information, see scripts/get_source_date_epoch.sh .
     #
     # - The OpenWrt buildbot shows how to use ccache's compiler_check setting, see repository buildbot.git, file scripts/ccache.sh .
     #
     # - It looks like OpenWrt generates about 270 GiB of object files in the host's cache.
     #
     #   There are more notes about ccache in my script BuildOpenWrt-X86_64-FromScratch.sh .
     #
     #   [doch?]  Despite the config change, ccache does not seem to get used. Why is that?
     #
     #   This is one example of ccache invocation:
     #
     #     ccache gcc -I/home/rdiez/rdiez/freifunk/openwrt/git-repo/staging_dir/host/include -DHAVE_CONFIG_H
     #     -DSYSCONFDIR=\"/home/rdiez/rdiez/freifunk/openwrt/git-repo/staging_dir/host/etc\" -DCPU_x86_64 -DVENDOR_pc
     #     -DOS_linux_gnu -O2 -I/home/rdiez/rdiez/freifunk/openwrt/git-repo/staging_dir/host/include -Wall -fno-strict-aliasing -I.
     #     -I.  -c fat.c
     #
     #   It is not clear whether it is using the system's ccache, or building its own ccache:
     #
     #     /usr/bin/install -c -m 755 ccache /home/rdiez/rdiez/freifunk/openwrt/git-repo/staging_dir/host/bin
     #
     #   I could find out by:
     #   1) Removing ccache from the system.
     #   2) Changing the ccache repo in the system.
     #
     #   OpenWrt is using its private copy here:
     #     /home/rdiez/rdiez/freifunk/openwrt/git-repo/staging_dir/host/bin
     #
     #   The ccache's cache dir seems to be here:
     #     staging_dir/host/ccache
     #
     #   Here is a confirmation:
     #     https://lists.openwrt.org/mailman/listinfo/openwrt-devel
     #
     #   Maybe we should be setting this environment variable: CCACHE_DIR=~/.ccache
     #
     #   Does ccache realise when the compiler has changed? Probably yes.
     #   And it probably will not work properly then for our OpenWrt sandbox.
     #   Look at ccache's config file option "compiler_check".
     #
     # I am getting these warnings:
     # Does this happen with Git 'master' too?
     #   make[2]: Entering directory '/home/rdiez/rdiez/Freifunk/OpenWrt/WorkingOpenWrtGitRepository/toolchain/musl'
     #   bash: ccache_cc: command not found
     #   bash: ccache_cc: command not found
     #   bash: ccache_cc: command not found

     echo "CONFIG_CCACHE=y"
   fi

  } >"$CONFIG_FILE"


  # Expand file .config to a full configuration.
  local CMD
  CMD="make defconfig"

  run_cmd_in_sandbox_no_net "$CMD"


  # This should output the same seed we used above. You can use this to check your seed for consistency.
  if false; then
    CMD="./scripts/diffconfig.sh"
    echo "$CMD"
    eval "$CMD"
  fi

  popd >/dev/null
}


operation_make_download ()
{
  pushd "$REPO_DIR" >/dev/null

  local CMD

  CMD="make  $OPENWRT_MAKE_FLAGS  download"

  if $TRACE_MAKE; then
    CMD+=" --trace"
    CMD+=" --debug=j"
  fi

  run_cmd_in_sandbox "$CMD"

  popd >/dev/null
}


operation_make_build ()
{
  local -r TARGET="$1"

  pushd "$REPO_DIR" >/dev/null

  local CMD

  CMD="make  $OPENWRT_MAKE_FLAGS"

  add_make_parallel_jobs_flag "CMD"

  if $TRACE_MAKE; then
    # Print what targets are considered not up to date.
    CMD+=" --trace"

    # a: print all debugging information
    # b: print basic debugging information
    # v: print more verbose basic debugging information
    # There other more such options.
    CMD+=" --debug=a"
  fi

  if [[ $TARGET != "" ]]; then
    quote_and_append_args "CMD" "$TARGET"
  fi

  run_cmd_in_sandbox_no_net "$CMD"

  popd >/dev/null
}


operation_make_archive ()
{
  # local CURRENT_DATE
  # printf -v CURRENT_DATE "%(%F %H:%M:%S)T"
  local -r COMPRESSED_FILENAME="$1.7z"

  # In case the file is already there, attempt to delete it.
  rm -f -- "$COMPRESSED_FILENAME"

  printf -v CMD  "%s %q  %q"  "$COMPRESS_CMD"  "$COMPRESSED_FILENAME"  "$REPO_DIR/"

  echo "$CMD"
  eval "$CMD"
}


# ----------- Entry point -----------


case "$#" in

  1) declare -r OPERATION="$1"
     declare -r GIT_REPO_USER_NAME=""
     ;;

  3) declare -r OPERATION="$1"
     declare -r GIT_REPO_USER_NAME="$2"
     declare -r GIT_REPO_EMAIL="$3"
     ;;

  *) abort "Invalid number of command-line arguments. See this script's source code for more information.";;
esac


case "$OPERATION" in
  update-master-repositories) declare -r DELETE_SENTINELS=true  ;;
  rebuild)                    declare -r DELETE_SENTINELS=true  ;;
  build)                      declare -r DELETE_SENTINELS=false ;;
  *) abort "Unknown operation '$OPERATION'";;
esac


SCRIPT_DIR_ABS="$(readlink --canonicalize-existing --verbose -- ".")"

declare -r ALL_REPO_CLONES_DIR="MasterRepositories"

declare -r REPO_DIR="WorkingOpenWrtGitRepository"

declare -r DOWNLOAD_FOLDER_DIR="DownloadFolder"

# The sentinel files cannot live in the repository, because when we clean it, they would be deleted automatically.
declare -r SENTINEL_DIR="BuildSentinels"

if $DELETE_SENTINELS; then
  delete_dir_if_exists  "$SENTINEL_DIR"
fi

mkdir --parents -- "$SENTINEL_DIR"


OPENWRT_MAKE_FLAGS=""


# About redirecting stdin to /dev/null before running this script:
#
#   The build commands below are designed to run unattended. They should not need
#   anything from stdin. If they do, that is unexpected, and they should fail straight away.
#   That's why redirecting stdin to /dev/null is a good idea.
#
#   OpenWrt's makefile does not determine correctly whether it is running inside a terminal,
#   see this bug report of mine:
#     FS#2086 - IS_TTY in the makefile is broken
#     https://bugs.openwrt.org/index.php?do=details&task_id=2086
#   The makefile checks stdin instead of stdout. Therefore, redirecting stdin to /dev/null
#   also disables terminal colour codes in the build output, which is often desirable
#   if you are keeping a build log as a text file.
#
# Rather than relying on OpenWrt's makefile, this script tests stdout itself and decides
# whether to colour the output or not.

declare -r -i STDOUT_FD_NUMBER=1

if [ -t "$STDOUT_FD_NUMBER" ]; then
  # We are outputting to a terminal. We can probably turn of coloured output.
  quote_and_append_args  OPENWRT_MAKE_FLAGS  "NO_COLOR=0"  "IS_TTY=1"
else
  # We are outputting to something else, probably a file. Turning on coloured output is probably a bad idea.
  quote_and_append_args  OPENWRT_MAKE_FLAGS  "NO_COLOR=1"  "IS_TTY=0"
fi

# Variable V can be set to one or more of the following flags:
# - Flag 's' means stdout + stderr are visible.
# - Flag 'c' means see the build commands, and ist meant for build systems that suppress commands by default, e.g. kbuild, cmake.
#   This flag seems however little used in the build system.
# - Flag 'w' means let stderr through, but not stdout. You normally do not use flag 's' together with this one.
quote_and_append_args  OPENWRT_MAKE_FLAGS  "V=sc"


# Passing these variables seems to have no effect.
if false; then
  if $ENABLE_CCACHE; then
    quote_and_append_args OPENWRT_MAKE_FLAGS "CC=ccache gcc"
    quote_and_append_args OPENWRT_MAKE_FLAGS "CXX=ccache g++"
  fi
fi


declare -r COMPRESS_CMD="7z  a  -t7z  -m0=lzma2  -mx1  -mmt=on  -ms -- "

declare -r ALL_REPO_CLONES_DIR_ABS="$SCRIPT_DIR_ABS/$ALL_REPO_CLONES_DIR"


# Turn this on only if you need to trace the rebuild decisions made with my version of script timestamp.pl .
if $TRACE_MAKE; then
  export TIMESTAMP_PL_OPTIONS="--trace-search-args --trace-up-to-date"
fi


if [[ $OPERATION = "update-master-repositories" ]]; then

  run_with_sentinel "Update all repository clones"  "update-all-clones.sentinel"  "operation_update_all_clones"

  echo

  echo "Finished updating all repository clones."

  exit 0

fi


# This is normally the tag of the OpenWrt's version we want to build.
# Use 'master' for the very latest commit.
# Tags that I have been using: v19.07.2
declare -r OPENWRT_CHECKOUT_COMMIT="master"

run_with_sentinel "Clone the OpenWrt repository"  "clone-openwrt-repo.sentinel"  "operation_clone_openwrt_repo $OPENWRT_CHECKOUT_COMMIT"

echo

run_with_sentinel "Clean the OpenWrt repository"  "clean-openwrt-repo.sentinel"  "operation_clean_openwrt_repo"

echo

if [[ $GIT_REPO_USER_NAME != "" ]]; then
  run_with_sentinel "Set the repository user and e-mail"  "set-repo-user.sentinel"  "operation_set_repo_user"
  echo
fi

run_with_sentinel "Patch the repository."  "patch-repo.sentinel"  "operation_patch_repo"

echo

run_with_sentinel "Set the OpenWrt version string"  "set-openwrt-version.sentinel"  "operation_set_openwrt_version"

echo

run_with_sentinel "Update package feeds"  "update-feeds.sentinel"  "operation_update_feeds"

echo

run_with_sentinel "Install package feeds"  "install-feeds.sentinel"  "operation_install_feeds"

echo

run_with_sentinel "Generate x86 target configuration"  "generate-x86-target-config.sentinel"  "operation_generate_x86_target_config"

echo

run_with_sentinel "Download"  "make-download.sentinel"  "operation_make_download"

echo

run_with_sentinel "Build OpenWrt"  "build.sentinel"  "operation_make_build ''"

echo

if false; then

  run_with_sentinel "Archive all results"  "archive.sentinel"  "operation_make_archive GitRepoAfterBuilding"

  echo

fi

echo "Finished building OpenWrt."
