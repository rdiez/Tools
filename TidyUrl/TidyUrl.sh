#!/bin/bash

# Script version 1.02.
#
# This script downloads the given URL to a fixed filename under your home directory,
# and runs HTML 'tidy' against it for lint purposes.
#
# I use it from Emacs to check if an web page generates any HTML warnings.
#
# If the URL starts with "file://", the file is not downloaded, but used directly.
#
# Optional CSS linting:
#
#   If environment variable TIDYURL_STYLELINT is set, it is assumed to point to
#   a directory containing stylelint's configuration file ".stylelintrc.json" or ".stylelintrc.js".
#
#   Normally, there is also a subdirectory there called "node_modules", with
#   yet another subdirectory called "stylelint-config-standard" and so on.
#
#   This script will change to the TIDYURL_STYLELINT directory and run stylelint
#   against the downloaded file too.
#
# Copyright (c) 2018-2023 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit 1
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


main ()
{
  local -r URL="$1"

  local -r FILE_PREFIX="file://"

  local FILE_PATH

  if str_starts_with "$URL" "$FILE_PREFIX"; then

    # Remove the prefix.
    FILE_PATH="${URL:${#FILE_PREFIX}}"

  else

    local -r DOWNLOAD_DIR="$HOME/.$SCRIPT_NAME-tmp-dir"

    mkdir --parents -- "$DOWNLOAD_DIR"

    # We could rotate the last N files like script background.sh does.
    FILE_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME-tmp.html"

    local CMD

    CMD="curl"

    # Option --location makes curl follow redirects.
    # It does not work with HTML redirects like:  <meta http-equiv="refresh" ...>
    CMD+=" --location"

    CMD+=" --silent"
    CMD+=" --show-error"

    printf -v CMD  "$CMD --output %q  %q"  "$FILE_PATH"  "$URL"

    echo "$CMD"
    eval "$CMD"

  fi


  printf -v CMD "tidy --gnu-emacs yes  -quiet -output /dev/null  %q"  "$FILE_PATH"

  echo "$CMD"

  # I am running this script from other scripts, and there is quite a lot of console output.
  # Tool 'tidy' does not output anything at all if there are no warnings.
  # So I added these markers, in order to quickly locate any HTML warnings in the output.
  echo
  echo "--- Tidy output begin ---"

  eval "$CMD"

  echo "--- Tidy output end   ---"
  echo

  if is_var_set "TIDYURL_STYLELINT"; then

    if [ -z "$TIDYURL_STYLELINT" ]; then
      abort "Environment variable TIDYURL_STYLELINT is set, but its value is empty."
    fi

    pushd "$TIDYURL_STYLELINT" >/dev/null

    # The 'unix' formatter generates warnings like a C compiler does. Emacs' compilation-minor-mode
    # can automatically hyperlink them to the locations they refer to inside the downloaded HTML file.
    #
    # Option '--no-update-notifier' prevents the frequent "update available" warning,
    # and hopefully the related Internet access to check for new versions too.

    printf -v CMD \
           "npx  --no-update-notifier -- stylelint  --formatter=unix  --  %q" \
           "$FILE_PATH"

    echo "$CMD"

    echo
    echo "--- stylelint output begin ---"

    eval "$CMD"

    echo "--- stylelint output end ---"
    echo

    popd >/dev/null

  else
    echo "Environment variable TIDYURL_STYLELINT not set, so CSS linting with stylelint was skipped."
    echo
  fi

  echo "Finished."
}


if (( $# != 1 )); then
  abort "You need to pass a single argument with the URL."
fi

main "$1"
