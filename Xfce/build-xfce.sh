#!/bin/bash

# See display_help below for information about this script.

set -o errexit
set -o nounset
set -o pipefail

# Trace this script.
#   set -x

SCRIPT_NAME="build-xfce.sh"
VERSION_NUMBER="1.00"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
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


clone_or_update ()
{
  local REPO_DIR="$1"

  case "$REPO_OPERATION" in
    clone)
      delete_dir_if_exists "$REPO_DIR"
      # Downloading a shallow clone saves time and bandwidth. If you need the full
      # history later on, issue command "git fetch --unshallow".
      printf -v CMD "git clone --depth 1 --shallow-submodules  %q"  "$BASE_GIT_URL/$REPO_DIR"
      echo $CMD
      eval $CMD
      return
      ;;

    update)
      printf -v CMD "pushd %q >/dev/null  &&  git pull --rebase  &&  popd >/dev/null"  "$REPO_DIR"
      echo $CMD
      eval $CMD
      return
      ;;

    noupdate)
      return
      ;;
    *)
      abort "Invalid repository operation \"$REPO_OPERATION\"."
      ;;
  esac
}


build_component_with_options ()
{
  echo
  echo "Building component '$1'..."

  pushd "$1" >/dev/null

  ./autogen.sh  --prefix="${INSTALLATION_PREFIX}"  $2


  # Command 'local' is in a separate line, in order to prevent masking any error from the external command invoked.
  local PARALLEL_COUNT

  # You can use here any other heuristic or fixed value you wish.
  PARALLEL_COUNT="$(( $(getconf _NPROCESSORS_ONLN) + 1 ))"

  # Make's flag --no-builtin-variables does not work, because some of the makefiles use variable $(RM) .
  # I am using --no-builtin-rules because GNU Make runs faster with it.
  make  --no-builtin-rules  -j "$PARALLEL_COUNT"  $MAKE_OPTIONS

  make install

  popd >/dev/null

  echo "Finished building component '$1'."
}


build_component ()
{
  build_component_with_options "$1" "$AUTOGEN_OPTIONS"
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This script clones or updates the local Xfce Git repositories and builds them all."
  echo
  echo "You will probably want to manually amend some options in this script before"
  echo "running it for the first time. See for example BASE_GIT_URL, MAKE_OPTIONS"
  echo "and AUTOGEN_OPTIONS in this script's source code. You may also want to add or remove"
  echo "some of the Xfce repositories to process."
  echo
  echo "Syntax:"
  echo "  ./$SCRIPT_NAME dest_dir repo_operation"
  echo
  echo "Valid repo_operation values are:"
  echo "  clone     Delete any existing local repositories and clone them from the server."
  echo "  update    Update the existing local repositories."
  echo "  noupdate  Do not update the local repositories before building."
  echo
  echo "You probably want to run this script with \"background.sh\", so that you get a"
  echo "visual indication when the build is complete. You will find background.sh in"
  echo "the same repository as this script."
  echo
}


# ------- Entry point -------

if [ $# -eq 0 ]; then
  display_help
  exit 0
fi

if [ $# -ne 2 ]; then
  abort "Invalid number of command-line arguments. Run this script without arguments for help."
fi


DEST_DIR="$1"
REPO_OPERATION="$2"

mkdir -p -- "$DEST_DIR"
cd -- "$DEST_DIR"


BASE_GIT_URL="git://git.xfce.org/xfce"
# When testing this script, you can clone from other local repositories like this,
# in order to avoid cloning too much from the remote server:
# BASE_GIT_URL="file://$HOME/dir-where-the-xfce-repos-are"

# This where the compiled Xfce programs etc. will be installed.
INSTALLATION_PREFIX="$(readlink --canonicalize --verbose "bin")"

clone_or_update "xfce4-dev-tools"
clone_or_update "libxfce4util"
clone_or_update "xfconf"
clone_or_update "libxfce4ui"
clone_or_update "garcon"
clone_or_update "exo"
clone_or_update "xfce4-panel"
clone_or_update "thunar"

delete_dir_if_exists "$INSTALLATION_PREFIX"

# Whether to do a debug or a release build.
if true; then
  export CFLAGS=""
  AUTOGEN_OPTIONS="--enable-debug=on"
else
  export CFLAGS="-O2 -pipe"
  AUTOGEN_OPTIONS="--enable-debug=minimum"
fi

# Whether to show the full commands used when building. This is useful
# when debugging the build script.
if false; then
  MAKE_OPTIONS="V=1"
else
  MAKE_OPTIONS=""
fi

echo "Using CFLAGS: $CFLAGS"

# The first repository 'xfce4-dev-tools' does not use AUTOGEN_OPTIONS.
build_component_with_options "xfce4-dev-tools" ""

# Tool xdt-autogen must be in the PATH.
export PATH="$INSTALLATION_PREFIX/bin:$PATH"

# The first package, libxfce4util, does not actually need PKG_CONFIG_PATH yet,
# but it does not hurt either if it is set.
PKG_CONFIG_DIR="${INSTALLATION_PREFIX}/lib/pkgconfig"
export PKG_CONFIG_PATH="${PKG_CONFIG_DIR}${PKG_CONFIG_PATH:+:}${PKG_CONFIG_PATH:-}"

echo "Using AUTOGEN_OPTIONS: $AUTOGEN_OPTIONS"

# Possible optimisation: We could build some of the following repositories in parallel.

build_component "libxfce4util"
build_component "xfconf"
build_component "libxfce4ui"
build_component "garcon"
build_component "exo"
build_component "xfce4-panel"
build_component "thunar"

echo "Xfce build complete, the installation directory is:"
echo "$INSTALLATION_PREFIX"
