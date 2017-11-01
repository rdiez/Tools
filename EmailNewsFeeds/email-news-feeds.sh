#!/bin/bash

# Helper script to run tool 'rss2email' after every login.
#
# I want to turn some online news feeds (RSS or Atom) into old-fashioned e-mails,
# so that I can conveniently read the news offline whenever it suits me,
# and still not miss a thing. However, I could not find a nice server for
# that purpose. They tend to be hard to use or want to see some money in return.
#
# In Ubuntu Linux' repositories I found a tool called 'rss2email' that does the job nicely.
# However, starting it from a crontab proved difficult. That's the reason why
# I wrote this script.
#
# The best way to run this script is to use wrapper script RunBundledScriptAfterDelay.sh .
# Create a folder in your computer and place this script there together with RunBundledScriptAfterDelay.sh .
# Add the latter to your KDE autoruns (or similar) with 2 arguments: a delay of a few minutes,
# and the name of this script.
#
# The chosen delay should be long enough for your computer to start and for you to manually connect to
# the Internet if needs be. If something goes wrong, you will (most likely) get a visual notification
# (see the call to notify-send below).
# Of course, you will only get your news e-mails if you regularly login to your computer,
# but that is close enough to my needs.
#
# The best solution would actually be a daemon that runs rss2email every now and then, but only when
# the computer is connected to the Internet. If something goes wrong, it should retry a few times,
# and then somehow deliver a visual error notification (or maybe per e-mail). However, I did not
# find the time to write such a proper solution.
#
# Note: r2e's config file is located here:
#   $HOME/.rss2email
#
# Copyright (c) 2015 R. Diez
# Licensed under the GNU Affero General Public License version 3.


set -o errexit
set -o nounset
set -o pipefail


display_error_message()
{
  notify-send --icon=dialog-error -- "ERROR e-mailing feeds."
}

trap "display_error_message" ERR

echo "E-mailing RSS feeds..."

# "$(which time)" -f "\nElapsed time running command: %E"

nice -n 15  r2e run  2>&1 | tee "last-run-log.txt"

# notify-send --icon=dialog-information -- "Finished e-mailing feeds."

echo "Finished e-mailing feeds."
