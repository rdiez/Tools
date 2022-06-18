#!/bin/bash

# This script is rather destructive: it reverts the working directory
# to a pristine state, like after doing the first "git clone".
# All files, include .gitignore'd files, are deleted.
#
# Such a clean directory can be used, for example, to test a build from scratch.
# However, for this purpose alone, "git stash --all" is probably a better choice.
# Or check out to a separate directory, or do a "git clone --shared",
# or create a new shallow clone somewhere else.

set -o errexit
set -o nounset
set -o pipefail

# Any changes to tracked files in the working tree and index are discarded.
git reset --hard origin/master  --recurse-submodule

# The "git reset" may fail in the submodules under some circumstances.
#
# Instead of --recurse-submodule, some people do this instead:
#   git submodule sync --recursive
#   git submodule update --init --force --recursive
#
# This way is allegedly safer, but it takes longer:
#   # unbinds all submodules
#   git submodule deinit --force .
#   # checkout again
#   git submodule update --init --recursive

# git-clean: Remove untracked files from the working tree.
#   -d: Remove untracked directories in addition to untracked files.
#   -x: Don't use the standard ignore rules read from .gitignore etc.
git clean -d -x --force --force

git submodule foreach --recursive  git clean -d -x --force --force
