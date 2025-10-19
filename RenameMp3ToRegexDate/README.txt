

RenameMp3ToRegexDate.sh

  The MP3 podcasts from the German public broadcaster WDR 5 used to have sensible filenames,
  but nowadays (as of July 2024) they are named something like 3104403_57032996.mp3
  or 3146466_58228694.mp3, so that you do not easily see the recording dates or titles.
  Furthermore, the "Recorded date" tag inside the files has only the year,
  with neither month nor day of the month.

  However, the date is usually inside the "Track name" tag, appended as a suffix like "(12.07.2024)".

  This script renames the files to their track names, but with the date as a prefix.
  The date is captured with a regular expression. I could not figure out
  how to do all that with lltag alone, so that is why I wrote this script.

  Any invalid characters under Windows or FAT32 are replaced,
  so that you can copy your MP3 files to any USB memory stick or MP3 player without worries.

  You may find the scanning and renaming techniques implemented in this script useful,
  even if your particular scenario is somewhat different.


RenameAndMove.sh

  The MP3 podcasts "Der Tag" from the German public broadcaster "Deutschlandfunk"
  have half-witted filenames like:

    episode_title_dlf_20250102_2000_random_suffix.mp3

  I wanted a common prefix followed by the timestamp, so that you can easily
  sort the episodes by source and date. The format should be then:

    dlf_20250102_2000_episode_title_random_suffix.mp3

  This script performs such renaming in a robust manner: if it finds filenames
  which do not fit the expected naming format, it will fail.
  This way, you will notice if the podcast changes the filename format,
  instead of the script simply silently stoping to work properly.

  Any invalid characters under Windows or FAT32 are replaced,
  so that you can copy your MP3 files to any USB memory stick or MP3 player without worries.

  You may find the scanning and renaming techniques implemented in this script useful,
  even if your particular scenario is somewhat different.
