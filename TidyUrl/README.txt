
TidyUrl.sh

This script downloads the given URL to a fixed filename under your home directory,
and runs HTML 'tidy' against it for lint purposes.

It can optionally run 'stylelint' too for CSS linting.

Usage example:

  # If set, this environment variable indicates where stylelint's configuration file
  # is located. Usual filenames are ".stylelintrc.json" and ".stylelintrc.js".
  export TIDYURL_STYLELINT="$HOME/my-stylelint-config"

  TidyUrl.sh file:///full/path/to/my/file.html
