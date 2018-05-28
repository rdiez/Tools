#!/bin/bash

# Copyright (c) 2018 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


# -------- Entry point --------

if [ $# -ne 0 ]; then
  abort "Wrong number of command-line arguments. See this script's source code for more information."
fi

SHELLCHECK_BIN="shellcheck"
printf -v SHELLCHECK_BIN_QUOTED "%q" "$SHELLCHECK_BIN"

BASEDIR="."
printf -v BASEDIR_QUOTED "%q" "$BASEDIR"


declare -a SEARCH_DIRS_TO_IGNORE=()

SEARCH_DIRS_TO_IGNORE+=( "Autotools/AutotoolsIntermediateBuildFiles" )
SEARCH_DIRS_TO_IGNORE+=( "Autotools/*-bin" )

SEARCH_DIRS_TO_IGNORE_JOINED="$(printf -- " -o -path $BASEDIR/%q" "${SEARCH_DIRS_TO_IGNORE[@]}")"
SEARCH_DIRS_TO_IGNORE_JOINED="${SEARCH_DIRS_TO_IGNORE_JOINED:4}"


CMD="find $BASEDIR -type d \\( $SEARCH_DIRS_TO_IGNORE_JOINED \\) -prune -o -name '*.sh' -print"
CMD+=" | xargs  --no-run-if-empty"
CMD+=" $SHELLCHECK_BIN_QUOTED  --format=gcc"
# CMD+=" --exclude=\"SC1117\""

echo "$CMD"
eval "$CMD"
