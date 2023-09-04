
unpack.sh version 1.19
Copyright (c) 2019-2023 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script unpacks an archive (zip, tarball, ISO image, etc.) into a subdirectory
inside the current directory (or the given destination directory), taking care that:
1) The destination directory does not get littered with many unpacked files.
2) No existing file or subdirectory is accidentaly overwritten.
3) The new file or subdirectory has a reasonable name, and that name
   is displayed at the end.

Rationale:

There are many types of archives, an unpacking each type needs a different
tool with different command-line options. I can never remember them.

All archive types do have something in common: when unpacking,
you never know in advance whether you are going to litter the destination
directory with the extracted files, or whether everything is going into
a subdirectory, and what that subdirectory is going to be called.

Because of that, I have become accustomed to opening such files beforehand
with the current desktop's file manager and archiving tool. Some
file managers, like KDE's Dolphin, often have an "Extract here,
autodetect subfolder" option, but not all do, or maybe the right plug-in
for the file manager is not installed yet. Besides, if you are connected
to a remove server via SSH, you may not have a quick desktop
environment available.

So I felt it was time to write this little script to automate unpacking
in a safe and convenient manner.

This script creates a temporary subdirectory in the destination directory,
unpacks the archive there, and then it checks what files were unpacked.

Many archives in the form program-version-1.2.3.zip contain a subdirectory
called program-version-1.2.3/ with all other files inside it. This script
will then place that subdirectory program-version-1.2.3/
in the destination directory.

Other archives in the form archive.zip have contain many top-level files.
This script will then unpack those files into an archive/ subdirectory.

If the archive contains just one file, it will be placed in the destination directory.

In any case, if the desired destination file or directory already exists,
this script will not overwrite it. Instead, a temporary directory like
archive-unpacked-wtGQX will be left behind.

In the end, the user will be told where the unpacked archive contents are
and, where appropriate, that the normally-expected unpacked name already existed.

This script is designed for interactive usage and is not suitable
for automated tasks.

For convenience, it is recommended that you place this script
on your PATH. In this respect, see also GenerateLinks.sh in the same Git
repository this script lives in.

Alternative scripts that work in a similar fashion:
  https://github.com/mitsuhiko/unp
  https://github.com/githaff/unpack

Syntax:
  unpack.sh <options...> [--] <archive filename> [optional destination directory]

If the destination directory is not given, the current directory is used.

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently 1.19)
 --license  prints license information

Usage example:
  unpack.sh archive.zip

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

