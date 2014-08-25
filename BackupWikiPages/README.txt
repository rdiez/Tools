
Wiki Page Backup

This script downloads a set of Wiki pages in several formats from a MediaWiki server.

Usage:

First of all, edit the script in order to enter your own page URLs. Then run it
with the download destination directory as the one and only argument.

For maximum comfort, see companion script BackupExampleWithRotateDir.sh, which uses RotateDir.pl
in order to automatically rotate the backup directories.

Motivation:

During the past years, I have written quite a few Wiki pages on a public MediaWiki server,
and I wanted to back up the whole set at once. After I amend a page or create a new one,
I want to re-run the backup process without too much fuss. This way, if the Wiki server
suddenly disappears, it should be easy to get my pages published again
on the next server that comes along.

Besides, having offline copies of your Wiki pages in several formats allows you to consult,
search or print them without Internet access.
