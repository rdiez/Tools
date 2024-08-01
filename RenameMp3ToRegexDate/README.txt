
The MP3 podcasts from the German public broadcaster WDR 5 used to have sensible filenames,
but nowadays (as of July 2024) they are named something like 3104403_57032996.mp3
or 3146466_58228694.mp3, so that you do not easily see the recording dates or titles.
Furthermore, the "Recorded date" tag inside the files has only the year,
with neither month nor day of the month.

However, the date is usually inside the "Track name" tag, appended as a suffix like "(12.07.2024)".

This script renames the files to their track names, but with the date as a prefix.
The date is captured with a regular expression. I could not figure out
how to do all that with lltag alone, so that is why I wrote this script.

You may find the scanning and renaming techniques implemented in this script useful,
even if your particular scenario is somewhat different.
