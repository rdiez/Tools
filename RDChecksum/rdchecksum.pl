#!/usr/bin/perl

# The following POD section contains placeholders, so it has to be preprocessed by this script first.
#
# HelpBeginMarker

=head1 OVERVIEW

PROGRAM_NAME version SCRIPT_VERSION

Creates, updates or verifies a list of file checksums (hashes).

=head1 RATIONALE

In an ideal world, all filesystems would have integrated data checksums like ZFS does.
This tool is a poor man's substitute for such filesystem-level checksums.
It can also help detect data corruption when transferring files over a network.

Storage devices are supposed to use checksums to detect or even correct data errors,
and most data transport protocols should do the same. However, computer systems are becoming
more complex and more brittle at the same time, often due to economic pressure.

As a result, I have very rarely performed a large backup or file copy operation without hitting some data
integrity issue. For example, interrupting with Ctrl+C an rsync transfer to an SMB network share
tends to corrupt the destination files, and resuming the transfer will not fix such corruption.

There are many alternative checksum/hash tools around, but I decided to write a new one out of frustration
with the existing software. Advantages of this tool are:

=over

=item *

Checksum list file update

If only a few files have changed, there is no need to checksum all of them again.
None of the other checksum tools I know of have this feature.
I actually wrote this tool because I found that very irritating.

See option I<< --OPT_NAME_UPDATES< > >>.

=item *

Resumable verification.

I often verify large amounts of data on conventional hard disks, and it can take hours to complete.
But sometimes I need to interrupt the process, or perhaps I inadvertently close the wrong terminal window.
All other checksum tools I know will then restart from scratch, which is very annoying, as it is
an unnecessary waste of my precious time.

See option I<< --OPT_NAME_RESUME_FROM_LINES< > >>.

=item *

It is possible to automate the processing of files that failed verification.

The verification report file has a legible but strict data format. An automated tool
can parse it and, for example, copy all failed files again.

=back

Instead of using a checksum/hash tool, you could use an intrusion detection tool
like Tripwire, AIDE, Samhain, afick, OSSEC or integrit,
as most of them can also checksum files and test for changes on demand.
However, I tried or evaluated a few such tools and found them rather user unfriendly and not flexible enough.

For disadvantages and other issues of PROGRAM_NAME see the CAVEATS section below.

=head1 USAGE

 SCRIPT_NAME --OPT_NAME_CREATE [options] [--] [directory]

 SCRIPT_NAME --OPT_NAME_UPDATE [options] [--] [directory]

 SCRIPT_NAME --OPT_NAME_VERIFY [options]

Argument 'directory' is optional and defaults to the current directory ('.').

If 'directory' is the current directory ('.'), then the filenames in the checksum list file will be like 'file.txt'.
Otherwise, the filenames will be like 'directory/file.txt'.

The directory path is not normalised, except for removing any trailing slashes. For example, "file.txt" and "././file.txt"
will be considered different files.

The specified directory will be scanned for files, and then each subdirectory will be recursively scanned.
The resulting order looks like this:

 dir1/file1.txt
 dir1/file2.txt
 dir1/subdir1/file.txt
 dir1/subdir1/subdir/file.txt
 dir1/subdir2/file.txt

The checksum list file itself (DEFAULT_CHECKSUM_FILENAME by default) and any other temporary files with that basename
will be automatically skipped from the checksum list file (assuming that the checksum list filename's basedir and
argument 'directory' match, because mixing relative and absolute paths will confuse the script).

Usage examples:

 cd somewhere && SCRIPT_NAME --OPT_NAME_CREATE

 cd somewhere && SCRIPT_NAME --OPT_NAME_VERIFY

=head1 OPTIONS

Command-line options are read from environment variable I<< OPT_ENV_VAR_NAME >> first, and then from the command line.

=over

=item *

B<-h, --OPT_NAME_HELP>

Print this help text.

=item *

B<--help-pod>

Preprocess and print the POD section. Useful to generate the README.pod file.

=item *

B<--version>

Print this tool's name and version number (SCRIPT_VERSION).

=item *

B<--license>

Print the license.

=item *

B<< --OPT_NAME_SELF_TEST >>

Run the built-in self-tests.

=item *

B<-->

Terminate options processing. Useful to avoid confusion between options and filenames
that begin with a hyphen ('-'). Recommended when calling this script from another script,
where the filename comes from a variable or from user input.

=item *

B<< --OPT_NAME_CREATE  >>

Creates a checksum list file.

Non-regular files, such as FIFOs (named pipes), will be automatically skipped.

When creating a checksum list file named F<< DEFAULT_CHECKSUM_FILENAME >>S< >, a temporary file named F<< DEFAULT_CHECKSUM_FILENAME.IN_PROGRESS_EXTENSION >>
will also be created. If this script is interrupted, the temporary file will remain behind.

=item *

B<< --OPT_NAME_UPDATE  >>

Updates a checksum list file.

Files that do not exist anymore on disk will be deleted from the checksum list file, and new files will be added.

For those files that are still on disk, their checksums will only be updated if their sizes or I<< last modified >> timestamps have changed.

Make sure you pass the same directory as you did when creating the checksum list file. Otherwise, all files will be checksummed again.

When updating a checksum list file named F<< DEFAULT_CHECKSUM_FILENAME >>S< >, a temporary file named F<< DEFAULT_CHECKSUM_FILENAME.IN_PROGRESS_EXTENSION >>
will also be created. If this script is interrupted, the temporary file will remain behind. If the update succeeds, the previous file will
be renamed to F<< DEFAULT_CHECKSUM_FILENAME.BACKUP_EXTENSION >>S< >.

=item *

B<< --OPT_NAME_VERIFY  >>

Verifies the files listed in the checksum list file.

A report file named F<< DEFAULT_CHECKSUM_FILENAME.VERIFICATION_REPORT_EXTENSION >> will be created. Only failed files will show up in the report.

It is possible to parse the report in order to automatically process the files that failed verification.

Temporary files F<< DEFAULT_CHECKSUM_FILENAME.VERIFICATION_RESUME_EXTENSION >> and
F<< DEFAULT_CHECKSUM_FILENAME.VERIFICATION_RESUME_EXTENSION_TMP >> will be created and may remain behind if the script gets killed.
See I<< --OPT_NAME_RESUME_FROM_LINE >> for more information.

You may want to flush the disk cache before verifying. Otherwise, you may be testing some of the files
from memory, so you wouldn't notice if they are actually corrupt on disk.

=item *

B<< --checksum-file=filename >>

Specifies the checksum list file to create, update or verify.

The default filename is F<< DEFAULT_CHECKSUM_FILENAMES< > >>.

=item *

B<< --checksum-type=xxx >>

Supported checksum types are:

=over

=item * I<< CHECKSUM_TYPE_CRC_32 >>

Unsafe for protecting against intentional modification.

=item * I<< CHECKSUM_TYPE_ADLER_32 >>

Faster than CHECKSUM_TYPE_CRC_32, but weak for small files. Unsafe for protecting against intentional modification.

=item * I<< CHECKSUM_TYPE_NONE >>

No checksum will be calculated or verified. Only the file metadata (size and I<< last modified >> timestamp) will be used.

=back

The default checksum type is I<< DEFAULT_CHECKSUM_TYPE >>. This option's argument is case insensitive.

Changes in the checksum type only take effect when a checksum is recalculated for a file.
Existing entries in the checksum list file will not be modified.
Therefore, you may want to recreate the checksum list file from scratch if you select a different checksum type.

=item *

B<< --OPT_NAME_RESUME_FROM_LINE=n >>

Before starting verification, skip (nS< >-S< >1) text lines at the beginning of F<< DEFAULT_CHECKSUM_FILENAME >>S< >.
This option allows you to manually resume a previous, unfinished verification.

During verification, file F<< DEFAULT_CHECKSUM_FILENAME.VERIFICATION_RESUME_EXTENSION >> is created and periodically updated
with the latest verified line number. The update period is one minute. In order to guarantee an atomic update,
temporary file F<< DEFAULT_CHECKSUM_FILENAME.VERIFICATION_RESUME_EXTENSION_TMP >> will be created and then moved
to the final filename.

If verification is completed, F<< DEFAULT_CHECKSUM_FILENAME.VERIFICATION_RESUME_EXTENSION >> is automatically deleted, but
if verification is interrupted, F<< DEFAULT_CHECKSUM_FILENAME.VERIFICATION_RESUME_EXTENSION >> will remind behind
and will contain the line number you can resume from. It the script gets suddenly killed and cannot gracefully stop,
the line number in that file will lag up to the update period, and the temporary file might also be left behind.

Before resuming, remember to rename or copy the last report file (should you need it), because it will be overwritten,
so you will then lose the list of files that had failed the previous verification attempt.

=item *

B<< --OPT_NAME_VERBOSE >>

Print the name of each file and directory found on disk.

Without this option, operations --OPT_NAME_CREATE, --OPT_NAME_UPDATE and --OPT_NAME_VERIFY display a progress indicator every few seconds.

=item *

B<< --OPT_NAME_NO_UPDATE_MESSAGES >>

During an update, do not display which files in the checksum list file are new, missing or have changed.

=item *

B<< --OPT_NAME_INCLUDE=regex >>

See section FILTERING FILENAMES WITH REGULAR EXPRESSIONS below.

=item *

B<< --OPT_NAME_EXCLUDE=regex >>

See section FILTERING FILENAMES WITH REGULAR EXPRESSIONS below.

=back

=head1 FILTERING FILENAMES WITH REGULAR EXPRESSIONS

Filename filtering only applies to operations --OPT_NAME_CREATE and --OPT_NAME_UPDATES< >.

Say you run this tool as follows:

 SCRIPT_NAME --OPT_NAME_CREATE dir1

The specified directory F<< dir1 >> is not subject to any filtering.

Let us say that the first filename found on disk is F<< dir1/fileA.txt >>S< >.

All --OPT_NAME_INCLUDE and --OPT_NAME_EXCLUDE options are applied as Perl regular expressions against "dir1/fileA.txt",
in the same order as these options are given on the command line. The first expression that matches wins.

If no regular expression matches:

=over

=item *

If all filtering expressions are --OPT_NAME_INCLUDES< >, the file will be excluded.

=item *

If at least one --OPT_NAME_EXCLUDE option is present, the file will be included.

=back

Let us say that a subdirectory named F<< dir1/dir2 >> is also found. Before descending into it, all
--OPT_NAME_INCLUDE and --OPT_NAME_EXCLUDE options are applied against "dir1/dir2/".
Note the trailing slash.

If the directory is excluded, nothing else underneath will be considered anymore.

The regular expression itself is internally converted into UTF-8 first, and is applied against pathnames
that are coded in UTF-8 too, so there should not be any issues with international characters.

=head2 FILTERING EXAMPLES

=over

=item *

Skip files that end with '.jpg':

  --OPT_NAME_EXCLUDE='\.jpg\z'

We are using \z instead of the usual $ to match the end of the filename,
in case the filename contains new-line characters.

Directory names end with a slash ('/'), so they will not match.

The single quoting (') is there just to minimise interference from the shell.
Otherwise, we would have to quote special shell characters such as '\' and '$'.

=item *

Skip files that end with either '.jpg' or '.jpeg':

 --OPT_NAME_EXCLUDE='\.(jpg|jpeg)\z'

=item *

Skip files that end with either '.jpg' or '.jpeg', but case insensitively,
so that .JPG and .jpEg would also match:

 --OPT_NAME_EXCLUDE='(?i)\.(jpg|jpeg)\z'

=item *

Include only files that end with '.txt':

 --OPT_NAME_INCLUDE='/\z'  --OPT_NAME_INCLUDE='\.txt\z'

The /\z rule means "anything that ends with a slash" and allows descending into all subdirectories.
Otherwise, directory names that do not match the .txt rule will be filtered out too.

=item *

Do not descend into any subdirectories:

  --OPT_NAME_EXCLUDE='/\z'

Anything that ends with a slash is a directory.

Matching just a slash anywhere may not work properly, because if there is a starting directory like S<< "my-dir" >>,
then filenames at top-level will be like S<< "my-dir/file.txt" >>. Therefore, the slash needs to match only at the end,
in order to prevent descending into a directory like S<< "my-dir/subdir/" >>.

=item *

Skip all subdirectories named 'tmp':

  --OPT_NAME_EXCLUDE='(\A|/)tmp/\z'

Including a trailing slash after 'tmp' makes sure it only matches directories, and not files.

Expression (\A|/) will match either from the beginning, so "tmp/" will match,
or after a slash, so that a subdirectory like "abc/tmp/" will match too. A name like "/xtmp" will not match.

The \z is there to match the slash only at the end. Otherwise, if the starting directory itself is called "tmp",
then a top-level file like "tmp/file.txt" will be filtered out too. Matching the slash only at the end
avoids the risk of filtering out the starting directory specified on the command line.


=item *

Skip all files which names start with a digit or an ASCII lowecase letter:

  --OPT_NAME_EXCLUDE='(?xx)  (\A|/)  [0-9 a-z]  [^/]*  \z'

(?xx) makes the expression more readable by allowing spaces between components (unquoted spaces will be discarded).

(\A|/) indicates that matching must start right at the beginning of the path, or after a slash.
Otherwise, filenames such as !abc and dir/!abc will also match, even though they start with '!'.

0-9 matches digits, and a-z matches lowercase ASCII letters (there are 26 of them, so letters with diacritical marks
are not included). The brackets [0-9 a-z] mean that one such character must exist.

[^/]* allows for any characters afterwards, as long as it is not a slash. We want to match only filenames,
so any slashes to the right are to be avoided.

\z specifies that the end of the path must come at this point. Without it, other slashes to the right
of the match would still be tolerated.

=back

=head1 EXIT CODE

Exit code: 0 on success, some other value on error or if interrupted by a signal.

=head1 SIGNALS

Reception of signals SIGTERM, SIGINT (usually Ctrl+C) and SIGHUP (usually closing the terminal window)
make this script gracefully stop the current operation. The script then kills itself with the same signal.
Most other signals will kill the script straight away.

SIGHUP will probably not be handled as a normal request to stop if you close the terminal,
because writing to sdtout or stderr will fail immediately and will make this script
quit beforehand.

=head1 USING I<< background.sh >>

It is probably most convenient to run this tool with another script of mine called I<< background.sh >>S< >,
so that it runs with low priority and you get a visual notification when finished. For example:

 background.sh SCRIPT_NAME --OPT_NAME_VERIFY

=head1 CHECKSUM LIST FILE FORMAT

The generated file with the list of checksums looks like this:

 2019-12-31T20:15:01.200  CRC-32  12345678  1,234,567  subdir/file1.txt
 2019-12-31T20:15:01.300  CRC-32  90ABCDEF  2,345,678  subdir/file2.txt

=head1 CAVEATS

=over

=item *

This tools is rather young and could benefit from more options.

If you need more features, drop me a line.

=item *

You can only specify one directory as the starting point.

If you want to process multiple directories on different locations at once,
you can work-around it by placing symlinks to all those directories into a single directory,
and passing that single directory to PROGRAM_NAME.

=item *

When updating a checksum list file, the logic that detects whether a file has changed can be fooled
if you move and rename files around, so that previous filenames and their file sizes still match.
The reason ist that move and rename operations do not change the file's I<< last modified >> timestamp.

This shortcoming is not unique to PROGRAM_NAME, you can fool GNU Make this way too.

=item *

If you move or rename files or directories, this tool will neither detect it nor update the
checksum list file accordingly. The affected files will be processed again from scratch
on the next checksum list file update, as if they were new or missing files.

=item *

The granularity level is one file.

If you data consists of a single huge file, you will not be able to resume an interrupted verification.

=item *

Processing is single threaded.

If you have a very fast SSD and a multicore processor, you will probably be waiting longer than necessary.

When using conventional disks (HDDs), reading several files in parallel would probably only decrease performance,
due to the permanent seeks. So implementing multiprocessing would only really help with SSDs.

This script could also benefit from asynchronous I/O, but that would not bring a lot, because
checksumming is usually pretty fast compared to disk I/O, and because operating systems normally
implement a pretty good "read ahead" optimisation when your program mainly issues
sequential disk reads.

=item *

There is no symbolic link loop detection (protection against circular links).

In such a situation, this tool will run forever.

=item *

Memory usage will be higher than with alternative tools.

The main reason is that this script needs to sort the list of filenames inside each directory traversed,
in order to support the --OPT_NAME_UPDATE operation later on. All filenames in the current directory
are loaded into memory, and part of them will remain in memory while descending to its subdirectories.

Therefore, if you have directories with a huge number of files or subdirectories, you will see increased memory usage.
CPU usage may also be higher than expected due to the sorting operation.

=item *

UTF-8 assumption

This tool assumes that all filenames returned from syscalls like readdir are encoded in UTF-8.

It should be the case in all modern operating systems. There is no other encoding that will actually work in practice anyway.
Note that the Linux kernel does not enforce any particular encoding nor provides encoding information to userspace.

=item *

Running on a native Perl under Microsoft Windows may cause problems.

Support for drive letters like C: when dealing with absolute pathnames is missing.
But this limitation is probably not hard to fix.

There is also the issue of UTF-8 in filenames, but you can probably configure the way Windows
interacts with non-Unicode applications to overcome this problem.

I would be willing to help if you volunteer testing the changes under Windows.

In the meantime, you can always use Cygwin. Windows 10 even has a Linux subsystem nowadays.

=item *

Using PROGRAM_NAME on large amounts of data may flush the Linux filesystem cache and impact
the performance of other processes.

This shortcoming is not unique to PROGRAM_NAME, but to any tool processing lots of file data.
I have written a small summary about this cache flushing issue:

L<< https://rdiez.miraheze.org/wiki/The_Linux_Filesystem_Cache_is_Braindead >>

One way to overcome this issue is to use syscall I<< posix_fadvise >>S< >. Unfortunately,
Perl provides no easy access to it. I have raised a GitHub issue about this:

S<  >Title: Provide access to posix_fadvise

S<  >Link: L<< https://github.com/Perl/perl5/issues/17899 >>

=back

=head1 FEEDBACK

Please send feedback to rdiezmail-tools at yahoo.de

=head1 LICENSE

Copyright (C) 2020-2022 R. Diez

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License version 3 for more details.

You should have received a copy of the GNU Affero General Public License version 3
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

=cut

# HelpEndMarker

use strict;
use warnings;

use Config;
use POSIX qw();
use Encode qw();
use Time::HiRes qw( CLOCK_MONOTONIC );
use Fcntl qw();
use FindBin qw( $Bin $Script );
use Getopt::Long qw( GetOptionsFromString );
use Pod::Usage qw();
use Compress::Zlib qw();
use File::Copy qw();
use File::Spec qw();
use Class::Struct qw();
use Carp qw();


use constant TRUE  => 1;
use constant FALSE => 0;

use constant EXIT_CODE_SUCCESS => 0;
# Beware that other errors, like those from die(), can yield other exit codes.
# It is very hard to guarantee that all possible failures will always yield
# an exit code of 1.
use constant EXIT_CODE_FAILURE => 1;


use constant PROGRAM_NAME => "RDChecksum";
use constant SCRIPT_VERSION => "0.78";

use constant OPT_ENV_VAR_NAME => "RDCHECKSUM_OPTIONS";
use constant DEFAULT_CHECKSUM_FILENAME => "FileChecksums.txt";

use constant IN_PROGRESS_EXTENSION             => "inProgress";
use constant VERIFICATION_REPORT_EXTENSION     => "verification.report";
use constant VERIFICATION_RESUME_EXTENSION     => "verification.resume";
use constant VERIFICATION_RESUME_EXTENSION_TMP => "verification.resume.tmp";
use constant BACKUP_EXTENSION                  => "previous";


use constant FILE_FORMAT_VERSION => "2";

use constant FILE_COMMENT => "#";

use constant FILE_THOUSANDS_SEPARATOR => ",";

use constant FILE_COL_SEPARATOR => "\011";  # Tab, \t, ASCII code 9.

use constant FILE_LINE_SEP => "\012";  # "\n" is defined in Perl as "logical newline". Avoid eventual portability
                                       # problems by using its ASCII code. Name: LF, decimal: 10, hex: 0x0A.

use constant FILE_FIRST_LINE_PREFIX      => PROGRAM_NAME . " - list of checksums - file format version ";

use constant REPORT_FIRST_LINE_PREFIX    => PROGRAM_NAME . " - verification report - file format version ";

use constant KEY_VALUE_FIRST_LINE_PREFIX => PROGRAM_NAME . " - key-value storage - file format version ";

use constant KEY_VERIFICATION_RESUME_LINE_NUMBER => "VerificationResumeLineNumber";

# The UTF-8 BOM actually consists of 3 bytes: EF, BB, BF.
# However, the UTF-8 I/O layer that we are using will convert it to/from U+FEFF.
use constant UTF8_BOM => "\x{FEFF}";
use constant UTF8_BOM_AS_BYTES => "\xEF\xBB\xBF";

# I am finding Unicode support in Perl hard. Most of my strings are ASCII, so there usually is no trouble. But then a
# Unicode character comes up, and suddenly writing text to stdout produces garbage characters and Perl issues a warning
# about it.
#
# So I have come up with an assertion strategy: during development, I enable my "UTF-8 asserts", so that I verify that
# strings are flagged as native or as UTF-8 at the places where they should be. This has helped me prevent errors,
# as this catches strings that have not been properly encoded/decoded even if they only contain low (ASCII) characters .
#
# The only problem I found is substr, which resets the UTF-8 flag if the extracted string contains only low (ASCII) characters.
# I have raised a GitHub issue about this, see routine remove_eventual_trailing_directory_separators() below for more information.
#
# Do not enable these assertions for production, because Perl's internal behaviour may change and still
# remain compatible, breaking the checks but not really affecting functionality.
use constant ENABLE_UTF8_RESEARCH_CHECKS => FALSE;

use constant OPERATION_CREATE => 1;
use constant OPERATION_VERIFY => 2;
use constant OPERATION_UPDATE => 3;

use constant CHECKSUM_TYPE_ADLER_32 => "Adler-32";
use constant CHECKSUM_TYPE_CRC_32   => "CRC-32";
use constant CHECKSUM_TYPE_NONE     => "none";
use constant DEFAULT_CHECKSUM_TYPE => CHECKSUM_TYPE_CRC_32;

use constant CHECKSUM_IF_NONE => "none";

use constant PROGRESS_DELAY => 4;  # In seconds.

use constant OPT_NAME_HELP =>'help';
use constant OPT_NAME_CREATE => "create";
use constant OPT_NAME_VERIFY => "verify";
use constant OPT_NAME_UPDATE => "update";
use constant OPT_NAME_SELF_TEST => "self-test";
use constant OPT_NAME_RESUME_FROM_LINE => "resume-from-line";
use constant OPT_NAME_VERBOSE => "verbose";
use constant OPT_NAME_CHECKSUM_TYPE => "checksum-type";
use constant OPT_NAME_NO_UPDATE_MESSAGES => "no-update-messages";
use constant OPT_NAME_INCLUDE => "include";
use constant OPT_NAME_EXCLUDE => "exclude";


# Returns a true value if the string starts with the given 'prefix' argument.

sub str_starts_with ( $ $ )
{
  my $str    = shift;
  my $prefix = shift;

  if ( length( $str ) < length( $prefix ) )
  {
    return FALSE;
  }

  return substr( $str, 0, length( $prefix ) ) eq $prefix;
}


# Returns a true value if the string ends in the given 'suffix' argument.

sub str_ends_with ( $ $ )
{
  my $str    = shift;
  my $suffix = shift;

  if ( length( $str ) < length( $suffix ) )
  {
    return FALSE;
  }

  return substr( $str, -length( $suffix ), length( $suffix ) ) eq $suffix;
}


# If 'str' starts with the given 'prefix', remove that prefix
# and return a true value.

sub remove_str_prefix ( $ $ )
{
  my $str    = shift;  # Pass here a reference to a string.
  my $prefix = shift;

  # Note that substr() can turn a Perl string marked as UTF-8 to a native/byte string.
  # If this poses problems, it could be possible to cut the string using a regular expression
  # with option {n} for "exactly n occurrences". This way, the UTF-8/native flag would be preserved.
  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $str, "string to remove a prefix from" );
  }

  if ( str_starts_with( $$str, $prefix ) )
  {
    $$str = substr( $$str, length( $prefix ) );
    return TRUE;
  }
  else
  {
    return FALSE;
  }
}


sub str_remove_optional_suffix ( $ $ )
{
  my $str    = shift;
  my $suffix = shift;

  # Note that substr() can turn a Perl string marked as UTF-8 to a native/byte string.
  # If this becomes inconvenient or creates performance problems, it could be possible to cut the string using a
  # regular expression with option {n} for "exactly n occurrences". This way, the UTF-8/native flag would be preserved.
  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $str, "string to remove an optional suffix from" );
  }

  if ( str_ends_with( $str, $suffix ) )
  {
    return substr( $str, 0, length( $str ) - length( $suffix ) );
  }
  else
  {
    return $str;
  }
}


sub remove_eol_from_perl_error ( $ )
{
  # All Perl error messages should end with a new-line character,
  # which is actually defined as a "logical newline".
  # If you are writing the error message to a file, you should remove it first,
  # and then write to the file the specific newline-character you want.
  # This way, you can be sure about the end-of-line character that lands in the file.
  return str_remove_optional_suffix( $_[0], "\n" );
}


sub is_plain_ascii ( $ )
{
  return $_[0] !~ /[^\x00-\x7f]/;
}


sub plural_s ( $ )
{
  return ( $_[0] == 1 ) ? "" : "s";
}


sub are_arrays_of_strings_equal ( $ $ )
{
  my $arrayA = shift;
  my $arrayB = shift;

  if ( scalar( @$arrayA ) !=
       scalar( @$arrayB ) )
  {
    return FALSE;
  }

  for ( my $i = 0; $i < @$arrayA; ++$i )
  {
    if ( $arrayA->[ $i ] ne
         $arrayB->[ $i ] )
    {
      return FALSE;
    }
  }

  return TRUE;
}


# Originally copied from Filesys::DiskUsage, _convert(), and then improved.
# Alternative: "use Number::Bytes::Human;" , but note that not all standard
# Perl distributions come with that module.

use constant HRS_UNIT_SI     => 1;
use constant HRS_UNIT_BINARY => 2;  # IEEE 1541-2002

sub format_human_readable_size ( $ $ $ )
{
  my $size     = shift;
  my $truncate = shift;
  my $units    = shift;

  my $block;
  my @args;

  if ( $units == HRS_UNIT_SI )
  {
    @args = qw/B kB MB GB TB PB EB ZB YB/;
    $block = 1000;
  }
  elsif ( $units == HRS_UNIT_BINARY )
  {
    @args = qw/B KiB MiB GiB TiB PiB EiB ZiB YiB/;
    $block = 1024;
  }
  else
  {
    die "Invalid HRS unit.\n";
  }

  my $are_bytes = TRUE;

  while ( @args && $size > $block )
  {
    $are_bytes = FALSE;
    shift @args;
    $size /= $block;
  }

  if ( !defined( $truncate ) || $are_bytes )
  {
    $size = int( $size );  # Is there a standard rounding function in perl?
  }
  elsif ( $truncate > 0 )
  {
    # We could use here $g_decimalSep .
    $size = sprintf( "%.${truncate}f", $size );
  }

  return "$size $args[0]";
}


sub format_human_friendly_elapsed_time ( $ $ )
{
  # This code is based on a snippet from https://www.perlmonks.org/?node_id=110550

  my $seconds    = shift;
  my $longFormat = shift;

  use integer;

  my ( $weeks, $days, $hours, $minutes, $sign, $res ) = qw/0 0 0 0 0/;

  $sign = $seconds == abs $seconds ? '' : '-';
  $seconds = abs $seconds;

  my $separator = $longFormat
                    ? ', '
                    : ' ';

  ( $seconds, $minutes ) = ( $seconds % 60, $seconds / 60 ) if $seconds;
  ( $minutes, $hours   ) = ( $minutes % 60, $minutes / 60 ) if $minutes;
  ( $hours  , $days    ) = ( $hours   % 24, $hours   / 24 ) if $hours  ;
  ( $days   , $weeks   ) = ( $days    %  7, $days    /  7 ) if $days   ;

  $res = sprintf ( '%d %s'              , $seconds, $longFormat ? "second" . plural_s( $seconds ) : "s" );
  $res = sprintf ( "%d %s$separator$res", $minutes, $longFormat ? "minute" . plural_s( $minutes ) : "m" ) if $minutes or $hours or $days or $weeks;
  $res = sprintf ( "%d %s$separator$res", $hours  , $longFormat ? "hour"   . plural_s( $hours   ) : "h" ) if             $hours or $days or $weeks;
  $res = sprintf ( "%d %s$separator$res", $days   , $longFormat ? "day"    . plural_s( $days    ) : "d" ) if                       $days or $weeks;
  $res = sprintf ( "%d %s$separator$res", $weeks  , $longFormat ? "week"   . plural_s( $weeks   ) : "w" ) if                                $weeks;

  return "$sign$res";
}


my $g_thousandsSep;
my $g_decimalSep;
my $g_grouping;

sub init_locale_info ()
{
  my $localeValues = POSIX::localeconv();

  $g_thousandsSep = $localeValues->{ 'thousands_sep' } || ',';
  $g_decimalSep   = $localeValues->{ 'decimal_point' } || '.';

  my $localeGrouping = $localeValues->{ 'grouping' };

  my @allGroupingValues;

  if ( $localeGrouping )
  {
    @allGroupingValues = unpack( "C*", $localeGrouping );
  }
  else
  {
    @allGroupingValues = ( 3 );
  }

  # We are simplifying here by only taking the first grouping value.
  $g_grouping = $allGroupingValues[ 0 ];
}


sub AddThousandsSeparators ( $ $ $ )
{
  my $str          = "$_[0]";  # Just in case, avoid converting any possible integer type to a string several times
                               # in the loop below, so just do it once at the beginning.

  # Note that substr() can turn a Perl string marked as UTF-8 to a native/byte string.
  # If this becomes inconvenient or creates performance problems, it could be possible to cut the string using a
  # regular expression with option {n} for "exactly n occurrences". This way, the UTF-8/native flag would be preserved.
  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $str, "string to add thousands separators to" );
  }

  my $grouping     = $_[1];  # We are only using a single grouping value, but the locale information can actually have several.
  my $thousandsSep = $_[2];

  my $res = "";
  my $i;

  for ( $i = length( $str ) - $grouping; $i > 0; $i -= $grouping )
  {
    $res = $thousandsSep . substr( $str, $i, $grouping ) . $res;
  }

  return substr( $str, 0, $grouping + $i ) . $res;
}


# ------- Unicode helpers, begin -------

sub check_string_is_marked_as_utf8 ( $ $ )
{
  my $str                = shift;
  my $strNameForErrorMsg = shift;

  if ( ! utf8::is_utf8( $str ) )
  {
    die "Internal error: String " . format_str_for_message( $strNameForErrorMsg ) . " is unexpectedly marked as native/byte string." .
        " The string is: " . format_str_for_message( $str ) . "\n";
  }
}

sub check_string_is_marked_as_native ( $ $ )
{
  my $str                = shift;
  my $strNameForErrorMsg = shift;

  if ( utf8::is_utf8( $str ) )
  {
    die "Internal error: String " . format_str_for_message( $strNameForErrorMsg ) . " is unexpectedly marked as UTF-8 string.\n";
  }
}


# I often use this string for test purposes.
use constant TEST_STRING_MARKED_AS_UTF8 => "Unicode character WHITE SMILING FACE: \x{263A}";

# I often use this string for test purposes.
# In order for you to recognise it in error messages:
# The first byte is 195 = 0xC3 = octal 0303, and the second byte is ASCII character '('.
use constant INVALID_UTF8_SEQUENCE => "\xC3\x28";


use constant SYSCALL_ENCODING_ASSUMPTION => 'UTF-8';  # 'UTF-8' in uppercase and with a hyphen means "follow strict UTF-8 decoding rules".

sub convert_native_to_utf8 ( $ )
{
  my $nativeStr = shift;

  # A string such as a filename comes ultimately from readdir and is marked as native/raw byte.
  #
  # We do not know how that string is encoded. Perl does not know. Even the operating system
  # may not know (it may depend on the filesystem encoding, which may not be known).
  #
  # We are assuming here that such strings coming from syscalls are in UTF-8,
  # which is almost always the case on Linux.
  #
  # We need to convert the string to UTF-8 for sorting and other purposes. Even if no conversion
  # is needed, because both source and destination encodings are UTF-8, we still have to mark
  # the Perl string internally as being UTF-8. Otherwise, Perl will treat it like a sequence
  # of bytes without encoding, which will cause problems later on.
  #
  # Such conversion is only necessary if the string contains non-ASCII characters.
  # Plain ASCII characters usually pose no problems.
  #
  # For example, say that you want to write the string to a file which has been
  # opened with ":encoding(UTF-8)". If you write the native/raw byte string directly to that file,
  # Perl knows what the destination file encoding is, but not what the string encoding is.
  # Therefore, Perl will not be able to convert the raw bytes to UTF-8 correctly.
  # Bytes > 127 may be filtered, or you may get runtime warnings.
  #
  # The documentation of Encode::decode() states:
  #   "This function returns the string that results from decoding the scalar value OCTETS,
  #    assumed to be a sequence of octets in ENCODING, into Perl's internal form."
  # That is, [UTF-8 as raw bytes] -> [internal string marked as UTF-8].

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $nativeStr, "\$nativeStr" );
  }

  my $strUtf8;

  eval
  {
    $strUtf8 = Encode::decode( SYSCALL_ENCODING_ASSUMPTION,
                               $nativeStr,
                               Encode::FB_CROAK  # Die with an error message if invalid UTF-8 is found.
                               # Note that, without flag Encode::LEAVE_SRC, variable $nativeStr string gets cleared.
                             );
  };

  my $errorMessage = $@;

  if ( $errorMessage )
  {
    # The error message from Encode::decode() is ugly and leaks the source filename,
    # but there is not much we can do about it. There is a big comment next to a call to Encode::encode()
    # in this script with more information these leaky error messages.
    #
    # This error should rarely happen anyway, because the filenames coming from the system should not be
    # incorrectly encoded, and this should not generate any incorrect encodings either.
    die "Error transcoding string " . format_str_for_message( $nativeStr ) . " from native to UTF-8: ". $errorMessage;
  }


  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_utf8( $strUtf8, "\$strUtf8" );
  }

  return $strUtf8;
}


sub convert_utf8_to_native ( $ )
{
  my $strUtf8 = shift;

  # Sometimes we have a Perl string marked as UTF-8. This happens for example if a text line was read
  # from a file which has been opened with layers ":utf8" or ":encoding(UTF-8)".
  #
  # And then we need to pass that string as a filename to a syscall.
  #
  # We do not know what encoding we should pass to the syscall. Perl does not know.
  # Even the operating system may not know (it may depend on the filesystem encoding,
  # which may not be known).
  #
  # We are assuming here that such strings going into syscalls should be in UTF-8,
  # which is almost always the case on Linux.
  #
  # We need to convert the string to native/raw byte. Even if no conversion is needed,
  # because both source and destination encodings are UTF-8, we still have to mark
  # the Perl string internally as being native/raw byte. Otherwise, Perl will
  # not know how to convert a UTF-8 string when passing it to a syscall.
  # Bytes > 127 may be filtered, or you may get runtime warnings.
  #
  # Such conversion is only necessary if the string contains non-ASCII characters.
  # Plain ASCII characters usually pose no problems.
  #
  # The documentation of Encode::encode() states:
  #   "Encodes the scalar value STRING from Perl's internal form into ENCODING and returns
  #    a sequence of octets."
  # That is, internal -> UTF-8 as raw bytes.

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_utf8( $strUtf8, "\$strUtf8" );
  }

  my $nativeStr;

  eval
  {
    $nativeStr = Encode::encode( SYSCALL_ENCODING_ASSUMPTION,
                                 $strUtf8,
                                 Encode::FB_CROAK  # Die with an error message if invalid UTF-8 is found.
                                 # Note that, without flag Encode::LEAVE_SRC, variable $strUtf8string gets cleared.
                               );
  };

  my $errorMessage = $@;

  if ( $errorMessage )
  {
    # This is an example of an error message that Encode::encode() or its companion Encode::decode() may generate:
    #
    #   utf8 "\xC3" does not map to Unicode at /usr/lib/x86_64-linux-gnu/perl/5.26/Encode.pm line 212, <$fileHandle> line 8.
    #
    # It is not only ugly: it is also leaking the source code filename. The indicated location is also wrong,
    # because the error is not in that file, but in the data read from the file (or wherever).
    # Even if the location were right, it provides no useful information to the end user, possibly confusing him/her.
    # There is not much we can do about it.
    # I even raised a bug about this, because it is not the only place in Perl that unexpectedly leaks
    # internal information:
    #   Unprofessional error messages with source filename and line number
    #   https://github.com/Perl/perl5/issues/17898
    # Unfortunately, I only got negative responses from the Perl community.
    die "Error transcoding string from UTF-8 to native: ". $errorMessage;
  }

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $nativeStr, "\$nativeStr" );
  }

  return $nativeStr;
}


sub convert_raw_bytes_to_native ( $ )
{
  my $binaryData = shift;

  # Sometimes, we have read a string from a file in binary mode, so the string is still marked as native/byte.
  # We know that the file should be encoded in UTF-8, so the string should be valid UTF-8, but we need
  # to check it.
  #
  # Because the source file is encoded in UTF-8, and because we are assuming that Perl's native format is UTF-8 too
  # (see SYSCALL_ENCODING_ASSUMPTION), we do not need an actual conversion to use the string as a filename
  # in a syscall. But we still need to check that the source string has no UTF-8 encoding errors,
  # or Perl will complain later on when working on the string.
  # The only way I found to check is to actually perform a conversion, and then ignoring the result.

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $binaryData, "\$binaryData" );
  }

  if ( SYSCALL_ENCODING_ASSUMPTION ne "UTF-8" )
  {
    die "Internal error: Invalid syscall encoding assumption.\n";
  }

  # Try to convert the string to UTF-8. That will check that there are no encoding errors.

  my $strUtf8;

  eval
  {
    $strUtf8 = Encode::decode( SYSCALL_ENCODING_ASSUMPTION,
                               $binaryData,
                               Encode::FB_CROAK | # Die with an error message if invalid UTF-8 is found.
                               Encode::LEAVE_SRC  # Do not clear variable $nativeStr .
                             );
  };

  my $errorMessage = $@;

  if ( $errorMessage )
  {
    # The error message from Encode::decode() is ugly, but there is not much we can do about it.
    die "Error decoding UTF-8 string: ". $errorMessage;
  }

  # $strUtf8 will be marked to be in UTF-8, so we cannot use this string in syscalls.
  # Therefore, we do not need $strUtf8 anymore.
  # We just use the original string, which we now know is valid UTF-8.

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_utf8( $strUtf8, "\$strUtf8" );
  }

  return $binaryData;
}


sub convert_raw_bytes_to_utf8 ( $ )
{
  my $binaryData = shift;

  # Sometimes, we have read a string from a file in binary mode, so the string is still marked as native/byte.
  # We know that the file should be encoded in UTF-8, so the string should be valid UTF-8, but we need
  # to check it.
  #
  # We have to mark the resulting Perl string internally as being UTF-8. Otherwise, Perl will treat it like a sequence
  # of bytes without encoding, which will cause problems later on. For example, if we try to write
  # a string marked as "native/byte" to a file opened with layer ":utf8", and the string has high characters (>127),
  # we will get encoding warnings or errors.

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $binaryData, "\$binaryData" );
  }

  my $strUtf8;

  eval
  {
    $strUtf8 = Encode::decode( 'UTF-8',
                               $binaryData,
                               Encode::FB_CROAK  # Die with an error message if invalid UTF-8 is found.
                               # Note that, without flag Encode::LEAVE_SRC, variable $binaryData gets cleared.
                             );
  };

  my $errorMessage = $@;

  if ( $errorMessage )
  {
    # The error message from Encode::decode() is ugly, but there is not much we can do about it.
    die "Error decoding UTF-8 string: ". $errorMessage;
  }

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_utf8( $strUtf8, "\$strUtf8" );
  }

  return $strUtf8;
}


# We want to make sure that the sort order does not depend on the platform or on the current locale. Therefore:
# 1) Do not use "use locale;" in this script.
# 2) Make sure that the strings are in UTF-8 when being compared lexicographically. This means that:
#    - Character 'B' comes before 'a', because all uppercase characters come before the lowercase ones.
#    - Character "LATIN CAPITAL LETTER E WITH ACUTE" will not come right after "LATIN CAPITAL LETTER E", but after "Z".

sub lexicographic_utf8_comparator ( $ $ )
{
  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_utf8( $_[0], "string to compare, left" );
    check_string_is_marked_as_utf8( $_[1], "string to compare, right" );
  }

  if ( FALSE )
  {
    write_stdout( "Comparing left : " . $_[0] . "\n" .
                  "Comparing right: " . $_[1] . "\n" );
  }

  return $_[0] cmp $_[1];
}


sub luc_test_case ( $ $ )
{
  my $less    = shift;
  my $greater = shift;

  my $lessUtf8    = convert_raw_bytes_to_utf8( $less    );
  my $greaterUtf8 = convert_raw_bytes_to_utf8( $greater );

  if ( lexicographic_utf8_comparator( $lessUtf8, $greaterUtf8 ) >= 0 )
  {
    Carp::confess( "lexicographic_utf8_comparator test case failed: " .
                   format_str_for_message( convert_utf8_to_native( $lessUtf8 ) ) .
                   " < " .
                   format_str_for_message( convert_utf8_to_native( $greaterUtf8 ) ) .
                   "\n" );
  }
}


sub self_test_lexicographic_utf8_comparator ()
{
  write_stdout( "Testing lexicographic_utf8_comparator()...\n" );

  luc_test_case( "a", "b" );

  luc_test_case( "B", "a" );

  my $capEWithAcute = "\xC3\x89";  # Latin Capital Letter E with Acute (U+00C9), as UTF-8.
  # This Unicode character is a letter but nevertheless comes after all ASCII letters.
  luc_test_case( 'z', $capEWithAcute );
  luc_test_case( 'Z', $capEWithAcute );
}


sub self_test_utf8 ()
{
  write_stdout( "Testing UTF-8...\n" );

  check_string_is_marked_as_utf8( TEST_STRING_MARKED_AS_UTF8, "TEST_STRING_MARKED_AS_UTF8" );

  check_string_is_marked_as_utf8( UTF8_BOM, "UTF8_BOM" );

  check_string_is_marked_as_native( UTF8_BOM_AS_BYTES, "UTF8_BOM_AS_BYTES" );

  self_test_lexicographic_utf8_comparator;
}

# ------- Unicode helpers, end -------


sub write_stdout ( $ )
{
  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $_[0], "text for stdout" );
  }

  ( print STDOUT $_[0] ) or
     die "Error writing to standard output: $!\n";
}

sub write_stderr ( $ )
{
  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $_[0], "text for stderr" );
  }

  ( print STDERR $_[0] ) or
     die "Error writing to standard error: $!\n";
}


sub flush_stdout ()
{
  if ( ! defined( STDOUT->flush() ) )
  {
    # The documentation does not say whether $! is set. I am hoping that it does,
    # because otherwise there is no telling what went wrong.
    die "Error flushing standard output: $!\n";
  }
}

sub flush_stderr ()
{
  if ( ! defined( STDERR->flush() ) )
  {
    # The documentation does not say whether $! is set. I am hoping that it does,
    # because otherwise there is no telling what went wrong.
    die "Error flushing standard error: $!\n";
  }
}

sub flush_file ( $ $ )
{
  my $fileHandle = shift;
  my $filename   = shift;

  if ( ! defined( $fileHandle->flush() ) )
  {
    die "Error flushing file " . format_str_for_message( $filename ) . ": $!\n";
  }
}


# This routine does not include the filename in an eventual error message.

sub open_file_for_binary_reading ( $ )
{
  my $filename = shift;

  open( my $fileHandle, "<", "$filename" )
    or die "Cannot open the file: $!\n";

  binmode( $fileHandle )  # Avoids CRLF conversion.
    or die "Cannot access the file in binary mode: $!\n";

  return $fileHandle;
}


my $textLineWhitespaceExpression = "[\x20\x09]";  # Whitespace is only a space or a tab.

# Read the next line, skipping any empty, whitespace-only or comment lines.
# Leading and trailing whitespace is removed.
#
# Returns 'undef' if end of file is reached.

sub read_text_line ( $ $ )
{
  my $fileHandle = shift;
  my $lineNumber = shift;

  for ( ; ; )
  {
    my $textLine = read_text_line_raw( $fileHandle );

    if ( ! defined( $textLine ) )
    {
      return undef;
    }

    ++$$lineNumber;

    my $withoutLeadingWhitespace = trim_empty_or_comment_text_line( $textLine );

    if ( 0 == length( $withoutLeadingWhitespace ) )
    {
      next;
    }

    my $withoutTrailingWhitespace = $withoutLeadingWhitespace;
    $withoutTrailingWhitespace =~ s/$textLineWhitespaceExpression*\z//;

    if ( FALSE )
    {
      write_stdout( "Resulting text line: <$withoutTrailingWhitespace>\n" );
    }

    return $withoutTrailingWhitespace;
  }
}


# Leading whitespace is removed, but not trailing whitespace.

sub trim_empty_or_comment_text_line ( $ )
{
  my $textLine = shift;

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $textLine, "\$textLine" );
  }

  if ( FALSE )
  {
    write_stdout( "Line read: " . $textLine . "\n" );
  }

  # Strip leading whitespace.
  my $withoutLeadingWhitespace = $textLine;
  $withoutLeadingWhitespace =~ s/\A$textLineWhitespaceExpression*//;

  if ( length( $withoutLeadingWhitespace ) == 0 )
  {
    if ( FALSE )
    {
      write_stdout( "Discarding empty or whitespace-only line.\n" );
    }

    return "";
  }

  if ( str_starts_with( $withoutLeadingWhitespace, FILE_COMMENT ) )
  {
    if ( FALSE )
    {
      write_stdout( "Discarding comment line: $textLine\n" );
    }

    return "";
  }

  return $withoutLeadingWhitespace;
}


sub read_text_line_raw ( $ )
{
  my $filehandle = shift;

  if ( eof( $filehandle ) )
  {
    return undef;
  }

  my $textLine = readline( $filehandle );

  if ( ! defined( $textLine ) )
  {
    die "Error reading a text line: $!\n";
  }

  # Remove the trailing new-line character, if any (the last line may not have any).
  # Accept both Linux and Windows end-of-line characters.
  # Keep in mind that "\n" is defined in Perl as "logical newline". Avoid eventual portability
  # problems by using the its ASCII code. Name: LF, decimal: 10, hex: 0x0A, octal: 012.
  #
  # In this alternative, \R matches anything considered a linebreak sequence by Unicode:
  #   s/\R\z//;

  $textLine =~ s/\015?\012\z//;

  return $textLine;
}


# Arguments:
# - file descriptor to write to
# - filename (for an eventual error message)
# - contents to write to the file.

sub write_to_file ( $ $ $ )
{
  my $fd       = shift;
  my $filename = shift;
  my $data     = shift;

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $filename, "filename in write_to_file" );
  }

  ( print $fd $data) or
    die "Cannot write to file " . format_str_for_message( $filename ) . ": $!\n";
}


# Sometimes we want to generate an error message meant for humans which contains the string
# that caused the error. However, the string that we want to embed in the error message may be problematic:
# 1) It may be too long, rendering the error message unreadable.
# 2) It may have characters that make it difficult to know where the embedded string begins
#    and ends inside the error message.
# 3) It may have ASCII control characters that will cause visualisation problems depending
#    on the terminal or editor.
#
# This routine escapes away any problematic characters, shortens the string if necessary
# and surrounds it in double quotation marks. The resulting string can be safely embedded
# in a larger text.
#
# Examples of such quoted strings:
#   "abc"
#   " abc "
#   "a<TAB>b<CR>c"
#   "a<QUOT>b"
#
# The quoted string is designed for maximum readability, so there is a trade-off:
# it cannot be reliably unquoted, because some encodings are ambiguous. For example,
# a string like 'a<TAB>b' will pass through without any quoting. The receiver will
# have no way to know whether the original string had a single tab character,
# or the 5 characters '<TAB>'.
#
# I have decided to use this ambiguous quoting rules because any other escaping mechanisms
# I know are hard to read or pose more questions, and the focus here is readability in
# informational messages for humans who cannot be bother to read the encodind specification.
#
# Example of hard-to-read or ugly quotation mechanisms:
#   URL encoding: a%30%40%40b
#   Shell: "\"Spaces\ get\ quoted\""
#   Perl Unicode literals: \x{1234}x\x{4567}
#   Perl Unicode literals: \N{U+1234}N\N{U+4567}
#
# Because all quoted characters are <= 127, this routine is safe to use before or after
# converting a string to or from UTF-8.

my %escapeTable =
(
   0  => "NUL",
   1  => "SOH",
   2  => "STX",
   3  => "ETX",
   4  => "EOT",
   5  => "ENQ",
   6  => "ACK",
   7  => "BEL",
   8  => "BS",
   9  => "TAB",  # The ASCII name is actually HT for Horizontal Tab.
  10  => "LF",
  11  => "VT",
  12  => "FF",
  13  => "CR",
  14  => "SO",
  15  => "SI",
  16  => "DLE",
  17  => "DC1",
  18  => "DC2",
  19  => "DC3",
  20  => "DC4",
  21  => "NAK",
  22  => "SYN",
  23  => "ETB",
  24  => "CAN",
  25  => "EM",
  26  => "SUB",
  27  => "ESC",
  28  => "FS",
  29  => "GS",
  30  => "RS",
  31  => "US",  # In octal: 037

  34  => "QUOT", # Double quotation mark, in octal: 042

 127  => "DEL", # In octal: 0177

 # Anything above 127 may display as rubbish in a terminal or in a text editor, depending on the encoding,
 # but it will probably cause no big problems like a line break.
);

sub format_str_for_message ( $ )
{
  my $str = shift;

  $str =~ s/([\000-\037\042\177])/ '<' . $escapeTable{ ord $1 } . '>' /eg;

  # This is some arbitrary length limit. Some people would like to see more text, some less.
  use constant FSFM_MAX_LEN => 300;

  use constant FSFM_SUFFIX => "[...]";

  if ( length( $str ) > FSFM_MAX_LEN )
  {
    my $lenToPreserve = FSFM_MAX_LEN - length( FSFM_SUFFIX );

    if ( FALSE )
    {
      # substr() can turn a Perl string marked as UTF-8 to a native/byte string,
      # so avoid it because we want to support the assertion strategy enabled by ENABLE_UTF8_RESEARCH_CHECKS.
      $str = substr( $str, 0, FSFM_MAX_LEN - length( FSFM_SUFFIX ) ) . FSFM_SUFFIX;
    }
    else
    {
      my @capture = $str =~ m/\A(.{$lenToPreserve})/;

      $str = $capture[ 0 ] . FSFM_SUFFIX;
    }
  }

  return '"' . $str . '"';
}


sub close_or_die ( $ $ )
{
  close ( $_[0] ) or die "Internal error: Cannot close file handle of file " . format_str_for_message( $_[1] ) . ": $!\n";
}


# Say you have the following logic:
# - Open a file.
# - Do something that might fail.
# - Close the file.
#
# If an error occurs between opening and closing the file, you need to
# make sure that you close the file handle before propagating the error upwards.
#
# You should not die() from an eventual error from close(), because we would
# otherwise be hiding the first error that happened. But you should
# generate at least warning, because it is very rare that closing a file handle fails.
# This is usually only the case if it has already been closed (or if there is some
# serious memory corruption).
#
# Writing the warning to stderr may also fail, but you should ignore any such eventual
# error for the same reason.

sub close_file_handle_or_warn ( $ $ )
{
  my $fileHandle = shift;
  my $filename   = shift;

  close( $fileHandle )
    or print STDERR "Warning: Internal error in '$Script': Cannot close file handle of " . format_str_for_message( $filename ) . ": $!\n";
}


sub if_error_close_file_handle_and_rethrow ( $ $ $ )
{
  my $fileHandle       = shift;
  my $filename         = shift;
  my $errorMsgFromEval = shift;

  if ( $errorMsgFromEval )
  {
    close_file_handle_or_warn( $fileHandle, $filename );

    die $errorMsgFromEval;
  }
}


sub close_file_handle_and_rethrow_eventual_error ( $ $ $ )
{
  my $fileHandle       = shift;
  my $filename         = shift;
  my $errorMsgFromEval = shift;

  if_error_close_file_handle_and_rethrow( $fileHandle, $filename, $errorMsgFromEval );

  close_or_die( $fileHandle, $filename );
}


sub move_file ( $ $ )
{
  my $filenameSrc  = shift;
  my $filenameDest = shift;

  if ( ! File::Copy::move( $filenameSrc, $filenameDest ) )
  {
    die "Cannot move file " . format_str_for_message( $filenameSrc ) . " to " . format_str_for_message( $filenameDest ) . ": $!\n";
  }
}


sub delete_file ( $ )
{
  my $filename = shift;

  unlink( $filename )
    or die "Cannot delete file " . format_str_for_message( $filename ) . ": $!\n";
}


sub rethrow_eventual_error_with_filename ( $ $ )
{
  my $filename         = shift;
  my $errorMsgFromEval = shift;

  if ( $errorMsgFromEval )
  {
    # Do not say "file" here, because it could be a directory.
    die "Error accessing " . format_str_for_message( $filename ) . ": $errorMsgFromEval";
  }
}


# An eventual error message will contain the filename.

sub create_or_truncate_file_for_utf8_writing ( $ )
{
  # Layer ":raw" disables the automatic end-of-line handling that the default ":crlf" does.
  # I would rather manually control which end-of-line characters land in the file.

  my $filename = shift;

  open( my $fileHandle, ">:raw:utf8", $filename )
    or die "Cannot create or truncate file " . format_str_for_message( $filename ) . " for writing: $!\n";

  $fileHandle->autoflush( 0 );  # Make sure the file is being buffered, for performance reasons.

  return $fileHandle;
}


# Reads a whole binary file, returns it as a scalar.
#
# Security warning: Any eventual error message will contain the file path.
#
# Alternative: use Perl module File::Slurp

sub read_whole_binary_file ( $ )
{
  my $filename = shift;

  # I believe that standard tool 'cat' uses a 128 KiB buffer size under Linux.
  use constant SOME_ARBITRARY_BLOCK_SIZE_RWBF => 128 * 1024;

  my $fileContent;

  eval
  {
    my $fileHandle = open_file_for_binary_reading( $filename );

    eval
    {
      my $pos = 0;

      for ( ; ; )
      {
        my $readByteCount = sysread( $fileHandle, $fileContent, SOME_ARBITRARY_BLOCK_SIZE_RWBF, $pos );

        if ( not defined $readByteCount )
        {
          die "Error reading from file: $!\n";
        }

        if ( $readByteCount == 0 )
        {
          last;
        }

        $pos += $readByteCount;
      }
    };

    close_file_handle_and_rethrow_eventual_error( $fileHandle, $filename, $@ );
  };

  rethrow_eventual_error_with_filename( $filename, $@ );

  return $fileContent;
}


# ------- Filename escaping, begin -------

# Escape characters such as TAB (\t) to "%09", like URL encoding.

sub escape_filename ( $ )
{
  my $filename = shift;

  # We are escaping the following characters:
  # - percentage (\045), because that is the escape character.
  # - tab (\011), because that is the separator in our file format.
  # - newline (\012), because that could cause visual disruption.
  # - carriage return (\015), because that could cause visual disruption
  # - Any other characters under \040 (ASCII space), because they
  #   may cause visualisation problems.
  # - 'DEL' character, ASCII code 127, (octal \177), because it is
  #   invisible on many terminals.
  # - A single leading and a single trailing space (\040), because:
  #   - Leading and trailing spaces are discarded when reading our file format.
  #   - Leading and trailing spaces in filenames are easy to miss during visual inspection.
  #   - Escaping spaces in the middle hurts readability. After all, leading and trailing
  #     spaces are rare, but they are pretty common in the middle.
  #   - We could escape all leading or trailing spaces, but then a leading " \t " would
  #     yield "%20%09 ", which is not consistent either. Trying to make it more consistent
  #     is probably not worth it.
  #
  # Possible optimisation: URI/Escape.pm uses a hash and may be faster. You may be able
  #                        to optimise it even further by using a look-up array.

  $filename =~ s/([\000-\037\045\177])/ sprintf "%%%02X", ord $1 /eg;

  if ( FALSE )
  {
    # All leading spaces.
    $filename =~ s/\A(\040+)/  "%20" x length( $1 ) /e;
  }
  else
  {
    # A single leading space.
    $filename =~ s/\A\040/%20/;
  }

  if ( FALSE )
  {
    # All trailing spaces.
    $filename =~ s/(\040+)\z/ "%20" x length( $1 ) /e;
  }
  else
  {
    # A single trailing space.
    $filename =~ s/\040\z/%20/;
  }

  return $filename;
}


sub unescape_filename ( $ )
{
  my $filename = shift;

  # This unescaping logic is the same as URI::Escape::uri_unescape().

  # This logic is fast, but not very robust: it does not generate an error
  # for invalid escape sequences. Maybe we should make it more robust.

  $filename =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

  return $filename;
}


sub efname_test_case ( $ $ )
{
  my $strToEscape    = shift;
  my $expectedResult = shift;

  my $escaped = escape_filename( $strToEscape );

  if ( $escaped ne $expectedResult )
  {
    Carp::confess( "Test case for escape_filename() failed for " . format_str_for_message( $strToEscape ) . ".\n" );
  }

  if ( $strToEscape ne unescape_filename( $escaped ) )
  {
    Carp::confess( "Test case for escape_filename(), unescaping, failed for " . format_str_for_message( $strToEscape ) . ".\n" );
  }
}

sub self_test_escape_filename ()
{
  write_stdout( "Testing filename escaping...\n" );

  efname_test_case( "ab", "ab" );

  efname_test_case( "a%b", "a%25b" );

  efname_test_case( "a\tb", "a%09b" );

  # This test make break, because "\n" is defined in Perl as "logical newline", which might not be an LF.
  efname_test_case( "a\nb", "a%0Ab" );

  # Binary zero.
  efname_test_case( "a\x00b", "a%00b" );

  # ASCII 1 and ASCII 31 (under space).
  efname_test_case( "a\x01b", "a%01b" );
  efname_test_case( "a\x1Fb", "a%1Fb" );

  # ASCII 'DEL' character.
  efname_test_case( "a\x7Fb", "a%7Fb" );

  # Only one leading and one trailing space should get escaped.
  efname_test_case( "  ab   ", "%20 ab  %20" );
}


# Escapes the filename so that it does not interfere with normal console operation,
# like some ASCII control codes would do. One leading and/or trailing space is also
# escaped, so that the user sees where the filename begins and where it ends.
# See escape_filename() for more information about what this routine escapes and why.
#
# The user can copy the console output and unescape it to get the exact original filename.
#
# There is no quoting around the filename, so this routine is mostly suitable to
# display filenames at the end of a text line.
#
# Note that there is no limit to the filename length, so that the console line
# may become very long.

sub format_filename_for_console ( $ )
{
  # Our escaping only affects characters < 127, so it does not matter whether
  # the filename string is marked as native or as UTF-8.
  return escape_filename( $_[0] );
}

# ------- Filename escaping, end -------


# ------- Integer parsing, begin -------

# Parse an unsigned integer.
#
# I often have the following requirements:
# - Parse a string as an unsigned integer.
# - The source of the string is untrusted, so proper validation is needed.
# - Parsing has to be fast. The script may be reading hundreds of thousands of such numbers from a file.
# - The result has to be internally stored as an integer, so that:
#   - Subsequent operations on it remain fast.
#   - Avoid the inherent inaccuracies from an eventual internal floating-point format of fixed size.
# - The requirements above already rule out big, complex modules like Math::BigInt.
# - The script should accept the full range of integers supported by the native platform,
#   which is usually 32 or 64 bits. Otherwise, interoperability with other software or data formats
#   using the standard 32-bit or 64-bit value range would be compromised.
#
# The requirements above are nothing special and most computer languages can do it without special considerations.
# It is however surprisingly difficult in Perl. This discussion illustrates how many aspects there are to consider:
#   https://www.perlmonks.org/?node_id=11118650
#
# The following test code shows the root of the problem:
#
#   my $str = "99999999999999999999";
#   print "What the string is: $str\n";
#   my $strAsInteger = int( $str );
#   print "Value of \$strAsInteger: $strAsInteger\n";
#   printf "How printf sees it: %u\n", $strAsInteger;
#
# The result is:
#   What the string is: 99999999999999999999
#   Value of $strAsInteger: 1e+20
#   How printf sees it: 18446744073709551615
#
# There is no sign of a hint, a warning, or anything helpful from Perl there.
#
# In my opinion, this is a serious issue that is probably pervasive across the Perl codebase.
# For example, if you ask Getopt::Long to only allow an integer as a command-line option argument (with "=i"),
# you may get a floating-point value like "1e+42" back, or even "Inf". So you cannot really trust
# Getopt::Long to do a proper integer validation. Some hacker might even find a way to use
# such a weakness to create problems further down the line.

use constant LARGEST_UNSIGNED_INT => ~0;

use constant LARGEST_UNSIGNED_INT_AS_STR => "@{[ LARGEST_UNSIGNED_INT ]}";

if ( FALSE )
{
  write_stdout( "Largest unsigned integer: @{[ LARGEST_UNSIGNED_INT ]}\n" );
}

sub parse_unsigned_integer ( $ )
{
  my $str = shift;

  # There may be a faster way to parse an integer with pack/unpack. Any help is welcome.

  my @capture = $str =~ m/
                         \A               # Start of the string.
                         0*               # Optional leading zeros that are discarded.
                         ([1-9][0-9]*|0)  # Either a lone 0, or some other number which does not start with 0.
                         \z               # End of the string.
                         /x;

  if ( scalar ( @capture ) != 1 )
  {
    die "Invalid unsigned integer number.\n";
  }

  my $intAsStr = $capture[ 0 ];

  if ( length( $intAsStr ) < length( LARGEST_UNSIGNED_INT_AS_STR ) )
  {
    return int( $intAsStr );
  }

  if ( length( $intAsStr ) > length( LARGEST_UNSIGNED_INT_AS_STR ) )
  {
    die "The integer number is too large.\n";
  }


  # A simple lexicographical comparison should do the trick here.

  if ( ( $intAsStr cmp LARGEST_UNSIGNED_INT_AS_STR ) <= 0 )
  {
    return int( $intAsStr );
  }

  die "The integer number is too large.\n";
}


sub pui_test_case_ok ( $ $ )
{
  my $str           = shift;
  my $expectedValue = shift;

  my $value;

  eval
  {
    $value = parse_unsigned_integer( $str );
  };

  my $errorMessage = $@;

  if ( $errorMessage )
  {
    Carp::confess( "Test case failed: Test string " . format_str_for_message( $str ) . " failed to parse as an unsigned integer.\n" );
  }


  use B qw( svref_2object SVf_IOK );

  my $sv = svref_2object( \$value );

  if ( FALSE )
  {
    write_stdout( "Flags: " . $sv->FLAGS . "\n" );
  }

  # Flag SVf_IOK means "has valid public integer value"

  if ( 0 == ( $sv->FLAGS & SVf_IOK ) )
  {
    Carp::confess( "Test case failed: Test string " . format_str_for_message( $str ) . " generated a value that Perl considers not to be an integer.\n" );
  }


  # In case the internal check with SVf_IOK does not work well, check that converting the value to a string
  # still looks like an integer, because it could be a floating point value.
  #
  # Yes, I am being a little paranoid. But who knows if Perl 7 will keep the same internal flags.

  my $asString = "" . $value;

  # This regular expression checks whether the string has non-digits.
  if ( $asString =~ m/[^0-9]/ )
  {
    Carp::confess( "Test case failed: Test string " . format_str_for_message( $str ) .
                   " generated a value that, when converted to string, does not look like an integer: " . format_str_for_message( $asString ) . ".\n" );
  }

  if ( $value != $expectedValue )
  {
    Carp::confess( "Test case failed: Test string " . format_str_for_message( $str ) . " parsed as " .
                   format_str_for_message( $value ) . "  instead of the expected " .
                   format_str_for_message( $expectedValue ) . ".\n" );
  }

  if ( FALSE )
  {
    write_stdout( "Obtained: " . format_str_for_message( $value ) . ", expected: " . format_str_for_message( $expectedValue ) . ".\n" );
  }
}


sub pui_test_case_fail ( $ )
{
  my $str = shift;

  eval
  {
    parse_unsigned_integer( $str );
  };

  my $errorMessage = $@;

  if ( ! $errorMessage )
  {
    Carp::confess( "Test case failed: Test string " . format_str_for_message( $str ) . " did not fail to parse as an unsigned integer as expected.\n" );
  }
}


sub self_test_parse_unsigned_integer ()
{
  write_stdout( "Testing parse_unsigned_integer()...\n" );

  pui_test_case_fail( "" );
  pui_test_case_fail( "a" );
  pui_test_case_fail( "2a" );
  pui_test_case_fail( "a2" );
  pui_test_case_fail( " 123" );
  pui_test_case_fail( "123 " );
  pui_test_case_fail( "-123" );
  pui_test_case_fail( "+123" );

  pui_test_case_ok( "0", 0 );
  pui_test_case_ok( "01", 1 );
  pui_test_case_ok( "0000000000000000000000000001", 1 );
  pui_test_case_ok( "10", 10 );

  # We are assuming that the current Perl interpreter is using 64-bit integers.
  # If that is not the case, you will need to improve this test code.

  pui_test_case_ok( "1000000000000000000", 1000000000000000000 );  # One digit less than the maximum.
  pui_test_case_fail( "100000000000000000000" );  # One digit more than the maximum.
  pui_test_case_fail( "99999999999999999999" );  # The exact example in the comment further above.

  pui_test_case_ok( "18446744073709551614", 18446744073709551614 );  # UINT32_MAX - 1
  pui_test_case_ok( "18446744073709551615", 18446744073709551615 );  # UINT32_MAX
  pui_test_case_fail( "18446744073709551616" );  # UINT32_MAX + 1

  # Leading zeros should not make a difference.
  pui_test_case_ok( "000018446744073709551614", 18446744073709551614 );  # UINT32_MAX - 1
  pui_test_case_ok( "000018446744073709551615", 18446744073709551615 );  # UINT32_MAX
  pui_test_case_fail( "000018446744073709551616" );  # UINT32_MAX + 1

  # A few other values with the maximum amount of digits.
  pui_test_case_ok( "18000000000000000000", 18000000000000000000 );
  pui_test_case_fail( "20000000000000000000" );
  pui_test_case_ok( "10000000000000000000", 10000000000000000000 );

  # Way too big.
  pui_test_case_fail( "9" x 1000 );
}

# ------- Integer parsing, end -------


use constant CURRENT_DIRECTORY => '.';

# This constant must be 1 character long, see the call to chop() below.
use constant DIRECTORY_SEPARATOR => '/';

sub remove_eventual_trailing_directory_separators ( $ )
{
  my $dirname = shift;

  # We want to respect the [UTF-8 / native] flag in the Perl string,
  # in order to support the assertion strategy I am using, see ENABLE_UTF8_RESEARCH_CHECKS.
  # Therefore, we cannot use substr in this routine.
  #
  # I have raised a GitHub issue about substr behaving like this, which is
  # inconsistent and will probably cause performance losses in many situations. It is here:
  #
  #  https://github.com/Perl/perl5/issues/17897
  #  substr should respect the UTF-8 flag
  #
  # Unfortunately, I only got irrelevant or negative feedback from the Perl community.

  # A regular expression would probably be faster, but there is normally just one separator,
  # so optimising is not worth it.

  for ( ; ; )
  {
    # If the dirname is just "/", it refers to the root directory, and we must not change it.

    if ( $dirname eq DIRECTORY_SEPARATOR )
    {
      last;
    }

    if ( ! str_ends_with( $dirname, DIRECTORY_SEPARATOR ) )
    {
      last;
    }

    chop $dirname;
  }

  return $dirname;
}


# ------- Directory stack routines, begin -------

# Takes a path consisting only of directories, like "dir1/dir2/dir3",
# and breaks it down to an array of strings, like (dir1, dir2, dir3).
#
# We would not need to break up such strings if we could compare them directly.
#
#     This is the kind of paths that we need to compare later on:
#
#     Correct sort order, according to the recursive directory scanning we are using:
#      dir1/dir2
#      dir1-dir2
#      dir10dir2
#
#     Wrong sort order (see below):
#      dir1-dir2
#      dir1/dir2
#      dir10dir2
#
#     The slash ('/') has ASCII code 0x2F, which is greater than the hyphen ('-'),
#     and lower than zero ('0'). If we compared those strings normally, the sort order
#     in the examples above would be wrong.
#
#     So we need to compare each directory component separately.
#     Perl is probably not fast enough to write a routine that compares character
#     by character and takes the '/' separator into account. But I may be wrong.
#
# This routine takes care that a leading '/' is not removed. Otherwise, we would not
# be able to differenciate between absolute and relative paths.
#
# Multiple '/' characters must be collapsed according to according to POSIX, so that "dir1/////dir2"
# yields the same result as "dir1/dir2".
#
# Some systems treat a leading '//' differently. For example, on Cygwin, a path like "//network-share/dir"
# indicates a network mountpoint.
# We are not handling such cases here yet. If you do in the future, beware that it must be exactly 2 slashes,
# according to POSIX:
#  "A pathname that begins with two successive slashes may be interpreted in an implementation-defined manner, although
#   more than two leading slashes shall be treated as a single slash."

sub break_up_dir_only_path ( $ )
{
  my $dirOnlyPath = shift;

  # There is probably a better or faster way to break up a directory path.

  my @splitResult = File::Spec->splitdir( $dirOnlyPath );

  my @dirs;

  # Handle any leading '/' as a special case, because otherwise we would lose it.

  if ( FALSE )
  {
    # If the original Perl string was marked as UTF-8, we should generate directory
    # components which are marked as UTF-8 too, but this code does not.

    if ( str_starts_with( $dirOnlyPath, DIRECTORY_SEPARATOR ) )
    {
      if ( TRUE )
      {
        # This always yiels a Perl string marked as "native".
        push @dirs, DIRECTORY_SEPARATOR;
      }
      else
      {
        # This always yiels a Perl string marked as "native", even though it should not
        # if $dirOnlyPath is marked as UTF-8.
        # I have tested it with the Perl version v5.26.1 that comes with Ubuntu 18.04.4.
        push @dirs, substr( $dirOnlyPath, 0, length( DIRECTORY_SEPARATOR ) );
      }
    }
  }
  else
  {
    # If we capture an eventual leading '/' character with a regular expression,
    # the string type (UTF-8 or native) is respected.
    my $dirSepQuoted = quotemeta( DIRECTORY_SEPARATOR );

    my @capturedDirSep = $dirOnlyPath =~ m/\A($dirSepQuoted)/;

    if ( scalar( @capturedDirSep ) != 0 )
    {
      push @dirs, $capturedDirSep[0];
    }
  }


  foreach my $d ( @splitResult )
  {
    # Strings like "a//b" generate an empty component in the middle,
    # between the two slashes. Discard such empty components.

    if ( length( $d ) != 0 )
    {
      push @dirs, $d;
    }
  }

  return @dirs;
}


sub budop_test_case ( $ $ )
{
  my $dirOnlyPath    = shift;
  my $expectedResult = shift;

  my @expectedResultUtf8;

  foreach my $str ( @$expectedResult )
  {
    push @expectedResultUtf8, convert_native_to_utf8( $str );
  }

  my @resultUtf8 = break_up_dir_only_path( convert_native_to_utf8( $dirOnlyPath ) );

  if ( ! are_arrays_of_strings_equal( \@resultUtf8, \@expectedResultUtf8 ) )
  {
    write_stdout( "Test case failed:\n" );
    print_dir_stack_utf8( "Result"   , \@resultUtf8 );
    print_dir_stack_utf8( "Expected ", \@expectedResultUtf8 );
    Carp::confess( "Test case failed, see above.\n" );
  }
}


sub self_test_break_up_dir_only_path ()
{
  write_stdout( "Testing break_up_dir_only_path()...\n" );

  # Test cases without a leading '/'.

  budop_test_case( ".", [qw( . )] );

  budop_test_case( "a", [qw( a )] );

  budop_test_case( "a/", [qw( a )] );

  budop_test_case( "a/.", [qw( a . )] );

  budop_test_case( "a/..", [qw( a .. )] );

  budop_test_case( "a/../", [qw( a .. )] );

  budop_test_case( "a/..//", [qw( a .. )] );

  budop_test_case( "a/b/c", [qw( a b c )] );

  budop_test_case( "a//b///c", [qw( a b c )] );

  budop_test_case( "a/../b///..///c", [qw( a .. b .. c )] );


  # Test cases with a leading '/'.

  budop_test_case( "/", [qw( / )] );

  budop_test_case( "/.", [qw( / . )] );

  budop_test_case( "/a", [qw( / a )] );

  # This case could be different in the future, if we implement the special
  # case for a leading "//".
  budop_test_case( "//a", [qw( / a )] );

  budop_test_case( "///a", [qw( / a )] );

  budop_test_case( "/./a", [qw( / . a)] );

  budop_test_case( "/.//a", [qw( / . a)] );

  budop_test_case( "/a//b///c", [qw( / a b c )] );

  budop_test_case( "/a/../b///..///c", [qw( / a .. b .. c )] );
}


# I have kept this routine because it can be useful to debug problems
# in the logic that handles directory stacks.

sub print_dir_stack_utf8 ( $ $ )
{
  my $prefixStr = shift;
  my $arrayRef  = shift;

  my $elemCount = scalar @$arrayRef;

  if ( $elemCount == 0 )
  {
    write_stdout( "$prefixStr stack: <empty>\n" );
    return;
  }

  write_stdout( "$prefixStr stack:\n" );

  for ( my $i = 0; $i < $elemCount; ++$i )
  {
    my $msgUtf8 = "- Elem " . ($i + 1) . ": " . format_filename_for_console( $arrayRef->[ $i ] ) . "\n";

    write_stdout( convert_utf8_to_native( $msgUtf8 ) );
  }
}


sub compare_directory_stacks ( $ $ )
{
  my $arrayRefA = shift;
  my $arrayRefB = shift;

  my $arrayALen = scalar @$arrayRefA;
  my $arrayBLen = scalar @$arrayRefB;

  for ( my $i = 0; ; ++$i )
  {
    if ( $i == $arrayALen )
    {
      if ( $i == $arrayBLen )
      {
        return 0;
      }
      elsif ( $i < $arrayBLen )
      {
        return -1;
      }
      else
      {
        die "Internal error in function " . (caller(0))[3] . "\n";
      }
    }

    if ( $i == $arrayBLen )
    {
      if ( $i < $arrayALen )
      {
        return +1;
      }
      else
      {
        die "Internal error in function " . (caller(0))[3] . "\n";
      }
    }

    my $comparisonResult = lexicographic_utf8_comparator( $arrayRefA->[ $i ],
                                                          $arrayRefB->[ $i ] );
    if ( $comparisonResult != 0 )
    {
      return $comparisonResult;
    }
  }
}

# ------- Directory stack routines, end -------


# ------- Command-line options helpers, begin -------

sub check_multiple_incompatible_options ( $ $ $ )
{
  my $isOptionPresent    = shift;
  my $optionName         = shift;
  my $previousOptionName = shift;

  if ( ! $isOptionPresent )
  {
    return;
  }

  if ( $$previousOptionName )
  {
    die "Option '$optionName' is incompatible with option '$$previousOptionName'.\n";
  }

  $$previousOptionName = $optionName;
}


sub check_single_incompatible_option ( $ $ $ $ )
{
  my $isOption1Present = shift;
  my $option1Name      = shift;

  my $isOption2Present = shift;
  my $option2Name      = shift;

  if ( ! $isOption1Present ||
       ! $isOption2Present )
  {
    return;
  }

  die "Option '$option1Name' is incompatible with option '$option2Name'.\n";
}


sub check_is_only_compatible_with_option ( $ $ $ )
{
  my $presentOptionName           = shift;
  my $isPrerequisiteOptionPresent = shift;
  my $prerequisiteOptionName      = shift;

  if ( ! $isPrerequisiteOptionPresent )
  {
    die "Option '$presentOptionName' is only compatible with option '$prerequisiteOptionName'.\n";
  }
}

# ------- Command-line options helpers, end -------


sub get_pod_from_this_script ()
{
  # POSSIBLE OPTIMISATION:
  #   We do not actually need to read the whole file. We could read line-by-line,
  #   discard everything before HelpBeginMarker and stop as soon as HelpEndMarker is found.

  my $sourceCodeOfThisScriptAsString = read_whole_binary_file( "$Bin/$Script" );

  # We do not actually need to isolate the POD section, but it is cleaner this way.

  my $regex = "# HelpBeginMarker[\\s]+(.*?)[\\s]+# HelpEndMarker";

  my @podParts = $sourceCodeOfThisScriptAsString =~ m/$regex/s;

  if ( scalar( @podParts ) != 1 )
  {
    die "Internal error isolating the POD documentation.\n";
  }

  my $podAsStr = $podParts[0];


  # Replace the known placeholders. This is the only practical way to make sure
  # that things like the script name and version number in the help text are always right.
  # If you duplicate name and version in the source code and in the help text,
  # they will inevitably get out of sync at some point in time.

  # There are faster ways to replace multiple placeholders, but optimising this
  # is not worth the effort.

  $podAsStr =~ s/PROGRAM_NAME/@{[ PROGRAM_NAME ]}/gs;
  $podAsStr =~ s/SCRIPT_NAME/$Script/gs;
  $podAsStr =~ s/SCRIPT_VERSION/@{[ SCRIPT_VERSION ]}/gs;
  $podAsStr =~ s/OPT_NAME_HELP/@{[ OPT_NAME_HELP ]}/gs;

  $podAsStr =~ s/CHECKSUM_TYPE_CRC_32/@{[ CHECKSUM_TYPE_CRC_32 ]}/gs;
  $podAsStr =~ s/CHECKSUM_TYPE_ADLER_32/@{[ CHECKSUM_TYPE_ADLER_32 ]}/gs;
  $podAsStr =~ s/CHECKSUM_TYPE_NONE/@{[ CHECKSUM_TYPE_NONE ]}/gs;
  $podAsStr =~ s/DEFAULT_CHECKSUM_TYPE/@{[ DEFAULT_CHECKSUM_TYPE ]}/gs;

  return replace_script_specific_help_placeholders( $podAsStr );
}


sub print_help_text ()
{
  my $podAsStr = get_pod_from_this_script();


  # Prepare an in-memory file with the POD contents.

  my $memFileWithPodContents;

  open( my $memFileWithPod, '+>', \$memFileWithPodContents )
    or die "Cannot create in-memory file: $!\n";

  binmode( $memFileWithPod )  # Avoids CRLF conversion.
    or die "Cannot access in-memory file in binary mode: $!\n";

  ( print $memFileWithPod $podAsStr ) or
    die "Error writing to in-memory file: $!\n";

  seek $memFileWithPod, 0, 0
    or die "Cannot seek inside in-memory file: $!\n";


  write_stdout( "\n" );

  # Unfortunately, pod2usage does not return any error indication.
  # However, if the POD text has syntax errors, the user will see
  # error messages in a "POD ERRORS" section at the end of the output.

  Pod::Usage::pod2usage( -exitval    => "NOEXIT",
                         -verbose    => 2,
                         -noperldoc  => 1,  # Perl does not come with the perl-doc package as standard (at least on Debian 4.0).
                         -input      => $memFileWithPod,
                         -output     => \*STDOUT );

  $memFileWithPod->close()
    or die "Cannot close in-memory file: $!\n";
}


sub get_license_text ()
{
  return ( <<EOL

                    GNU AFFERO GENERAL PUBLIC LICENSE
                       Version 3, 19 November 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

                            Preamble

  The GNU Affero General Public License is a free, copyleft license for
software and other kinds of works, specifically designed to ensure
cooperation with the community in the case of network server software.

  The licenses for most software and other practical works are designed
to take away your freedom to share and change the works.  By contrast,
our General Public Licenses are intended to guarantee your freedom to
share and change all versions of a program--to make sure it remains free
software for all its users.

  When we speak of free software, we are referring to freedom, not
price.  Our General Public Licenses are designed to make sure that you
have the freedom to distribute copies of free software (and charge for
them if you wish), that you receive source code or can get it if you
want it, that you can change the software or use pieces of it in new
free programs, and that you know you can do these things.

  Developers that use our General Public Licenses protect your rights
with two steps: (1) assert copyright on the software, and (2) offer
you this License which gives you legal permission to copy, distribute
and/or modify the software.

  A secondary benefit of defending all users' freedom is that
improvements made in alternate versions of the program, if they
receive widespread use, become available for other developers to
incorporate.  Many developers of free software are heartened and
encouraged by the resulting cooperation.  However, in the case of
software used on network servers, this result may fail to come about.
The GNU General Public License permits making a modified version and
letting the public access it on a server without ever releasing its
source code to the public.

  The GNU Affero General Public License is designed specifically to
ensure that, in such cases, the modified source code becomes available
to the community.  It requires the operator of a network server to
provide the source code of the modified version running there to the
users of that server.  Therefore, public use of a modified version, on
a publicly accessible server, gives the public access to the source
code of the modified version.

  An older license, called the Affero General Public License and
published by Affero, was designed to accomplish similar goals.  This is
a different license, not a version of the Affero GPL, but Affero has
released a new version of the Affero GPL which permits relicensing under
this license.

  The precise terms and conditions for copying, distribution and
modification follow.

                       TERMS AND CONDITIONS

  0. Definitions.

  "This License" refers to version 3 of the GNU Affero General Public License.

  "Copyright" also means copyright-like laws that apply to other kinds of
works, such as semiconductor masks.

  "The Program" refers to any copyrightable work licensed under this
License.  Each licensee is addressed as "you".  "Licensees" and
"recipients" may be individuals or organizations.

  To "modify" a work means to copy from or adapt all or part of the work
in a fashion requiring copyright permission, other than the making of an
exact copy.  The resulting work is called a "modified version" of the
earlier work or a work "based on" the earlier work.

  A "covered work" means either the unmodified Program or a work based
on the Program.

  To "propagate" a work means to do anything with it that, without
permission, would make you directly or secondarily liable for
infringement under applicable copyright law, except executing it on a
computer or modifying a private copy.  Propagation includes copying,
distribution (with or without modification), making available to the
public, and in some countries other activities as well.

  To "convey" a work means any kind of propagation that enables other
parties to make or receive copies.  Mere interaction with a user through
a computer network, with no transfer of a copy, is not conveying.

  An interactive user interface displays "Appropriate Legal Notices"
to the extent that it includes a convenient and prominently visible
feature that (1) displays an appropriate copyright notice, and (2)
tells the user that there is no warranty for the work (except to the
extent that warranties are provided), that licensees may convey the
work under this License, and how to view a copy of this License.  If
the interface presents a list of user commands or options, such as a
menu, a prominent item in the list meets this criterion.

  1. Source Code.

  The "source code" for a work means the preferred form of the work
for making modifications to it.  "Object code" means any non-source
form of a work.

  A "Standard Interface" means an interface that either is an official
standard defined by a recognized standards body, or, in the case of
interfaces specified for a particular programming language, one that
is widely used among developers working in that language.

  The "System Libraries" of an executable work include anything, other
than the work as a whole, that (a) is included in the normal form of
packaging a Major Component, but which is not part of that Major
Component, and (b) serves only to enable use of the work with that
Major Component, or to implement a Standard Interface for which an
implementation is available to the public in source code form.  A
"Major Component", in this context, means a major essential component
(kernel, window system, and so on) of the specific operating system
(if any) on which the executable work runs, or a compiler used to
produce the work, or an object code interpreter used to run it.

  The "Corresponding Source" for a work in object code form means all
the source code needed to generate, install, and (for an executable
work) run the object code and to modify the work, including scripts to
control those activities.  However, it does not include the work's
System Libraries, or general-purpose tools or generally available free
programs which are used unmodified in performing those activities but
which are not part of the work.  For example, Corresponding Source
includes interface definition files associated with source files for
the work, and the source code for shared libraries and dynamically
linked subprograms that the work is specifically designed to require,
such as by intimate data communication or control flow between those
subprograms and other parts of the work.

  The Corresponding Source need not include anything that users
can regenerate automatically from other parts of the Corresponding
Source.

  The Corresponding Source for a work in source code form is that
same work.

  2. Basic Permissions.

  All rights granted under this License are granted for the term of
copyright on the Program, and are irrevocable provided the stated
conditions are met.  This License explicitly affirms your unlimited
permission to run the unmodified Program.  The output from running a
covered work is covered by this License only if the output, given its
content, constitutes a covered work.  This License acknowledges your
rights of fair use or other equivalent, as provided by copyright law.

  You may make, run and propagate covered works that you do not
convey, without conditions so long as your license otherwise remains
in force.  You may convey covered works to others for the sole purpose
of having them make modifications exclusively for you, or provide you
with facilities for running those works, provided that you comply with
the terms of this License in conveying all material for which you do
not control copyright.  Those thus making or running the covered works
for you must do so exclusively on your behalf, under your direction
and control, on terms that prohibit them from making any copies of
your copyrighted material outside their relationship with you.

  Conveying under any other circumstances is permitted solely under
the conditions stated below.  Sublicensing is not allowed; section 10
makes it unnecessary.

  3. Protecting Users' Legal Rights From Anti-Circumvention Law.

  No covered work shall be deemed part of an effective technological
measure under any applicable law fulfilling obligations under article
11 of the WIPO copyright treaty adopted on 20 December 1996, or
similar laws prohibiting or restricting circumvention of such
measures.

  When you convey a covered work, you waive any legal power to forbid
circumvention of technological measures to the extent such circumvention
is effected by exercising rights under this License with respect to
the covered work, and you disclaim any intention to limit operation or
modification of the work as a means of enforcing, against the work's
users, your or third parties' legal rights to forbid circumvention of
technological measures.

  4. Conveying Verbatim Copies.

  You may convey verbatim copies of the Program's source code as you
receive it, in any medium, provided that you conspicuously and
appropriately publish on each copy an appropriate copyright notice;
keep intact all notices stating that this License and any
non-permissive terms added in accord with section 7 apply to the code;
keep intact all notices of the absence of any warranty; and give all
recipients a copy of this License along with the Program.

  You may charge any price or no price for each copy that you convey,
and you may offer support or warranty protection for a fee.

  5. Conveying Modified Source Versions.

  You may convey a work based on the Program, or the modifications to
produce it from the Program, in the form of source code under the
terms of section 4, provided that you also meet all of these conditions:

    a) The work must carry prominent notices stating that you modified
    it, and giving a relevant date.

    b) The work must carry prominent notices stating that it is
    released under this License and any conditions added under section
    7.  This requirement modifies the requirement in section 4 to
    "keep intact all notices".

    c) You must license the entire work, as a whole, under this
    License to anyone who comes into possession of a copy.  This
    License will therefore apply, along with any applicable section 7
    additional terms, to the whole of the work, and all its parts,
    regardless of how they are packaged.  This License gives no
    permission to license the work in any other way, but it does not
    invalidate such permission if you have separately received it.

    d) If the work has interactive user interfaces, each must display
    Appropriate Legal Notices; however, if the Program has interactive
    interfaces that do not display Appropriate Legal Notices, your
    work need not make them do so.

  A compilation of a covered work with other separate and independent
works, which are not by their nature extensions of the covered work,
and which are not combined with it such as to form a larger program,
in or on a volume of a storage or distribution medium, is called an
"aggregate" if the compilation and its resulting copyright are not
used to limit the access or legal rights of the compilation's users
beyond what the individual works permit.  Inclusion of a covered work
in an aggregate does not cause this License to apply to the other
parts of the aggregate.

  6. Conveying Non-Source Forms.

  You may convey a covered work in object code form under the terms
of sections 4 and 5, provided that you also convey the
machine-readable Corresponding Source under the terms of this License,
in one of these ways:

    a) Convey the object code in, or embodied in, a physical product
    (including a physical distribution medium), accompanied by the
    Corresponding Source fixed on a durable physical medium
    customarily used for software interchange.

    b) Convey the object code in, or embodied in, a physical product
    (including a physical distribution medium), accompanied by a
    written offer, valid for at least three years and valid for as
    long as you offer spare parts or customer support for that product
    model, to give anyone who possesses the object code either (1) a
    copy of the Corresponding Source for all the software in the
    product that is covered by this License, on a durable physical
    medium customarily used for software interchange, for a price no
    more than your reasonable cost of physically performing this
    conveying of source, or (2) access to copy the
    Corresponding Source from a network server at no charge.

    c) Convey individual copies of the object code with a copy of the
    written offer to provide the Corresponding Source.  This
    alternative is allowed only occasionally and noncommercially, and
    only if you received the object code with such an offer, in accord
    with subsection 6b.

    d) Convey the object code by offering access from a designated
    place (gratis or for a charge), and offer equivalent access to the
    Corresponding Source in the same way through the same place at no
    further charge.  You need not require recipients to copy the
    Corresponding Source along with the object code.  If the place to
    copy the object code is a network server, the Corresponding Source
    may be on a different server (operated by you or a third party)
    that supports equivalent copying facilities, provided you maintain
    clear directions next to the object code saying where to find the
    Corresponding Source.  Regardless of what server hosts the
    Corresponding Source, you remain obligated to ensure that it is
    available for as long as needed to satisfy these requirements.

    e) Convey the object code using peer-to-peer transmission, provided
    you inform other peers where the object code and Corresponding
    Source of the work are being offered to the general public at no
    charge under subsection 6d.

  A separable portion of the object code, whose source code is excluded
from the Corresponding Source as a System Library, need not be
included in conveying the object code work.

  A "User Product" is either (1) a "consumer product", which means any
tangible personal property which is normally used for personal, family,
or household purposes, or (2) anything designed or sold for incorporation
into a dwelling.  In determining whether a product is a consumer product,
doubtful cases shall be resolved in favor of coverage.  For a particular
product received by a particular user, "normally used" refers to a
typical or common use of that class of product, regardless of the status
of the particular user or of the way in which the particular user
actually uses, or expects or is expected to use, the product.  A product
is a consumer product regardless of whether the product has substantial
commercial, industrial or non-consumer uses, unless such uses represent
the only significant mode of use of the product.

  "Installation Information" for a User Product means any methods,
procedures, authorization keys, or other information required to install
and execute modified versions of a covered work in that User Product from
a modified version of its Corresponding Source.  The information must
suffice to ensure that the continued functioning of the modified object
code is in no case prevented or interfered with solely because
modification has been made.

  If you convey an object code work under this section in, or with, or
specifically for use in, a User Product, and the conveying occurs as
part of a transaction in which the right of possession and use of the
User Product is transferred to the recipient in perpetuity or for a
fixed term (regardless of how the transaction is characterized), the
Corresponding Source conveyed under this section must be accompanied
by the Installation Information.  But this requirement does not apply
if neither you nor any third party retains the ability to install
modified object code on the User Product (for example, the work has
been installed in ROM).

  The requirement to provide Installation Information does not include a
requirement to continue to provide support service, warranty, or updates
for a work that has been modified or installed by the recipient, or for
the User Product in which it has been modified or installed.  Access to a
network may be denied when the modification itself materially and
adversely affects the operation of the network or violates the rules and
protocols for communication across the network.

  Corresponding Source conveyed, and Installation Information provided,
in accord with this section must be in a format that is publicly
documented (and with an implementation available to the public in
source code form), and must require no special password or key for
unpacking, reading or copying.

  7. Additional Terms.

  "Additional permissions" are terms that supplement the terms of this
License by making exceptions from one or more of its conditions.
Additional permissions that are applicable to the entire Program shall
be treated as though they were included in this License, to the extent
that they are valid under applicable law.  If additional permissions
apply only to part of the Program, that part may be used separately
under those permissions, but the entire Program remains governed by
this License without regard to the additional permissions.

  When you convey a copy of a covered work, you may at your option
remove any additional permissions from that copy, or from any part of
it.  (Additional permissions may be written to require their own
removal in certain cases when you modify the work.)  You may place
additional permissions on material, added by you to a covered work,
for which you have or can give appropriate copyright permission.

  Notwithstanding any other provision of this License, for material you
add to a covered work, you may (if authorized by the copyright holders of
that material) supplement the terms of this License with terms:

    a) Disclaiming warranty or limiting liability differently from the
    terms of sections 15 and 16 of this License; or

    b) Requiring preservation of specified reasonable legal notices or
    author attributions in that material or in the Appropriate Legal
    Notices displayed by works containing it; or

    c) Prohibiting misrepresentation of the origin of that material, or
    requiring that modified versions of such material be marked in
    reasonable ways as different from the original version; or

    d) Limiting the use for publicity purposes of names of licensors or
    authors of the material; or

    e) Declining to grant rights under trademark law for use of some
    trade names, trademarks, or service marks; or

    f) Requiring indemnification of licensors and authors of that
    material by anyone who conveys the material (or modified versions of
    it) with contractual assumptions of liability to the recipient, for
    any liability that these contractual assumptions directly impose on
    those licensors and authors.

  All other non-permissive additional terms are considered "further
restrictions" within the meaning of section 10.  If the Program as you
received it, or any part of it, contains a notice stating that it is
governed by this License along with a term that is a further
restriction, you may remove that term.  If a license document contains
a further restriction but permits relicensing or conveying under this
License, you may add to a covered work material governed by the terms
of that license document, provided that the further restriction does
not survive such relicensing or conveying.

  If you add terms to a covered work in accord with this section, you
must place, in the relevant source files, a statement of the
additional terms that apply to those files, or a notice indicating
where to find the applicable terms.

  Additional terms, permissive or non-permissive, may be stated in the
form of a separately written license, or stated as exceptions;
the above requirements apply either way.

  8. Termination.

  You may not propagate or modify a covered work except as expressly
provided under this License.  Any attempt otherwise to propagate or
modify it is void, and will automatically terminate your rights under
this License (including any patent licenses granted under the third
paragraph of section 11).

  However, if you cease all violation of this License, then your
license from a particular copyright holder is reinstated (a)
provisionally, unless and until the copyright holder explicitly and
finally terminates your license, and (b) permanently, if the copyright
holder fails to notify you of the violation by some reasonable means
prior to 60 days after the cessation.

  Moreover, your license from a particular copyright holder is
reinstated permanently if the copyright holder notifies you of the
violation by some reasonable means, this is the first time you have
received notice of violation of this License (for any work) from that
copyright holder, and you cure the violation prior to 30 days after
your receipt of the notice.

  Termination of your rights under this section does not terminate the
licenses of parties who have received copies or rights from you under
this License.  If your rights have been terminated and not permanently
reinstated, you do not qualify to receive new licenses for the same
material under section 10.

  9. Acceptance Not Required for Having Copies.

  You are not required to accept this License in order to receive or
run a copy of the Program.  Ancillary propagation of a covered work
occurring solely as a consequence of using peer-to-peer transmission
to receive a copy likewise does not require acceptance.  However,
nothing other than this License grants you permission to propagate or
modify any covered work.  These actions infringe copyright if you do
not accept this License.  Therefore, by modifying or propagating a
covered work, you indicate your acceptance of this License to do so.

  10. Automatic Licensing of Downstream Recipients.

  Each time you convey a covered work, the recipient automatically
receives a license from the original licensors, to run, modify and
propagate that work, subject to this License.  You are not responsible
for enforcing compliance by third parties with this License.

  An "entity transaction" is a transaction transferring control of an
organization, or substantially all assets of one, or subdividing an
organization, or merging organizations.  If propagation of a covered
work results from an entity transaction, each party to that
transaction who receives a copy of the work also receives whatever
licenses to the work the party's predecessor in interest had or could
give under the previous paragraph, plus a right to possession of the
Corresponding Source of the work from the predecessor in interest, if
the predecessor has it or can get it with reasonable efforts.

  You may not impose any further restrictions on the exercise of the
rights granted or affirmed under this License.  For example, you may
not impose a license fee, royalty, or other charge for exercise of
rights granted under this License, and you may not initiate litigation
(including a cross-claim or counterclaim in a lawsuit) alleging that
any patent claim is infringed by making, using, selling, offering for
sale, or importing the Program or any portion of it.

  11. Patents.

  A "contributor" is a copyright holder who authorizes use under this
License of the Program or a work on which the Program is based.  The
work thus licensed is called the contributor's "contributor version".

  A contributor's "essential patent claims" are all patent claims
owned or controlled by the contributor, whether already acquired or
hereafter acquired, that would be infringed by some manner, permitted
by this License, of making, using, or selling its contributor version,
but do not include claims that would be infringed only as a
consequence of further modification of the contributor version.  For
purposes of this definition, "control" includes the right to grant
patent sublicenses in a manner consistent with the requirements of
this License.

  Each contributor grants you a non-exclusive, worldwide, royalty-free
patent license under the contributor's essential patent claims, to
make, use, sell, offer for sale, import and otherwise run, modify and
propagate the contents of its contributor version.

  In the following three paragraphs, a "patent license" is any express
agreement or commitment, however denominated, not to enforce a patent
(such as an express permission to practice a patent or covenant not to
sue for patent infringement).  To "grant" such a patent license to a
party means to make such an agreement or commitment not to enforce a
patent against the party.

  If you convey a covered work, knowingly relying on a patent license,
and the Corresponding Source of the work is not available for anyone
to copy, free of charge and under the terms of this License, through a
publicly available network server or other readily accessible means,
then you must either (1) cause the Corresponding Source to be so
available, or (2) arrange to deprive yourself of the benefit of the
patent license for this particular work, or (3) arrange, in a manner
consistent with the requirements of this License, to extend the patent
license to downstream recipients.  "Knowingly relying" means you have
actual knowledge that, but for the patent license, your conveying the
covered work in a country, or your recipient's use of the covered work
in a country, would infringe one or more identifiable patents in that
country that you have reason to believe are valid.

  If, pursuant to or in connection with a single transaction or
arrangement, you convey, or propagate by procuring conveyance of, a
covered work, and grant a patent license to some of the parties
receiving the covered work authorizing them to use, propagate, modify
or convey a specific copy of the covered work, then the patent license
you grant is automatically extended to all recipients of the covered
work and works based on it.

  A patent license is "discriminatory" if it does not include within
the scope of its coverage, prohibits the exercise of, or is
conditioned on the non-exercise of one or more of the rights that are
specifically granted under this License.  You may not convey a covered
work if you are a party to an arrangement with a third party that is
in the business of distributing software, under which you make payment
to the third party based on the extent of your activity of conveying
the work, and under which the third party grants, to any of the
parties who would receive the covered work from you, a discriminatory
patent license (a) in connection with copies of the covered work
conveyed by you (or copies made from those copies), or (b) primarily
for and in connection with specific products or compilations that
contain the covered work, unless you entered into that arrangement,
or that patent license was granted, prior to 28 March 2007.

  Nothing in this License shall be construed as excluding or limiting
any implied license or other defenses to infringement that may
otherwise be available to you under applicable patent law.

  12. No Surrender of Others' Freedom.

  If conditions are imposed on you (whether by court order, agreement or
otherwise) that contradict the conditions of this License, they do not
excuse you from the conditions of this License.  If you cannot convey a
covered work so as to satisfy simultaneously your obligations under this
License and any other pertinent obligations, then as a consequence you may
not convey it at all.  For example, if you agree to terms that obligate you
to collect a royalty for further conveying from those to whom you convey
the Program, the only way you could satisfy both those terms and this
License would be to refrain entirely from conveying the Program.

  13. Remote Network Interaction; Use with the GNU General Public License.

  Notwithstanding any other provision of this License, if you modify the
Program, your modified version must prominently offer all users
interacting with it remotely through a computer network (if your version
supports such interaction) an opportunity to receive the Corresponding
Source of your version by providing access to the Corresponding Source
from a network server at no charge, through some standard or customary
means of facilitating copying of software.  This Corresponding Source
shall include the Corresponding Source for any work covered by version 3
of the GNU General Public License that is incorporated pursuant to the
following paragraph.

  Notwithstanding any other provision of this License, you have
permission to link or combine any covered work with a work licensed
under version 3 of the GNU General Public License into a single
combined work, and to convey the resulting work.  The terms of this
License will continue to apply to the part which is the covered work,
but the work with which it is combined will remain governed by version
3 of the GNU General Public License.

  14. Revised Versions of this License.

  The Free Software Foundation may publish revised and/or new versions of
the GNU Affero General Public License from time to time.  Such new versions
will be similar in spirit to the present version, but may differ in detail to
address new problems or concerns.

  Each version is given a distinguishing version number.  If the
Program specifies that a certain numbered version of the GNU Affero General
Public License "or any later version" applies to it, you have the
option of following the terms and conditions either of that numbered
version or of any later version published by the Free Software
Foundation.  If the Program does not specify a version number of the
GNU Affero General Public License, you may choose any version ever published
by the Free Software Foundation.

  If the Program specifies that a proxy can decide which future
versions of the GNU Affero General Public License can be used, that proxy's
public statement of acceptance of a version permanently authorizes you
to choose that version for the Program.

  Later license versions may give you additional or different
permissions.  However, no additional obligations are imposed on any
author or copyright holder as a result of your choosing to follow a
later version.

  15. Disclaimer of Warranty.

  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT
HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY
OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM
IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF
ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

  16. Limitation of Liability.

  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS
THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY
GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE
USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF
DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD
PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS),
EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

  17. Interpretation of Sections 15 and 16.

  If the disclaimer of warranty and limitation of liability provided
above cannot be given local legal effect according to their terms,
reviewing courts shall apply local law that most closely approximates
an absolute waiver of all civil liability in connection with the
Program, unless a warranty or assumption of liability accompanies a
copy of the Program in return for a fee.

                     END OF TERMS AND CONDITIONS

            How to Apply These Terms to Your New Programs

  If you develop a new program, and you want it to be of the greatest
possible use to the public, the best way to achieve this is to make it
free software which everyone can redistribute and change under these terms.

  To do so, attach the following notices to the program.  It is safest
to attach them to the start of each source file to most effectively
state the exclusion of warranty; and each file should have at least
the "copyright" line and a pointer to where the full notice is found.

    <one line to give the program's name and a brief idea of what it does.>
    Copyright (C) <year>  <name of author>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

Also add information on how to contact you by electronic and paper mail.

  If your software can interact with users remotely through a computer
network, you should also make sure that it provides a way for users to
get its source.  For example, if your program is a web application, its
interface could display a "Source" link that leads users to an archive
of the code.  There are many ways you could offer source, and different
solutions will be better for different programs; see section 13 for the
specific requirements.

  You should also get your employer (if you work as a programmer) or school,
if any, to sign a "copyright disclaimer" for the program, if necessary.
For more information on this, and how to apply and follow the GNU AGPL, see
<http://www.gnu.org/licenses/>.

EOL
  );
}


# ----------- Script-specific code -----------

sub replace_script_specific_help_placeholders ( $ )
{
  my $podAsStr = shift;

  $podAsStr =~ s/OPT_ENV_VAR_NAME/@{[ OPT_ENV_VAR_NAME ]}/gs;
  $podAsStr =~ s/DEFAULT_CHECKSUM_FILENAME/@{[ DEFAULT_CHECKSUM_FILENAME ]}/gs;
  $podAsStr =~ s/IN_PROGRESS_EXTENSION/@{[ IN_PROGRESS_EXTENSION ]}/gs;
  $podAsStr =~ s/VERIFICATION_REPORT_EXTENSION/@{[ VERIFICATION_REPORT_EXTENSION ]}/gs;
  $podAsStr =~ s/BACKUP_EXTENSION/@{[ BACKUP_EXTENSION ]}/gs;

  # VERIFICATION_RESUME_EXTENSION_TMP needs to come before VERIFICATION_RESUME_EXTENSION.
  $podAsStr =~ s/VERIFICATION_RESUME_EXTENSION_TMP/@{[ VERIFICATION_RESUME_EXTENSION_TMP ]}/gs;
  $podAsStr =~ s/VERIFICATION_RESUME_EXTENSION/@{[ VERIFICATION_RESUME_EXTENSION ]}/gs;

  $podAsStr =~ s/OPT_NAME_SELF_TEST/@{[ OPT_NAME_SELF_TEST ]}/gs;

  $podAsStr =~ s/OPT_NAME_CREATE/@{[ OPT_NAME_CREATE ]}/gs;
  $podAsStr =~ s/OPT_NAME_VERIFY/@{[ OPT_NAME_VERIFY ]}/gs;
  $podAsStr =~ s/OPT_NAME_UPDATE/@{[ OPT_NAME_UPDATE ]}/gs;
  $podAsStr =~ s/OPT_NAME_VERBOSE/@{[ OPT_NAME_VERBOSE ]}/gs;
  $podAsStr =~ s/OPT_NAME_NO_UPDATE_MESSAGES/@{[ OPT_NAME_NO_UPDATE_MESSAGES ]}/gs;
  $podAsStr =~ s/OPT_NAME_RESUME_FROM_LINE/@{[ OPT_NAME_RESUME_FROM_LINE ]}/gs;

  $podAsStr =~ s/OPT_NAME_INCLUDE/@{[ OPT_NAME_INCLUDE ]}/gs;
  $podAsStr =~ s/OPT_NAME_EXCLUDE/@{[ OPT_NAME_EXCLUDE ]}/gs;

  return $podAsStr;
}


my $g_wasInterruptionRequested = undef;

sub signal_handler
{
  my $signalName = shift;

  my $msg;

  if ( $g_wasInterruptionRequested )
  {
    $msg = "Request to stop (signal $signalName) received, but a previous stop request has not completed yet...";
  }
  else
  {
    $g_wasInterruptionRequested = $signalName;

    $msg = "Stopping upon reception of signal $signalName...";
  }

  # Ignore any eventual error below from flush() or from print(). After SIGHUP, writing to
  # sdtout or stderr will probably fail anyway, but that should not stop us here.
  STDERR->flush();
  print STDOUT "\n$Script: $msg\n";
}


sub update_progress ( $ $ )
{
  my $filename = shift;  # Can be undef for the final progress update.
  my $context  = shift;

  if ( defined( $filename ) && $context->verbose )
  {
    return;
  }

  my $currentTime = Time::HiRes::clock_gettime( CLOCK_MONOTONIC );

  # Do not update the screen every time, but only every few seconds,
  # to avoid using too much CPU time (or file space, if the output
  # is redirected to a file).

  if ( defined( $filename ) && $currentTime < $context->lastProgressUpdate + PROGRESS_DELAY )
  {
    return;
  }


  my $bytes_per_second;

  if ( $currentTime - $context->startTime == 0 )
  {
    $bytes_per_second = 0;
  }
  else
  {
    $bytes_per_second = $context->totalSizeProcessed / ( $currentTime - $context->startTime );
  }

  my $speed = format_human_readable_size( $bytes_per_second, undef, HRS_UNIT_SI ) . "/s";

  my $txt;

  my $dirCount  = $context->directoryCountOk + $context->directoryCountFailed;
  my $fileCount = $context->fileCountOk      + $context->fileCountFailed;

  if ( $dirCount != 0 )
  {
    $txt .= AddThousandsSeparators( $dirCount , $g_grouping, $g_thousandsSep ) . " dir" . plural_s( $dirCount ) . ", ";
  }

  $txt .= AddThousandsSeparators( $fileCount, $g_grouping, $g_thousandsSep ) . " file" . plural_s( $fileCount ) . ", ";

  $txt .= format_human_readable_size( $context->totalSizeProcessed, 2, HRS_UNIT_SI ) . ", " ;

  $txt .= format_human_friendly_elapsed_time( $currentTime - $context->startTime, FALSE ) . " at " . $speed;

  if ( defined( $filename ) )
  {
    $txt .= ", curr: " . format_filename_for_console( $filename );
  }

  flush_stderr();

  write_stdout( $txt . "\n" );

  flush_stdout();


  # Take the system time again, in case the operations above (like flushing) takes a long time.
  # This way, we make sure that at least some time elapses between updates.
  $context->lastProgressUpdate( Time::HiRes::clock_gettime( CLOCK_MONOTONIC ) );
}


# Warning: This routine can return undef if this script was requested to stop upon reception of a signal.

sub checksum_file ( $ $ $ )
{
  my $filename     = shift;
  my $checksumType = shift;
  my $context      = shift;

  # Do not open the file if a stop request has already been received.
  if ( $g_wasInterruptionRequested )
  {
    return ( undef, undef );
  }

  my $totalReadByteCount = 0;
  my $checksum = undef;
  my $wasStopRequestReceived = FALSE;

  my $fileHandle = open_file_for_binary_reading( $filename );

  eval
  {
    # I believe that standard tool 'cat' uses a 128 KiB buffer size under Linux.
    use constant SOME_ARBITRARY_BUFFER_SIZE_CHKSUM => 128 * 1024;
    my $readBuffer;

    for ( ; ; )
    {
      # Simulate slow operation, sometimes useful when developing this script.
      if ( FALSE )
      {
        sleep( 1 );
      }

      my $readByteCount = sysread( $fileHandle, $readBuffer, SOME_ARBITRARY_BUFFER_SIZE_CHKSUM );

      if ( not defined $readByteCount )
      {
        die "Error reading from file: $!\n";
      }

      if ( $readByteCount == 0 )
      {
        last;
      }

      if ( $g_wasInterruptionRequested )
      {
        $wasStopRequestReceived = TRUE;
        last;
      }

      $totalReadByteCount += $readByteCount;

      $context->totalSizeProcessed( $context->totalSizeProcessed + $readByteCount );

      if ( $checksumType eq CHECKSUM_TYPE_ADLER_32 )
      {
        # The 'seed' is documented to be 1. Compress::Zlib::adler32() does return 1 if called with
        # a zero-lenght buffer. Passing 2 binary zeros as data makes the Adler-32 checksum change,
        # so the starting value seems to be working OK.

        $checksum = Compress::Zlib::adler32( $readBuffer, $checksum );
      }
      elsif ( $checksumType eq CHECKSUM_TYPE_CRC_32 )
      {
        # The 'seed' is not clear. Compress::Zlib::crc32() returns 0 if called with
        # a zero-lenght buffer. Passing 2 binary zeros as data makes the CRC-32 checksum change,
        # so the starting value seems to be working OK.

        $checksum = Compress::Zlib::crc32( $readBuffer, $checksum );
      }
      else
      {
        die "Unsupported checksum type " . format_str_for_message( $checksumType ) . ".\n";
      }

      update_progress( $filename, $context );
    }
  };

  close_file_handle_and_rethrow_eventual_error( $fileHandle, $filename, $@ );

  # Do not check $g_wasInterruptionRequested at this point. If the file was completed,
  # we do not want to quit now, even if a stop request was received during the last data read operation.
  if ( $wasStopRequestReceived )
  {
    return ( undef, undef );
  }
  else
  {
    # This can happen if the file was not empty before calling this routine,
    # but was truncated before reading data from it.
    # The caller should check again the actual data size read.
    # The returned checksum will not be used, but it must not be 'undef',
    # because that means a request to stop was received.
    if ( $totalReadByteCount == 0 )
    {
      return ( CHECKSUM_IF_NONE, 0 );
    }
    else
    {
      return ( sprintf("%08X", $checksum ), $totalReadByteCount );
    }
  }
}


sub break_up_stat_mtime ( $ )
{
  my $statMtime = shift;

  # We will be outputting the time formatted in ISO 8601.
  #
  # POSIX::strftime() does not support printing fractions of a second.
  # This is a limitation in Perl that should be fixed.
  # Compare with Python 3, Lib/datetime.py, strftime(), which supports
  # placeholder %f to output microseconds.
  #
  # But microseconds would probably not be good enough, because we actually want
  # nanoseconds, supported by Linux since many years, and I believe that
  # Windows' NTFS stores timestamps in nanoseconds too.
  #
  # Therefore, we need to separate the integer part from the fractional part here.
  # You would normally use tricks like:
  #   my $fractionalPart = $v - int ( $v );
  # Or you could use POSIX::modf( $mtime ).
  # However, I am worried that floating point inaccuracies may give us grief
  # in some obscure case. So I am converting to a string first, which is slow but safe
  # for our purposes.
  #
  # Note that we are losing some precision because Time::HiRes::stat() is converting
  # the timestamp to a floating point value. The underlying filesystem probably uses
  # integers to encode timestamps, so I find this a limitation in Perl that should be fixed.
  # I mean that Perl should give you access to an integer-based timestamp.
  # I actually reported this limitation to the Perl community:
  #   Access file timestamps with subsecond resolution as integer
  #   https://github.com/Perl/perl5/issues/17900
  #
  # I have seen a small difference comparing the timestamp from this script and the output
  # from Linux 'stat' command, so the accuracy issues seem to be real.
  # This is one example (simplified for clarity):
  #   Linux stat : 20:20:48.704 811 806
  #   This script: 20:20:48.704 811 811
  # Therefore, even though the system may store the timestamp down to the nanosecond,
  # this script rounds to milliseconds, which should be accurate enough on most systems.

  my $mtimeAsStr = sprintf( "%.3f", $statMtime );

  # sprintf will make sure that there is at least one digit before the decimal separator,
  # so we will always get 2 non-empty components here.
  my @components = split( /\./, $mtimeAsStr );

  if ( scalar @components != 2 )
  {
    die "Internal error parsing floating-point string " . format_str_for_message( $mtimeAsStr ) . ".\n";
  }

  return @components;
}


sub read_next_file_from_checksum_list ( $ )
{
  my $context = shift;

  # We cannot pass a struct member as a reference, so we need a temporary variable.
  my $lineNumber = $context->checksumFileLineNumber;

  my $textLine;

  eval
  {
    $textLine = read_text_line( $context->checksumFileHandle, \$lineNumber );
  };

  rethrow_eventual_error_with_filename( $context->checksumFilename, $@ );

  if ( ! defined ( $textLine ) )
  {
    return undef;
  }

  $context->checksumFileLineNumber( $lineNumber );


  return parse_file_line_from_checksum_list( $textLine, $context );
}


sub format_file_timestamp ( $ )
{
  my $statsRef = shift;  # Reference to file stats array.

  my ( $mtime_integer_part, $mtime_fractional_part ) = break_up_stat_mtime( $statsRef->[ 9 ] );

  my @utc = gmtime( $mtime_integer_part );

  return POSIX::strftime( "%Y-%m-%d" . "T" . "%H:%M:%S", @utc ) .
         "." .
         $mtime_fractional_part;
}


sub scan_disk_files ( $ )
{
  my $context = shift;

  if ( $context->operation == OPERATION_UPDATE )
  {
    step_to_next_file_on_checksum_list( $context, TRUE );
  }

  my $initialDirStackUtf8Ref = $context->dirStackUtf8();
  my $initialDirStackDepth = 0;

  my $startDirnameUtf8 = convert_native_to_utf8( $context->startDirname );

  if ( $context->startDirname ne CURRENT_DIRECTORY )
  {
    @$initialDirStackUtf8Ref = break_up_dir_only_path( $startDirnameUtf8 );

    $initialDirStackDepth = scalar( @$initialDirStackUtf8Ref );
  }

  scan_directory( $context->startDirname,
                  $startDirnameUtf8,
                  $context );

  # The array behind this reference should not have changed, but just in case, retrieve it again.
  my $finalDirStackUtf8Ref = $context->dirStackUtf8();
  my $finalDirStackDepth = scalar( @$finalDirStackUtf8Ref );

  if ( $initialDirStackDepth != $finalDirStackDepth )
  {
    die "Internal error: The directory stack push/pop operations were not balanced during the disk scan.\n";
  }

  all_remaining_files_in_checksum_list_not_found( $context );

  my $totalFileCount = $context->fileCountOk + $context->fileCountUnchanged;

  # Write some statistics as comments at the end of the file.

  my $statsMsg = FILE_LINE_SEP;
  $statsMsg .= "# Directory count: " . AddThousandsSeparators( $context->directoryCountOk, $g_grouping, $g_thousandsSep ) . FILE_LINE_SEP;
  $statsMsg .= "# File      count: " . AddThousandsSeparators( $totalFileCount           , $g_grouping, $g_thousandsSep ) . FILE_LINE_SEP;
  $statsMsg .= "# Total data size: " . format_human_readable_size( $context->totalFileSize, 2, HRS_UNIT_SI )              . FILE_LINE_SEP;

  write_to_file( $context->checksumFileHandleInProgress,
                 $context->checksumFilenameInProgress,
                 $statsMsg );

  update_progress( undef, $context );

  flush_stderr();

  my $exitCode = EXIT_CODE_SUCCESS;
  my $msg;

  $msg .= "\n";

  $msg .= "Directory count: " . AddThousandsSeparators( $context->directoryCountOk, $g_grouping, $g_thousandsSep ) . "\n";

  if ( FALSE )
  {
    $context->directoryCountFailed( 1 );
    $context->fileCountFailed     ( 2 );
  }

  if ( $context->directoryCountFailed != 0 )
  {
    $msg .= "Dir fail  count: " . AddThousandsSeparators( $context->directoryCountFailed, $g_grouping, $g_thousandsSep ) . "\n";
    $exitCode = EXIT_CODE_FAILURE;
  }

  $msg .= "File      count: " . AddThousandsSeparators( $totalFileCount, $g_grouping, $g_thousandsSep ) . "\n";

  if ( $context->fileCountFailed != 0 )
  {
    $msg .= "File fail count: " . AddThousandsSeparators( $context->fileCountFailed, $g_grouping, $g_thousandsSep ) . "\n";
    $exitCode = EXIT_CODE_FAILURE;
  }

  if ( $context->operation == OPERATION_UPDATE )
  {
    $msg .= "New file  count: " . AddThousandsSeparators( $context->fileCountAdded, $g_grouping, $g_thousandsSep ) . "\n";
    $msg .= "Removed   count: " . AddThousandsSeparators( $context->fileCountRemoved, $g_grouping, $g_thousandsSep ) . "\n";
    $msg .= "Changed   count: " . AddThousandsSeparators( $context->fileCountChanged, $g_grouping, $g_thousandsSep ) . "\n";
    $msg .= "Unchanged count: " . AddThousandsSeparators( $context->fileCountUnchanged, $g_grouping, $g_thousandsSep ) . "\n";
  }

  write_stdout( $msg );

  if ( $g_wasInterruptionRequested )
  {
    write_stdout( "Stopped because signal $g_wasInterruptionRequested was received.\n" );
  }

  return $exitCode;
}


sub step_to_next_file_on_checksum_list ( $ $ )
{
  my $context     = shift;
  my $isFirstTime = shift;


  my $fileChecksumInfo = read_next_file_from_checksum_list( $context );

  if ( ! defined( $fileChecksumInfo ) )
  {
    if ( ! $isFirstTime && ! defined( $context->currentFileOnChecksumList ) )
    {
      die "Internal error: Trying to step to the next file after having reached the end of the checksum list file.\n";
    }

    $context->currentFileOnChecksumList( undef );
    return;
  }


  my ( $volumeUtf8, $directoriesUtf8, $filenameOnlyUtf8 ) = File::Spec->splitpath( $fileChecksumInfo->filenameUtf8 );

  if ( 0 != length( $volumeUtf8 ) )
  {
    die "Operating systems with a concept of volume are not supported yet. " .
        "The volume that triggered this problem is " . format_str_for_message( convert_utf8_to_native( $volumeUtf8 ) ) . ".\n";
  }

  $fileChecksumInfo->filenameOnlyUtf8( $filenameOnlyUtf8 );

  # The documentation of File::Spec->splitpath() states:
  #   "The directory portion may or may not be returned with a trailing '/'."
  # In order to be sure, remove an eventual trailing '/' here.
  # Note that there can actually be more than one of then (I have tested it).
  $directoriesUtf8 = remove_eventual_trailing_directory_separators( $directoriesUtf8 );

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_utf8( $directoriesUtf8, "\$directoriesUtf8" );
  }

  $fileChecksumInfo->directoriesUtf8( $directoriesUtf8 );


  my @dirsUtf8 = break_up_dir_only_path( $directoriesUtf8 );

  $fileChecksumInfo->directoryStackUtf8( \@dirsUtf8 );


  $context->currentFileOnChecksumList( $fileChecksumInfo );

  if ( FALSE )
  {
    write_stdout( ( $isFirstTime ? "First file: " : "Next file: " ) .
                  format_filename_for_console( convert_utf8_to_native( $fileChecksumInfo->filenameUtf8 ) ) . "\n" );
  }
}


my $dirEntryInfoComparator = sub
{
  my $comparisonResult = lexicographic_utf8_comparator( $a->[ 1 ],
                                                        $b->[ 1 ] );

  # Directories may change while we are scanning them. I have seen in the documentation no guarantee
  # about getting no duplicate filenames from readdir if this happens.
  #
  # We are checking here because:
  # a) Duplicate filenames can be a great waste of time, depending on the file size.
  # b) Some future tools may have trouble processing a checksum list file that contains duplicates.
  # c) Checking here costs very little performance.

  if ( $comparisonResult == 0 )
  {
    die "Duplicate filename: " . convert_utf8_to_native( format_str_for_message( $a->[ 1 ] ) ) . ".\n";
  }

  return $comparisonResult;
};


use constant DOT_AS_UTF8 => convert_native_to_utf8( CURRENT_DIRECTORY );

sub dir_or_dot_utf8 ( $ )
{
  if ( length( $_[0] ) == 0 )
  {
    return DOT_AS_UTF8;
  }
  else
  {
    return $_[0];
  }
}


sub current_file_on_checksum_list_not_found ( $ )
{
  my $context = shift;

  my $fileChecksumInfo = $context->currentFileOnChecksumList;

  if ( $context->enableUpdateMessages )
  {
    write_stdout( "File no longer present: " . format_filename_for_console( convert_utf8_to_native( $fileChecksumInfo->filenameUtf8 ) ) . "\n" );
  }

  $context->fileCountRemoved( $context->fileCountRemoved + 1 );
}


sub step_checksum_list_files_up_to_current_directory ( $ $ )
{
  my $dirnameUtf8 = shift;
  my $context     = shift;

  if ( $context->operation != OPERATION_UPDATE )
  {
    return FALSE;
  }

  if ( FALSE )
  {
    write_stdout( "Discarding all files in the checksum list file that would have been found before this directory...\n" );
  }

  # Note that the progress indicator (if shown) is not updated here.
  # This phase should not last long anyway.

  my $isTracingEnabled = FALSE;

  my $isCurrentFileOnCheckListInThisDir = FALSE;

  for ( ; ; )
  {
    if ( $g_wasInterruptionRequested )
    {
      last;
    }

    my $fileChecksumInfo = $context->currentFileOnChecksumList;

    if ( ! defined ( $fileChecksumInfo ) )
    {
      if ( $isTracingEnabled )
      {
        write_stdout( convert_utf8_to_native( "Dir: " . format_str_for_message( $dirnameUtf8 ) . ": no files left in the list.\n" ) );
      }

      last;
    }

    my $comparisonResult = compare_directory_stacks( $context->dirStackUtf8(), $fileChecksumInfo->directoryStackUtf8 );

    if ( FALSE && $isTracingEnabled )
    {
      print_dir_stack_utf8( "Scan dir: ", $context->dirStackUtf8() );
      print_dir_stack_utf8( "List dir: ", $fileChecksumInfo->directoryStackUtf8 );

      write_stdout( convert_utf8_to_native( "Dir: " . format_str_for_message( $dirnameUtf8 ) .
                                            " cmp " . format_str_for_message( dir_or_dot_utf8( $fileChecksumInfo->directoriesUtf8 ) ) .
                                            " = $comparisonResult\n" ) );
    }

    if ( $comparisonResult < 0 )
    {
      if ( $isTracingEnabled )
      {
        write_stdout( convert_utf8_to_native( "Dir: " . format_str_for_message( $dirnameUtf8 ) .
                                              " < " . format_str_for_message( dir_or_dot_utf8( $fileChecksumInfo->directoriesUtf8 ) ) . "\n" ) );
      }

      last;
    }

    if ( $comparisonResult == 0 )
    {
      if ( $isTracingEnabled )
      {
        write_stdout( convert_utf8_to_native( "Dir: " . format_str_for_message( $dirnameUtf8 ) .
                                              " == " . format_str_for_message( dir_or_dot_utf8( $fileChecksumInfo->directoriesUtf8 ) ) . "\n" ) );
      }

      $isCurrentFileOnCheckListInThisDir = TRUE;

      last;
    }

    if ( $isTracingEnabled )
    {
      write_stdout( convert_utf8_to_native( "Dir: " . format_str_for_message( $dirnameUtf8 ) . " > " .
                                            format_str_for_message( dir_or_dot_utf8( $fileChecksumInfo->directoriesUtf8 ) ) . "\n" ) );
    }

    current_file_on_checksum_list_not_found( $context );

    step_to_next_file_on_checksum_list( $context, FALSE );
  }

  # The caller is not actually using this value yet, but in the future, it could use it
  # to optimise away testing the dir stack on the first file inside the directory.
  return $isCurrentFileOnCheckListInThisDir;
}


sub step_checksum_list_files_up_to_current_file ( $ $ $ )
{
  my $filename     = shift;
  my $filenameUtf8 = shift;
  my $context      = shift;

  if ( $context->operation != OPERATION_UPDATE )
  {
    return FALSE;
  }

  my $isTracingEnabled = FALSE;

  my $isCurrentFileOnCheckListThisFile = FALSE;

  for ( ; ; )
  {
    if ( $g_wasInterruptionRequested )
    {
      last;
    }

    my $fileChecksumInfo = $context->currentFileOnChecksumList;

    if ( ! defined ( $fileChecksumInfo ) )
    {
      if ( $isTracingEnabled )
      {
        write_stdout( "File: " . format_str_for_message( $filename ) . ": no files left in the list.\n" );
      }

      last;
    }


    my $dirStackComparisonResult = compare_directory_stacks( $context->dirStackUtf8(),
                                                             $fileChecksumInfo->directoryStackUtf8 );
    if ( $dirStackComparisonResult != 0 )
    {
      last;
    }


    my $comparisonResult = lexicographic_utf8_comparator( $filenameUtf8, $fileChecksumInfo->filenameOnlyUtf8 );

    if ( $comparisonResult < 0 )
    {
      if ( $isTracingEnabled )
      {
        write_stdout( convert_utf8_to_native( "File: " . format_str_for_message( $filenameUtf8 ) .
                                              " < " . format_str_for_message( $fileChecksumInfo->filenameOnlyUtf8 ) . "\n" ) );
      }

      last;
    }

    if ( $comparisonResult == 0 )
    {
      if ( $isTracingEnabled )
      {
        write_stdout( convert_utf8_to_native( "File: " . format_str_for_message( $filenameUtf8 ) .
                                              " == " . format_str_for_message( $fileChecksumInfo->filenameOnlyUtf8 ) . "\n" ) );
      }

      $isCurrentFileOnCheckListThisFile = TRUE;

      last;
    }

    if ( $isTracingEnabled )
    {
      write_stdout( convert_utf8_to_native( "File: " . format_str_for_message( $filenameUtf8 ) .
                                            " > " . format_str_for_message( $fileChecksumInfo->filenameOnlyUtf8 ) . "\n" ) );
    }

    current_file_on_checksum_list_not_found( $context );

    step_to_next_file_on_checksum_list( $context, FALSE );
  }

  return $isCurrentFileOnCheckListThisFile;
}


sub all_remaining_files_in_checksum_list_not_found ( $ )
{
  my $context = shift;

  if ( $context->operation != OPERATION_UPDATE )
  {
    return;
  }

  if ( FALSE )
  {
    write_stdout( "Removing all remaining files in the checksum list file...\n" );
  }

  # Note that the progress indicator (if shown) is not updated here.
  # This phase should not last long anyway.

  for ( ; ; )
  {
    if ( $g_wasInterruptionRequested )
    {
      last;
    }

    my $fileChecksumInfo = $context->currentFileOnChecksumList;

    if ( ! defined ( $fileChecksumInfo ) )
    {
      last;
    }

    current_file_on_checksum_list_not_found( $context );

    # Possible optimisation:
    #   We probably do not need all the information for these files that we about to drop,
    #   like their directory stacks, so we could skip generating it.

    step_to_next_file_on_checksum_list( $context, FALSE );
  }
}


# When reading a directory, we are temporarily storing both the filename returned as raw bytes
# from readdir, and the UTF-8 version we encoded ourselves. This means that we will need double
# the amount of memory. We could store only one of them, and convert to the other variant as needed.
#
# If we did that, we would be hoping that converting to UTF-8 and back will always yield
# the same result. But that should be the case. After all, we are storing the UTF-8 variants
# in the checksum list file, which may be read at a later point in time on a different computer.
# Therefore, if the round trip did not work well, we would have a problem anyway.
#
# The main drawback is that converting more often means taking a performance hit.
# If users start processing huge directories with gazillions of files on systems with little
# memory, we may have to revert this decision. But huge directories tend to cause problems
# everywhere, so this scenario is not very likely.

use constant ENTRY_NAME_NATIVE => 0;
use constant ENTRY_NAME_UTF8   => 1;
use constant ENTRY_STAT        => 2;


sub scan_directory
{
  my $dirname     = shift;
  my $dirnameUtf8 = shift;
  my $context     = shift;

  if ( $g_wasInterruptionRequested )
  {
    return;
  }

  # Prevent generating filenames that start with the current directory like "./file.txt".
  my $dirnamePrefix;
  my $dirnamePrefixUtf8;

  if ( $dirname eq CURRENT_DIRECTORY )
  {
    # We do not want to end up with filenames like "./file.txt" in the checksum list file.
    $dirnamePrefix     = "";
    $dirnamePrefixUtf8 = "";
  }
  elsif ( $dirname eq DIRECTORY_SEPARATOR )
  {
    # Special case for the root directory.
    $dirnamePrefix     = $dirname;
    $dirnamePrefixUtf8 = $dirnameUtf8;
  }
  else
  {
    $dirnamePrefix     = $dirname     . DIRECTORY_SEPARATOR;
    $dirnamePrefixUtf8 = $dirnameUtf8 . DIRECTORY_SEPARATOR;
  }

  update_progress( $dirname, $context );

  step_checksum_list_files_up_to_current_directory( $dirnameUtf8, $context );

  if ( $g_wasInterruptionRequested )
  {
    return;
  }

  use constant TRACE_FILTER => FALSE;

  my @files;
  my @subdirectories;

  opendir( my $dh, $dirname )
    or die "Cannot open directory " . format_str_for_message( $dirname ) . ": $!\n";

  eval
  {
    for ( ; ; )
    {
      if ( $g_wasInterruptionRequested )
      {
        last;
      }

      # There does not seem to be a way to detect an eventual error from the readdir() call.
      # I have reported this issue to the Perl community:
      #   https://github.com/Perl/perl5/issues/17907
      #   readdir does not report an eventual error
      my $dirEntryName = readdir( $dh );

      if ( ! defined( $dirEntryName ) )
      {
        last;
      }

      if ( $dirEntryName eq CURRENT_DIRECTORY ||
           $dirEntryName eq ".." )
      {
        if ( FALSE )
        {
          write_stdout( "Skipping special directory '$dirEntryName'.\n" );
        }

        next;
      }

      my $prefixAndDirEntryName = $dirnamePrefix. $dirEntryName;

      # A call to stat() takes time. Linux function readdir() can already report whether
      # a directory entry is a file or a subdirectory. If we had access to that information
      # here, we could avoid the stat() call in many cases.

      my @dirEntryStats = Time::HiRes::stat( $prefixAndDirEntryName );

      if ( scalar( @dirEntryStats ) == 0 )
      {
        # We do not know at this point whether the entry is a file or a directory.
        # It is most likely a broken link.

        $context->fileCountFailed( $context->fileCountFailed + 1 );

        flush_stdout();

        write_stderr( "Error accessing " . format_str_for_message( $prefixAndDirEntryName ) . ": $!\n" );

        next;
      }

      my $mode = $dirEntryStats[ 2 ];

      if ( Fcntl::S_ISDIR( $mode ) )
      {
        my $dirEntryNameUtf8 = convert_native_to_utf8( $dirEntryName );

        if ( filter_file_or_dirname( $dirnamePrefixUtf8 . $dirEntryNameUtf8 . DIRECTORY_SEPARATOR,
                                     $context ) )
        {
          if ( TRACE_FILTER || $context->verbose )
          {
            write_stdout( "Filtered dir: " . format_filename_for_console( $prefixAndDirEntryName ) . "\n" );
          }
        }
        else
        {
          push @subdirectories, [ $dirEntryName,
                                  $dirEntryNameUtf8,
                                  undef  # \@dirEntryStats  # We are not actually using this one yet, so save memory by not storing it.
                                ];
        }

        next;
      }

      if ( ! Fcntl::S_ISREG( $mode ) )
      {
        if ( FALSE )
        {
          # We probably do not want to consider this an error.
          # The documentation states now that such non-regular files are automatically skipped.
          $context->fileCountFailed( $context->fileCountFailed + 1 );

          flush_stdout();

          write_stderr( "Error accessing " . format_str_for_message( $prefixAndDirEntryName ) . ": Not a regular file.\n" );
        }
        else
        {
          if ( $context->verbose )
          {
            write_stdout( "Skipping non-regular file: " . format_filename_for_console( $prefixAndDirEntryName ) . "\n" );
          }
        }

        next;
      }

      my $skipCheckStr = $prefixAndDirEntryName;

      if ( remove_str_prefix( \$skipCheckStr, $context->checksumFilename ) )
      {
        # We ignore the related verification report file, because it will often be there,
        # but the user will most probably not want to include it in the checksum list file.

        if ( $skipCheckStr eq ""  || # When updating, the previous "FileChecksums.txt" will be there.
             $skipCheckStr eq '.' . IN_PROGRESS_EXTENSION ||
             $skipCheckStr eq '.' . VERIFICATION_REPORT_EXTENSION ||
             $skipCheckStr eq '.' . VERIFICATION_RESUME_EXTENSION ||
             $skipCheckStr eq '.' . VERIFICATION_RESUME_EXTENSION_TMP ||
             $skipCheckStr eq '.' . BACKUP_EXTENSION )
        {
          if ( FALSE )
          {
            write_stdout( "Checksum-related file skipped: " . format_filename_for_console( $prefixAndDirEntryName ) . "\n" );
          }

          next;
        }
      }

      my $dirEntryNameUtf8 = convert_native_to_utf8( $dirEntryName );

      if ( filter_file_or_dirname( $dirnamePrefixUtf8 . $dirEntryNameUtf8,
                                   $context ) )
      {
        if ( TRACE_FILTER || $context->verbose )
        {
          write_stdout( "Filtered file: " . format_filename_for_console( $prefixAndDirEntryName ) . "\n" );
        }

        next;
      }

      push @files, [ $dirEntryName,
                     $dirEntryNameUtf8,
                     \@dirEntryStats
                   ];
    }

    if ( $g_wasInterruptionRequested )
    {
      return;  # Exit the eval.
    }


    # Sorting the filenames may take some time.
    #
    # If the source and destination arrays are the same, Perl will sort in place.
    # Otherwise, we would be generating a copy of the array, consuming more memory than necessary.
    # Sorting in place avoids creating a temporary copy of the array.

    @files = sort $dirEntryInfoComparator @files;

    for ( ; ; )
    {
      # Shifting from an array is supposed to be optimised for speed,
      # because Perl keeps a start offset for the array memory, which avoids moving and reallocating often.
      #
      # We want to shift in order to discard the element early.
      # Otherwise, depending on how good Perl's optimiser is, these file entries will remain
      # im memory when we descend into the subdirectories. That would unnecessarily increase memory consumption.

      my $fileEntry = shift @files;

      if ( ! defined( $fileEntry ) )
      {
        last;
      }

      process_file( $dirnamePrefix, $dirnamePrefixUtf8, $fileEntry, $context );

      if ( $g_wasInterruptionRequested )
      {
        last;
      }
    }

    if ( $g_wasInterruptionRequested )
    {
      return;  # Exit the eval.
    }


    # See the notes about sorting and shifting the @files array above for information about performance.
    @subdirectories = sort $dirEntryInfoComparator @subdirectories;

    for ( ; ; )
    {
      my $subdirEntry = shift @subdirectories;

      if ( ! defined( $subdirEntry ) )
      {
        last;
      }

      my $subdirname     = $subdirEntry->[ ENTRY_NAME_NATIVE ];
      my $subdirnameUtf8 = $subdirEntry->[ ENTRY_NAME_UTF8   ];

      my $prefixAndSubdirname = $dirnamePrefix . $subdirname;

      if ( $context->verbose )
      {
        write_stdout( "Dir: " . format_filename_for_console( $prefixAndSubdirname ) . "\n" );
      }

      my $dirStackRef = $context->dirStackUtf8();

      push @$dirStackRef, $subdirnameUtf8;

      eval
      {
        # Recursive call.
        scan_directory( $prefixAndSubdirname,
                        $dirnamePrefixUtf8 . $subdirnameUtf8,
                        $context );
      };

      my $errorMsg = $@;

      pop @$dirStackRef;

      if ( $g_wasInterruptionRequested )
      {
        last;
      }

      if ( $errorMsg )
      {
        $context->directoryCountFailed( $context->directoryCountFailed + 1 );

        flush_stdout();

        write_stderr( $errorMsg );

        # At this point, if we are updating, we could skip all files in the checksum list file
        # that should be under the failed directory.
      }
      else
      {
        $context->directoryCountOk( $context->directoryCountOk + 1 );
      }
    }
  };

  my $errorMessage = $@;

  if ( $errorMessage )
  {
    # Close the directory handle before propagating the first error.
    #
    # Do not die from an eventual error from closedir(), because we would otherwise be
    # hiding the first error that happened.
    #
    # Writing to STDERR may also fail, but ignore any such eventual error
    # for the same reason.

    closedir( $dh )
        or print STDERR "Cannot close directory " . format_str_for_message( $dirname ) . ": $!\n";

    die "Error processing directory " . format_str_for_message( $dirname ) . ": $errorMessage";
  }

  closedir( $dh )
    or die "Cannot close directory " . format_str_for_message( $dirname ) . ": $!\n";
}


sub filter_file_or_dirname ( $ $ )
{
  my $fileOrDirnameUtf8 = shift;
  my $context           = shift;

  my $filenameFiltersRef = $context->filenameFilters;

  foreach my $filterElem ( @$filenameFiltersRef )
  {
    my $regex = $filterElem->regex;

    my $doesMatch = $fileOrDirnameUtf8 =~ $regex;

    if ( $doesMatch )
    {
      return $filterElem->isInclude ? FALSE : TRUE;
    }
  }

  return $context->defaultIsInclude ? FALSE : TRUE;
}


sub process_file ( $ $ $ $ )
{
  my $dirnamePrefix     = shift;
  my $dirnamePrefixUtf8 = shift;
  my $fileEntry         = shift;
  my $context           = shift;

  my $prefixAndFilename     = $dirnamePrefix     . $fileEntry->[ ENTRY_NAME_NATIVE ];
  my $prefixAndFilenameUtf8 = $dirnamePrefixUtf8 . $fileEntry->[ ENTRY_NAME_UTF8   ];

  update_progress( $prefixAndFilename, $context );

  my $isCurrentFileOnCheckListThisFile = step_checksum_list_files_up_to_current_file( $fileEntry->[ ENTRY_NAME_NATIVE ],
                                                                                      $fileEntry->[ ENTRY_NAME_UTF8   ],
                                                                                      $context );
  if ( $g_wasInterruptionRequested )
  {
    return;
  }


  if ( $context->verbose )
  {
    write_stdout( "File: " . format_filename_for_console( $prefixAndFilename ) . "\n" );
  }


  my $statsRef = $fileEntry->[ ENTRY_STAT ];

  my $detectedFileSize = $statsRef->[ 7 ];

  my $iso8601Time = format_file_timestamp( $statsRef );

  if ( $isCurrentFileOnCheckListThisFile )
  {
    my $fileChecksumInfo = $context->currentFileOnChecksumList;

    my $reasonForUpdate;

    if ( $detectedFileSize != $fileChecksumInfo->fileSize )
    {
      $reasonForUpdate = "size changed";
    }
    else
    {
      if ( $iso8601Time ne $fileChecksumInfo->timestamp )
      {
        $reasonForUpdate = "timestamp changed";
      }
    }

    if ( ! $reasonForUpdate )
    {
      $context->fileCountUnchanged( $context->fileCountUnchanged + 1 );
      $context->totalFileSize( $context->totalFileSize + $detectedFileSize );

      add_line_for_file( $detectedFileSize,  # We could even optimise away having to add the thousands separators.
                         $iso8601Time,
                         $prefixAndFilenameUtf8,
                         $fileChecksumInfo->checksumType,
                         $fileChecksumInfo->checksumValue,
                         $context );

      step_to_next_file_on_checksum_list( $context, FALSE );

      return;
    }

    if ( $context->enableUpdateMessages )
    {
      write_stdout( "Updating file ($reasonForUpdate): " . format_filename_for_console( $prefixAndFilename ) . "\n" );
    }

    $context->fileCountChanged( $context->fileCountChanged + 1 );

    step_to_next_file_on_checksum_list( $context, FALSE );
  }
  else
  {
    if ( $context->operation == OPERATION_UPDATE )
    {
      if ( $context->enableUpdateMessages )
      {
        write_stdout( "Adding file: " . format_filename_for_console( $prefixAndFilename ) . "\n" );
      }

      $context->fileCountAdded( $context->fileCountAdded + 1 );
    }
  }


  my $checksumType = $context->checksumType;

  my $calculatedChecksum;
  my $fileSizeFromChecksumProcess;

  # If the file is empty, do not bother opening it.
  if ( $checksumType eq CHECKSUM_TYPE_NONE || $detectedFileSize == 0 )
  {
    $checksumType                = CHECKSUM_TYPE_NONE;
    $calculatedChecksum          = CHECKSUM_IF_NONE;
    $fileSizeFromChecksumProcess = $detectedFileSize;
  }
  else
  {
    my $wasInterrupted = FALSE;

    eval
    {
      ( $calculatedChecksum, $fileSizeFromChecksumProcess ) = checksum_file( $prefixAndFilename, $checksumType, $context );

      if ( ! defined( $calculatedChecksum ) )
      {
        $wasInterrupted = TRUE;
        return;  # Break out of eval.
      }
    };

    my $errorMsg = $@;

    if ( $wasInterrupted )
    {
      # If interrupted:
      # 1) We should not count the file as successful.
      # 2) There should be no error to deal with.
      # 3) $g_wasInterruptionRequested should also be set.
      return;
    }

    if ( $errorMsg )
    {
      $context->fileCountFailed( $context->fileCountFailed + 1 );

      flush_stdout();

      write_stderr( "Error processing file " . format_str_for_message( $prefixAndFilename ) . ": $errorMsg" );

      return;
    }
  }

  # The file size ($detectedFileSize) may have changed in the meantime,
  # so use the number of bytes actually read ($fileSizeFromChecksumProcess).

  if ( $fileSizeFromChecksumProcess == 0 )
  {
    $checksumType        = CHECKSUM_TYPE_NONE;
    $calculatedChecksum  = CHECKSUM_IF_NONE;
  }

  $context->totalFileSize( $context->totalFileSize + $fileSizeFromChecksumProcess );
  $context->fileCountOk( $context->fileCountOk + 1 );

  add_line_for_file( $fileSizeFromChecksumProcess,
                     $iso8601Time,
                     $prefixAndFilenameUtf8,
                     $checksumType,
                     $calculatedChecksum,
                     $context );
}


sub add_line_for_file ( $ $ $ $ $ $ )
{
  my $fileSize         = shift;
  my $iso8601TimeAsStr = shift;
  my $fileNameUtf8     = shift;
  my $checksumType     = shift;
  my $checksumValue    = shift;
  my $context          = shift;

  my $sizeStr = AddThousandsSeparators( $fileSize, 3, FILE_THOUSANDS_SEPARATOR );

  # Our escaping only affects characters < 127 and therefore does not interfere with any UTF-8 characters
  # before or after the conversion to UTF-8.
  my $subdirAndFilenameUtf8Escaped = escape_filename( $fileNameUtf8 );

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_utf8( $fileNameUtf8, "filename for checksum list file" );
  }

  my $line1 = $iso8601TimeAsStr .
              FILE_COL_SEPARATOR .
              $checksumType .
              FILE_COL_SEPARATOR .
              $checksumValue .
              FILE_COL_SEPARATOR .
              $sizeStr .
              FILE_COL_SEPARATOR;

  # Most of the line is plain ASCII and needs no conversion to UTF-8.
  # Only the filename is problematic.

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $line1, "\$line1" );
  }

  # Writing this string separately might avoid one conversion to UTF-8.
  write_to_file( $context->checksumFileHandleInProgress,
                 $context->checksumFilenameInProgress,
                 $line1 );

  write_to_file( $context->checksumFileHandleInProgress,
                 $context->checksumFilenameInProgress,
                 $subdirAndFilenameUtf8Escaped );

  write_to_file( $context->checksumFileHandleInProgress,
                 $context->checksumFilenameInProgress,
                 FILE_LINE_SEP );
}


# This alternative to remove thousand separators works, but it cannot use constant FILE_THOUSANDS_SEPARATOR:
#   $expectedFileSize =~ tr/,//d;
my $matchThousandsSeparatorsRegex = qr/${\(FILE_THOUSANDS_SEPARATOR)}/;

Class::Struct::struct( CFileChecksumInfo =>
                       [ # A bracket here means we will be creating an array-based struct (as opposed to a hash based).
                         timestamp          => '$',
                         checksumType       => '$',
                         checksumValue      => '$',
                         fileSize           => '$',

                         filename           => '$',  # Examples: "file.txt" and "dir1/dir2/file.txt".
                         filenameUtf8       => '$',

                         filenameOnlyUtf8   => '$',  # Only available during OPERATION_UPDATE.

                         # These fields are only available during OPERATION_UPDATE.
                         directoriesUtf8    => '$',  # Examples: "" for current directory ('.') and "dir1/dir2".
                         directoryStackUtf8 => '@',  # This is directoriesUtf8 broken up into path components.
                       ]
                     );

sub parse_file_line_from_checksum_list ( $ $ )
{
  my $textLine = shift;
  my $context  = shift;

  my $fileChecksumInfo;

  eval
  {
    use constant LINE_COMPONENT_COUNT => 5;

    use constant FIELD_INDEX_TIMESTAMP      => 0;
    use constant FIELD_INDEX_CHECKSUM_TYPE  => 1;
    use constant FIELD_INDEX_CHECKSUM_VALUE => 2;
    use constant FIELD_INDEX_SIZE           => 3;
    use constant FIELD_INDEX_FILENAME       => 4;


    my @textLineComponents = split( /\t/, $textLine );

    if ( scalar @textLineComponents != LINE_COMPONENT_COUNT )
    {
      die "Cannot separate the @{[ LINE_COMPONENT_COUNT ]} line components.\n";
    }

    if ( ENABLE_UTF8_RESEARCH_CHECKS )
    {
      for my $str ( @textLineComponents )
      {
        check_string_is_marked_as_native( $str, "text line read from a file" );
      }
    }


    # Step 1) First, check if there are any character encoding issues.

    if ( ! is_plain_ascii( $textLineComponents[ FIELD_INDEX_TIMESTAMP ] ) )
    {
      die "The timestamp field contains non-ASCII characters.\n";
    }

    if ( ! is_plain_ascii( $textLineComponents[ FIELD_INDEX_CHECKSUM_TYPE ] ) )
    {
      die "The checksum type field contains non-ASCII characters.\n";
    }

    if ( ! is_plain_ascii( $textLineComponents[ FIELD_INDEX_CHECKSUM_VALUE ] ) )
    {
      die "The checksum value field contains non-ASCII characters.\n";
    }

    if ( ! is_plain_ascii( $textLineComponents[ FIELD_INDEX_SIZE ] ) )
    {
      die "The file size field contains non-ASCII characters.\n";
    }


    # Unescape the filename.
    # Our escaping only affects characters < 127 and therefore does not interfere with any UTF-8 characters
    # before or after the conversion to UTF-8.
    eval
    {
      $textLineComponents[ FIELD_INDEX_FILENAME ] = unescape_filename( $textLineComponents[ FIELD_INDEX_FILENAME ] );
    };

    my $errorMsgUnescape = $@;

    if ( $errorMsgUnescape )
    {
      # We cannot output the filename, because we still do not know if the UTF-8 encoding is valid.
      if ( FALSE )
      {
        die "Error unescaping filename " . format_str_for_message( $textLineComponents[ FIELD_INDEX_FILENAME ] ) . ": $errorMsgUnescape";
      }
      else
      {
        die "Error unescaping the filename: $errorMsgUnescape";
      }
    }


    # We could validate that the filename does not contain binary zeros, as required by the Linux syscalls which take filenames.
    # But the list of invalid characters actually depends on the operating system, and even on the filesystem.
    # For example, Windows does not allow colons (':') and backslashes ('\') among other forbidden characters.


    my $filenameUtf8;

    eval
    {
      $filenameUtf8 = convert_raw_bytes_to_utf8( $textLineComponents[ FIELD_INDEX_FILENAME ] );
    };

    my $errorMsgUtf8 = $@;

    if ( $errorMsgUtf8 )
    {
      die "Error in the filename field: $errorMsgUtf8";
    }

    # $textLineComponents[ FIELD_INDEX_FILENAME ] can be used afterwards in syscalls to open the file etc.,
    # because after converting to $filenameUtf8, we know now that the UTF-8 encoding is valid,
    # and we also know that we are actually using UTF-8 internally.
    if ( SYSCALL_ENCODING_ASSUMPTION ne "UTF-8" )
    {
      die "Internal error: Invalid syscall encoding assumption.\n";
    }


    # Step 2) Modify or further validate the values as needed.
    #         From this point it is safe to output these strings to stdout.

    # We are not actually parsing the timestamp yet, because it is slow and we can get away without doing it.
    # Later on, when we need to compare such timestamps, we just generate the ISO 8601 representation
    # of the other timestamp, and we compare then as plain strings.
    # However, I decided to do the minimal validation of checking the timestamp field's length.
    # This way, hopefully many eventual errors will be detected early. One such error could be
    # printing the subsecond part with a resolution greater than milliseconds. If someone did that,
    # comparing timestamps will never work properly.

    if ( 23 != length( $textLineComponents[ FIELD_INDEX_TIMESTAMP ] ) )
    {
      die "The timestamp field has an invalid length.\n";
    }


    # Remove the thousands separators from the file size.
    $textLineComponents[ FIELD_INDEX_SIZE ] =~ s/$matchThousandsSeparatorsRegex//g;

    my $sizeAsInt;

    eval
    {
      $sizeAsInt = parse_unsigned_integer( $textLineComponents[ FIELD_INDEX_SIZE ] );
    };

    my $errorMessage = $@;

    if ( $errorMessage )
    {
      # The value we are showing the user below is actually after removing any thousands separators.
      die "Error in the file size field, value " . format_str_for_message( $textLineComponents[ FIELD_INDEX_SIZE ] ) . ": $errorMessage";
    }

    $fileChecksumInfo =
      CFileChecksumInfo->new( timestamp     => $textLineComponents[ FIELD_INDEX_TIMESTAMP ],
                              checksumType  => $textLineComponents[ FIELD_INDEX_CHECKSUM_TYPE ],
                              checksumValue => $textLineComponents[ FIELD_INDEX_CHECKSUM_VALUE ],
                              fileSize      => $sizeAsInt,
                              filename      => $textLineComponents[ FIELD_INDEX_FILENAME ],
                              filenameUtf8  => $filenameUtf8 );
  };

  my $errorMsg = $@;

  if ( $errorMsg )
  {
    die "Error parsing file " . format_str_for_message( $context->checksumFilename ) .
        ", line " . $context->checksumFileLineNumber .
        ": " . $errorMsg;
  }

  return $fileChecksumInfo;
}


sub scan_listed_files ( $ $ )
{
  my $resumeFromLine = shift;
  my $context        = shift;

  # Try to write an empty resume file at the beginning.
  # Otherwise, we may fail a few seconds later, and it is better to fail early.
  update_verification_resume( 0, TRUE,  $context );

  my $skippedFileCount = 0;

  if ( $resumeFromLine != 0 )
  {
    while ( $context->checksumFileLineNumber < $resumeFromLine - 1 )
    {
      if ( $g_wasInterruptionRequested )
      {
        last;
      }

      my $textLine;

      eval
      {
        $textLine = read_text_line_raw( $context->checksumFileHandle );
      };

      rethrow_eventual_error_with_filename( $context->checksumFilename, $@ );

      if ( ! defined ( $textLine ) )
      {
        die "The line number to resume from (" . $resumeFromLine . ") is higher than the number of lines in the checksum list file (" . $context->checksumFileLineNumber . ").\n";
      }

      $context->checksumFileLineNumber( $context->checksumFileLineNumber + 1 );

      if ( FALSE )
      {
        write_stdout( "Line skipped: $textLine\n" );
      }

      # Any non-empty text line refers to a file that has been checksummed.
      if ( 0 != length( trim_empty_or_comment_text_line( $textLine ) ) )
      {
        ++$skippedFileCount;
      }
    }
  }

  my $resumeLineNumber = 0;

  $context->lastVerificationUpdate( $context->startTime );

  for ( ; ; )
  {
    if ( $g_wasInterruptionRequested )
    {
      last;
    }

    my $fileChecksumInfo = read_next_file_from_checksum_list( $context );

    if ( ! defined ( $fileChecksumInfo ) )
    {
      last;
    }

    if ( $context->verbose )
    {
      write_stdout( "File: " . format_filename_for_console( $fileChecksumInfo->filename ) . "\n" );
    }

    my $wasInterrupted = FALSE;

    eval
    {
      my @entryStats = Time::HiRes::stat( $fileChecksumInfo->filename );

      if ( scalar( @entryStats ) == 0 )
      {
        die "$!\n";
      }

      # We need to check whether this is a file, because directories also have a size.

      my $mode = $entryStats[ 2 ];

      if ( Fcntl::S_ISDIR( $mode ) )
      {
        die "The file is actually a directory.\n";
      }

      my $detectedFileSize = $entryStats[ 7 ];

      if ( $fileChecksumInfo->fileSize != $detectedFileSize )
      {
        die "The current file size of " .
            AddThousandsSeparators( $detectedFileSize, $g_grouping, $g_thousandsSep ) .
            " bytes differs from the expected " .
            AddThousandsSeparators( $fileChecksumInfo->fileSize, $g_grouping, $g_thousandsSep ) .
            " bytes.\n";
      }

      if ( $fileChecksumInfo->checksumType ne CHECKSUM_TYPE_NONE )
      {
        my ( $calculatedChecksum, $fileSize ) = checksum_file( $fileChecksumInfo->filename,
                                                               $fileChecksumInfo->checksumType,
                                                               $context );

        if ( ! defined( $calculatedChecksum ) )
        {
          $wasInterrupted = TRUE;
          return;  # Break out of eval.
        }

        # The file size may have changed in the meantime, so we have to check again.
        # Note that empty files have no checksum.
        if ( $fileSize != $fileChecksumInfo->fileSize )
        {
          die "The current file size of " .
              AddThousandsSeparators( $fileSize, $g_grouping, $g_thousandsSep ) .
              " bytes differs from the expected " .
              AddThousandsSeparators( $fileChecksumInfo->fileSize, $g_grouping, $g_thousandsSep ) .
              " bytes.\n";
        }

        if ( $calculatedChecksum ne $fileChecksumInfo->checksumValue )
        {
          die "The calculated " . $fileChecksumInfo->checksumType . " checksum " . format_str_for_message( $calculatedChecksum ) .
              " does not match the expected " . format_str_for_message( $fileChecksumInfo->checksumValue ) . ".\n";
        }
      }
    };

    my $errorMsg = $@;

    if ( $wasInterrupted )
    {
      # If interrupted:
      # 1) We should not count the file as successful.
      # 2) There should be no error to deal with.
      # 3) $g_wasInterruptionRequested should also be set.
      last;
    }

    if ( $errorMsg )
    {
      $context->fileCountFailed( $context->fileCountFailed + 1 );

      flush_stdout();

      write_stderr( "Error verifying file " . format_str_for_message( $fileChecksumInfo->filename ) . ": $errorMsg" );

      my $errMsgWithoutNewline = remove_eol_from_perl_error( $errorMsg );

      my $lineTextUtf8 = escape_filename( $fileChecksumInfo->filenameUtf8 ) .
                         FILE_COL_SEPARATOR .
                         convert_native_to_utf8( $errMsgWithoutNewline ) .
                         FILE_LINE_SEP;

      if ( ENABLE_UTF8_RESEARCH_CHECKS )
      {
        check_string_is_marked_as_utf8( $lineTextUtf8, "\$lineTextUtf8" );
      }

      write_to_file( $context->verificationReportFileHandle,
                     $context->verificationReportFilename,
                     $lineTextUtf8 );
    }
    else
    {
      $context->fileCountOk( $context->fileCountOk + 1 );
    }

    $resumeLineNumber = $context->checksumFileLineNumber + 1;

    update_verification_resume( $resumeLineNumber, FALSE, $context );
  }

  if ( $g_wasInterruptionRequested )
  {
    if ( $resumeLineNumber == 0 )
    {
      # The first empty file we created will remain behind, but that is OK.
    }
    else
    {
      update_verification_resume( $resumeLineNumber, TRUE, $context );
    }
  }
  else
  {
    # The verification has finished, so there is no point leaving a resume file behind.
    # There will always be a resume file to delete at this point, because we always create an empty one on start-up.
    delete_file( $context->checksumFilename . "." . VERIFICATION_RESUME_EXTENSION );
  }

  update_progress( undef, $context );

  flush_stderr();

  write_stdout( "\n" );

  if ( $context->fileCountFailed != 0 )
  {
    write_to_file( $context->verificationReportFileHandle,
                   $context->verificationReportFilename,
                   FILE_LINE_SEP );
  }

  my $exitCode = EXIT_CODE_SUCCESS;
  my $msg;

  $msg = "Successfully verified: " . AddThousandsSeparators( $context->fileCountOk, $g_grouping, $g_thousandsSep ) .
         " file" . plural_s( $context->fileCountOk );

  write_stdout( $msg . "\n" );

  write_to_file( $context->verificationReportFileHandle,
                 $context->verificationReportFilename,
                 FILE_COMMENT . " " . $msg . FILE_LINE_SEP );


  if ( $skippedFileCount != 0 )
  {
    $msg = "Skipped by resume    : " . AddThousandsSeparators( $skippedFileCount, $g_grouping, $g_thousandsSep ) .
           " file" . plural_s( $skippedFileCount );

    write_stdout( $msg . "\n" );

    write_to_file( $context->verificationReportFileHandle,
                   $context->verificationReportFilename,
                   FILE_COMMENT . " " . $msg . FILE_LINE_SEP );
  }

  if ( $context->fileCountFailed != 0 )
  {
    $msg = "Failed               : " . AddThousandsSeparators( $context->fileCountFailed, $g_grouping, $g_thousandsSep ) .
           " file" . plural_s( $context->fileCountFailed );

    write_stdout( $msg . "\n" );

    write_to_file( $context->verificationReportFileHandle,
                   $context->verificationReportFilename,
                   FILE_COMMENT . " " . $msg . FILE_LINE_SEP );

    $exitCode = EXIT_CODE_FAILURE;
  }

  # There is no point reminding the user about the report file if it is incomplete anyway.
  if ( ! $g_wasInterruptionRequested )
  {
    write_stdout( "A report has been created with filename: " . format_filename_for_console( $context->verificationReportFilename ) . "\n" );
  }

  if ( $g_wasInterruptionRequested )
  {
    my $msgStdout = "Stopped because signal $g_wasInterruptionRequested was received.";
    my $msgReport = "The verification process was interrupted by signal $g_wasInterruptionRequested.";

    my $suffix = "";

    if ( $resumeLineNumber != 0 )
    {
      $suffix = " Resume with option \"--@{[ OPT_NAME_RESUME_FROM_LINE ]}=$resumeLineNumber\".";
    }

    write_stdout( $msgStdout . $suffix . "\n" );

    write_to_file( $context->verificationReportFileHandle,
                   $context->verificationReportFilename,
                   FILE_COMMENT . " " . $msgReport . $suffix . FILE_LINE_SEP );
  }

  return $exitCode;
}


sub update_verification_resume ( $ $ $ )
{
  my $resumeLineNumber = shift;
  my $shouldDoItNow    = shift;
  my $context          = shift;

  # We automatically regenerate the file once per minute. Therefore,
  # if this script gets killed, up to one minute's worth of work
  # will have to be performed again. Possibly more if the files are big.
  use constant UPDATE_VERIFICATION_DELAY => 60;  # In seconds.

  my $currentTime = Time::HiRes::clock_gettime( CLOCK_MONOTONIC );

  if ( ! $shouldDoItNow &&
       $currentTime < $context->lastVerificationUpdate + UPDATE_VERIFICATION_DELAY )
  {
    return;
  }

  if ( FALSE )
  {
    write_stdout( "Saving verification resume file.\n" );
  }

  flush_file( $context->verificationReportFileHandle,
              $context->verificationReportFilename );

  my $verificationResumeTmpFilename = $context->checksumFilename . "." . VERIFICATION_RESUME_EXTENSION_TMP;

  my $verificationResumeTmpFileHandle = create_or_truncate_file_for_utf8_writing( $verificationResumeTmpFilename );

  eval
  {
    my $header = UTF8_BOM . REPORT_FIRST_LINE_PREFIX . FILE_FORMAT_VERSION . FILE_LINE_SEP .
                 FILE_LINE_SEP .
                 FILE_COMMENT . " " . "This file contains information to resume an incomplete verification process." . FILE_LINE_SEP .
                 FILE_LINE_SEP;

    write_to_file( $verificationResumeTmpFileHandle,
                   $verificationResumeTmpFilename,
                   $header );

    my $text;

    if ( $resumeLineNumber == 0 )
    {
      $text = FILE_COMMENT . " " . "No resume information available yet." . FILE_LINE_SEP;
    }
    else
    {
      $text = KEY_VERIFICATION_RESUME_LINE_NUMBER . "=$resumeLineNumber" . FILE_LINE_SEP;
    }

    write_to_file( $verificationResumeTmpFileHandle,
                   $verificationResumeTmpFilename,
                   $text );
  };

  close_file_handle_and_rethrow_eventual_error( $verificationResumeTmpFileHandle,
                                                $verificationResumeTmpFilename,
                                                $@ );

  move_file( $verificationResumeTmpFilename, $context->checksumFilename . "." . VERIFICATION_RESUME_EXTENSION );

  # Take the system time again, in case the operations above (like moving the file) takes a long time.
  # This way, we make sure that at least some time elapses between updates.
  $context->lastVerificationUpdate( Time::HiRes::clock_gettime( CLOCK_MONOTONIC ) );
}


sub open_checksum_file ( $ )
{
  my $context = shift;

  # Generally, knowledgeable Perl people and websites advise opening
  # such UTF-8 files with layer ":utf8", or even better, with layer ":encoding(UTF-8)",
  # which immediately checks the validity of the UTF-8 encoding.
  #
  # The trouble is, if you do that, you will have little control about any encoding errors
  # that Perl sees. Even if you open with ":utf8", the next innocent-looking operation,
  # such as removing end-of-line characters with a simple regular expression, will
  # suddently start raising UTF-8 encoding errors.
  #
  # It is best to open the file in binary mode, and then handle encoding conversions yourself.
  # This way, you can generate better error messages that include the line number that failed.

  eval
  {
    $context->checksumFileHandle( open_file_for_binary_reading( $context->checksumFilename ) );

    eval
    {
      my $firstTextLine = read_text_line_raw( $context->checksumFileHandle );

      if ( ! defined ( $firstTextLine ) )
      {
        die "The file is empty.\n";
      }

      if ( ! remove_str_prefix( \$firstTextLine, UTF8_BOM_AS_BYTES ) )
      {
        die "The file does not begin with a UTF-8 BOM.\n"
      }

      if ( ! remove_str_prefix( \$firstTextLine, FILE_FIRST_LINE_PREFIX ) )
      {
        die "The file does not begin with the file format header.\n"
      }

      if ( ! is_plain_ascii( $firstTextLine ) )
      {
        die "Invalid format version.\n";
      }

      if ( $firstTextLine ne FILE_FORMAT_VERSION )
      {
        die "The file has an unsupported format version of " . format_str_for_message( $firstTextLine ) . ".\n";
      }
    };

    if_error_close_file_handle_and_rethrow( $context->checksumFileHandle,
                                            $context->checksumFilename,
                                            $@ );
  };

  rethrow_eventual_error_with_filename( $context->checksumFilename, $@ );

  $context->checksumFileLineNumber( 1 );
}


sub create_update_common ( $ $ )
{
  my $optionName = shift;
  my $context    = shift;

  if ( scalar( @ARGV ) > 1 )
  {
    die "Option '--$optionName' takes at most one argument.\n";
  }

  my $dirname = scalar( @ARGV ) == 0 ? CURRENT_DIRECTORY : $ARGV[0];

  $dirname = remove_eventual_trailing_directory_separators( $dirname );

  if ( not -d $dirname )
  {
    die qq<Directory "$dirname" does not exist.\n>;
  }

  $context->startDirname( $dirname );
}


sub create_in_progress_checksum_file ( $ )
{
  my $context = shift;

  # Note that, if this script gets interrupted interrupted (SIGINT / Ctrl+C),
  # we will leave the IN_PROGRESS_EXTENSION file behind.
  # The user may want to manually recover most of it, except perhaps the end.
  # We could attempt to delete this file in the case of SIGINT, but keep in mind
  # that this process may die because of some other signal or even SIGKILL.

  $context->checksumFilenameInProgress( $context->checksumFilename . "." . IN_PROGRESS_EXTENSION );

  $context->checksumFileHandleInProgress( create_or_truncate_file_for_utf8_writing( $context->checksumFilenameInProgress ) );

  eval
  {
    use constant LATIN_SMALL_LETTER_N_WITH_TILDE => "\x{00F1}";

    my $header = UTF8_BOM . FILE_FIRST_LINE_PREFIX . FILE_FORMAT_VERSION . FILE_LINE_SEP .
                 FILE_LINE_SEP .
                 FILE_COMMENT . " Warning: The filename sorting order will probably be unexpected for humans," . FILE_LINE_SEP .
                 FILE_COMMENT . " like this sorted sequence: 'Z', 'a', '@{[ LATIN_SMALL_LETTER_N_WITH_TILDE ]}'." . FILE_LINE_SEP .
                 FILE_LINE_SEP;

    write_to_file( $context->checksumFileHandleInProgress,
                   $context->checksumFilenameInProgress,
                   $header );
  };

  if_error_close_file_handle_and_rethrow( $context->checksumFileHandleInProgress,
                                          $context->checksumFilenameInProgress,
                                          $@ );
}


sub self_test ()
{
  self_test_break_up_dir_only_path;
  self_test_utf8;
  self_test_escape_filename;
  self_test_parse_unsigned_integer;
}


Class::Struct::struct( CFilenameFilter =>
                       [ # A bracket here means we will be creating an array-based struct (as opposed to a hash based).
                         isInclude => '$',
                         regex     => '$',
                       ]
                     );

sub addFilenameFilter ( $ $ $ )
{
  my $isInclude          = shift;
  my $expression         = shift;
  my $filenameFiltersRef = shift;

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    check_string_is_marked_as_native( $expression, "regular expression on command line" );
  }

  my $expressionUtf8 = convert_native_to_utf8( $expression );

  my $regexObject;

  # In order to test an error below, use a malformed regular expression like "(?z)",
  # where modifier 'z' is invalid.

  eval
  {
    $regexObject = qr/$expressionUtf8/;
  };

  my $errMsg = $@;

  if ( $errMsg )
  {
    # This is an example of an error message that qr// may generate:
    #
    #   Sequence (?z...) not recognized in regex; marked by <-- HERE in m/(?z <-- HERE )/ at ./rdchecksum.pl line 4738.
    #
    # It is not only ugly: it is also leaking the source code filename. The indicated error slocation is also wrong,
    # because the error is not in that file, but in the regular expression supplied by the user.
    # Therefore, adding a filename and a line number to the error cause will only help confuse the user.
    # There is not much we can do about it. I even raised a bug about this:
    #   Unprofessional error messages with source filename and line number
    #   https://github.com/Perl/perl5/issues/17898
    # Unfortunately, I only got negative responses from the Perl community.

    die "Error in option '--" . ( $isInclude ? OPT_NAME_INCLUDE : OPT_NAME_EXCLUDE ) . "', " .
        "regular expression " .  format_str_for_message( $expression ) . ": " . $errMsg;
  }

  my $filterElem =  CFilenameFilter->new(
                      isInclude => $isInclude,
                      regex => $regexObject,
                    );

  push @$filenameFiltersRef, $filterElem;
}


# ----------- Main routine -----------

sub main ()
{
  # I think I have all Unicode issues in filenames sorted, so we do not need to change
  # the character encoding in stdout/stderr anymore. Anything this script writes
  # to stdout/stderr has to be clean ASCII (charcode < 127), or the
  # Perl string has to be marked internally as a native/raw byte string,
  # see convert_utf8_to_native() etc.
  if ( FALSE )
  {
    # We are assuming here that stdout and stderr take UTF-8.
    # If you are using a terminal that is expecting some other encoding,
    # non-ASCII characters will appear as garbage.

    binmode STDOUT, ":utf8"
      or die "Cannot set stdout to UTF-8: $!\n";

    binmode STDERR, ":utf8"
      or die "Cannot set stderr to UTF-8: $!\n";
  }

  # Make sure that buffering is active, for performance reasons.
  STDOUT->autoflush( 0 );
  STDERR->autoflush( 0 );

  init_locale_info();

  if ( not $Config{ use64bitint } )
  {
    die "This script requires a Perl interpreter with 64-bit integer support (see build flag USE_64_BIT_INT).\n"
  }

  my $arg_help       = FALSE;
  my $arg_h          = FALSE;
  my $arg_help_pod   = FALSE;
  my $arg_version    = FALSE;
  my $arg_license    = FALSE;

  my $arg_create     = FALSE;
  my $arg_verify     = FALSE;
  my $arg_update     = FALSE;
  my $arg_self_test  = FALSE;

  my $arg_checksum_filename = DEFAULT_CHECKSUM_FILENAME;
  my $arg_resumeFromLine;
  my $arg_verbose = FALSE;
  my $arg_checksumType = DEFAULT_CHECKSUM_TYPE;
  my $arg_noUpdateMessages = FALSE;
  my @filenameFilters;

  Getopt::Long::Configure( "no_auto_abbrev",  "prefix_pattern=(--|-)", "no_ignore_case" );

  my %options =
  (
    OPT_NAME_HELP()      => \$arg_help,
    'h'                  => \$arg_h,
    'help-pod'           => \$arg_help_pod,
    'version'            => \$arg_version,
    'license'            => \$arg_license,
    OPT_NAME_SELF_TEST() => \$arg_self_test,

    OPT_NAME_CREATE() => \$arg_create,
    OPT_NAME_VERIFY() => \$arg_verify,
    OPT_NAME_UPDATE() => \$arg_update,

    'checksum-file=s' => \$arg_checksum_filename,
    OPT_NAME_RESUME_FROM_LINE . "=s" => \$arg_resumeFromLine,  # Do not let GetOptions() do the integer validation, because it is not reliable: you can get a floating-point back.
    OPT_NAME_VERBOSE() => \$arg_verbose,
    OPT_NAME_CHECKSUM_TYPE() . "=s" => \$arg_checksumType,
    OPT_NAME_NO_UPDATE_MESSAGES() => \$arg_noUpdateMessages,
    OPT_NAME_INCLUDE() . "=s" => sub { addFilenameFilter( TRUE , $_[1], \@filenameFilters ); },
    OPT_NAME_EXCLUDE() . "=s" => sub { addFilenameFilter( FALSE, $_[1], \@filenameFilters ); },
  );

  if ( exists $ENV{ (OPT_ENV_VAR_NAME) } )
  {
    my ( $getOptionsFromStringResult, $otherArgumentsInString ) = GetOptionsFromString( $ENV{ (OPT_ENV_VAR_NAME) }, %options );

    if ( not $getOptionsFromStringResult )
    {
      # GetOptionsFromString() has already printed an error message, but it did not say where the error came from.
      die "Error parsing options in environment variable @{[ OPT_ENV_VAR_NAME ]}.\n";
    }

    if ( @$otherArgumentsInString )
    {
      die "Environment variable @{[ OPT_ENV_VAR_NAME ]} contains the following excess arguments: @$otherArgumentsInString\n";
    }
  }

  my $getOptionsResult = GetOptions( %options );

  if ( not $getOptionsResult )
  {
    # GetOptions() has already printed an error message.
    return EXIT_CODE_FAILURE;
  }

  if ( $arg_help || $arg_h )
  {
    print_help_text();
    return EXIT_CODE_SUCCESS;
  }

  if ( $arg_help_pod )
  {
    write_stdout( "This file is written in Perl's Plain Old Documentation (POD) format\n" );
    write_stdout( "and has been generated with option --help-pod .\n" );
    write_stdout( "Run the following Perl commands to convert it to HTML or to plain text for easy reading:\n" );
    write_stdout( "\n" );
    write_stdout( "  pod2html README.pod >README.html\n" );
    write_stdout( "  pod2text README.pod >README.txt\n" );
    write_stdout( "\n\n" );
    write_stdout( get_pod_from_this_script() );
    write_stdout( "\n" );
    return EXIT_CODE_SUCCESS;
  }

  if ( $arg_version )
  {
    write_stdout( "$Script version " . SCRIPT_VERSION . "\n" );
    return EXIT_CODE_SUCCESS;
  }

  if ( $arg_license )
  {
    write_stdout( get_license_text() );
    return EXIT_CODE_SUCCESS;
  }

  if ( $arg_self_test )
  {
    write_stdout( "Running the self-tests...\n" );
    self_test();
    write_stdout( "\nSelf-tests finished.\n" );
    exit EXIT_CODE_SUCCESS;
  }


  if ( $arg_checksum_filename eq "" )
  {
    die "The checksum list filename is empty.\n";
  }


  if ( lc( $arg_checksumType ) eq lc( CHECKSUM_TYPE_ADLER_32 ) )
  {
    $arg_checksumType = CHECKSUM_TYPE_ADLER_32;
  }
  elsif ( lc( $arg_checksumType ) eq lc( CHECKSUM_TYPE_CRC_32 ) )
  {
    $arg_checksumType = CHECKSUM_TYPE_CRC_32;
  }
  elsif ( lc( $arg_checksumType ) eq lc( CHECKSUM_TYPE_NONE ) )
  {
    $arg_checksumType = CHECKSUM_TYPE_NONE;
  }
  else
  {
    die "Unsupported checksum type " . format_str_for_message( $arg_checksumType ) . ".\n";
  }

  Class::Struct::struct( COperationContext =>
                         [ # A bracket here means we will be creating an array-based struct (as opposed to a hash based).

                           operation                    => '$',
                           startDirname                 => '$',
                           dirStackUtf8                 => '@',  # We only actually require the directory stack during OPERATION_UPDATE.

                           checksumFilename             => '$',
                           checksumFileHandle           => '$',
                           checksumFilenameInProgress   => '$',
                           checksumFileHandleInProgress => '$',

                           # The first line number is 1, and corresponds to the file format header.
                           # This variable holds the line number of the last text line read from the file.
                           checksumFileLineNumber       => '$',

                           currentFileOnChecksumList    => '$',  # Only used during OPERATION_UPDATE.

                           checksumType                 => '$',
                           verbose                      => '$',
                           enableUpdateMessages         => '$',

                           filenameFilters              => '@',
                           defaultIsInclude             => '$',

                           verificationReportFileHandle => '$',
                           verificationReportFilename   => '$',

                           totalSizeProcessed           => '$',
                           totalFileSize                => '$',

                           directoryCountOk             => '$',
                           directoryCountFailed         => '$',
                           fileCountOk                  => '$',
                           fileCountFailed              => '$',

                           # These counters are for OPERATION_UPDATE only.
                           fileCountAdded               => '$',
                           fileCountRemoved             => '$',
                           fileCountChanged             => '$',
                           fileCountUnchanged           => '$',

                           lastProgressUpdate           => '$',
                           lastVerificationUpdate       => '$',
                           startTime                    => '$',
                         ]
                       );

  my $context =
      COperationContext->new(

        enableUpdateMessages    => FALSE,

        totalSizeProcessed      => 0,
        totalFileSize           => 0,

        directoryCountOk        => 0,
        directoryCountFailed    => 0,
        fileCountOk             => 0,
        fileCountFailed         => 0,

        fileCountAdded          => 0,
        fileCountRemoved        => 0,
        fileCountChanged        => 0,
        fileCountUnchanged      => 0,
      );

  $context->filenameFilters( \@filenameFilters );
  $context->defaultIsInclude( TRUE );

  if ( scalar( @filenameFilters ) != 0 )
  {
    if (  ! $arg_create &&
          ! $arg_update )
    {
      die "Options '--@{[ OPT_NAME_INCLUDE ]}' and '--@{[ OPT_NAME_EXCLUDE ]}' are only compatible" .
          " with '--@{[ OPT_NAME_CREATE ]}' or '--@{[ OPT_NAME_UPDATE ]}'.\n";
    }

    $context->defaultIsInclude( FALSE );

    foreach my $elem ( @filenameFilters )
    {
      if ( ! $elem->isInclude )
      {
        $context->defaultIsInclude( TRUE );
        last;
      }
    }
  }

  $context->checksumFilename( $arg_checksum_filename );
  $context->checksumType( $arg_checksumType );

  $context->verbose( $arg_verbose );

  # Unfortunately, Perl does not document any way to get an error code from Time::HiRes::clock_gettime(),
  # in order to know whether CLOCK_MONOTONIC is supported. But most systems do support it,
  # and it is a lot of work to find a good alternative.
  $context->startTime( Time::HiRes::clock_gettime( CLOCK_MONOTONIC ) );
  $context->lastProgressUpdate( $context->startTime );

  $SIG{INT}  = \&signal_handler;
  $SIG{TERM} = \&signal_handler;
  $SIG{HUP}  = \&signal_handler;

  my $exitCode;

  my $previousIncompatibleOption;

  check_multiple_incompatible_options( $arg_create   , "--" . OPT_NAME_CREATE, \$previousIncompatibleOption );
  check_multiple_incompatible_options( $arg_verify   , "--" . OPT_NAME_VERIFY, \$previousIncompatibleOption );
  check_multiple_incompatible_options( $arg_update   , "--" . OPT_NAME_UPDATE, \$previousIncompatibleOption );


  my $resumeFromLineAsInt;

  if ( defined( $arg_resumeFromLine ) )
  {
    check_is_only_compatible_with_option( "--" . OPT_NAME_RESUME_FROM_LINE,
                                          $arg_verify,
                                          "--" . OPT_NAME_VERIFY );
    eval
    {
      $resumeFromLineAsInt = parse_unsigned_integer( $arg_resumeFromLine );

      if ( $resumeFromLineAsInt <= 1 )
      {
        die "Invalid line number.\n";
      }
    };

    my $errorMessage = $@;

    if ( $errorMessage )
    {
      die "Error in option '--@{[ OPT_NAME_RESUME_FROM_LINE ]}', value " . format_str_for_message( $arg_resumeFromLine ) . ": $errorMessage";
    }
  }
  else
  {
    $resumeFromLineAsInt = 0;
  }


  if ( $arg_noUpdateMessages )
  {
    check_is_only_compatible_with_option( "--" . OPT_NAME_NO_UPDATE_MESSAGES,
                                          $arg_update,
                                          "--" . OPT_NAME_UPDATE );
  }

  if ( $arg_create )
  {
    create_update_common( OPT_NAME_CREATE, $context );

    $context->operation( OPERATION_CREATE );

    # We could silently overwrite any existing file, but it can take a lot of time to generate
    # such a checksum list file, so we do not want the user to inadvertently lose one.

    if ( -e $context->checksumFilename )
    {
      die "Filename " . format_str_for_message( $arg_checksum_filename ) . " already exists.\n";
    }

    create_in_progress_checksum_file( $context );

    eval
    {
      $exitCode = scan_disk_files( $context );
    };

    close_file_handle_and_rethrow_eventual_error( $context->checksumFileHandleInProgress,
                                                  $context->checksumFilenameInProgress,
                                                  $@ );

    move_file( $context->checksumFilenameInProgress,
               $context->checksumFilename );
  }
  elsif ( $arg_update )
  {
    create_update_common( OPT_NAME_UPDATE, $context );

    $context->operation( OPERATION_UPDATE );

    $context->enableUpdateMessages( $arg_noUpdateMessages ? FALSE : TRUE );

    open_checksum_file( $context );

    eval
    {
      create_in_progress_checksum_file( $context );

      eval
      {
        $exitCode = scan_disk_files( $context );
      };

     close_file_handle_and_rethrow_eventual_error( $context->checksumFileHandleInProgress,
                                                   $context->checksumFilenameInProgress,
                                                   $@ );
    };

    close_file_handle_and_rethrow_eventual_error( $context->checksumFileHandle,
                                                  $context->checksumFilename,
                                                  $@ );
    if ( ! $g_wasInterruptionRequested )
    {
      # If you pass the wrong options or the wrong starting directory, updating a checksum list file may
      # unexpectedly empty it. That is often irritating, because creating a new checksum list file can take a very long time.
      # Therefore, always back the old checksum list file up. This way, the user has a chance to recover
      # the old version.

      if ( ! $g_wasInterruptionRequested )
      {
        my $backupFilename = $context->checksumFilename . "." . BACKUP_EXTENSION;

        write_stdout( "The old checksum list file has been backed up with filename: " . format_filename_for_console( $backupFilename ) . "\n" );

        move_file( $context->checksumFilename,
                   $backupFilename );

        move_file( $context->checksumFilenameInProgress,
                   $context->checksumFilename );
      }
    }
  }
  elsif ( $arg_verify )
  {
    if ( scalar( @ARGV ) != 0 )
    {
      die "Option '--@{[ OPT_NAME_VERIFY ]}' takes no arguments.\n";
    }

    $context->operation( OPERATION_VERIFY );

    open_checksum_file( $context );

    eval
    {
      $context->verificationReportFilename( $context->checksumFilename . "." . VERIFICATION_REPORT_EXTENSION );

      $context->verificationReportFileHandle( create_or_truncate_file_for_utf8_writing( $context->verificationReportFilename ) );

      eval
      {
        my $header = UTF8_BOM . REPORT_FIRST_LINE_PREFIX . FILE_FORMAT_VERSION . FILE_LINE_SEP .
                     FILE_LINE_SEP;

        write_to_file( $context->verificationReportFileHandle,
                       $context->verificationReportFilename,
                       $header );

        eval
        {
          $exitCode = scan_listed_files( $resumeFromLineAsInt, $context );
        };

        my $errMsg = $@;

        if ( $errMsg )
        {
          # Attempt to write the error to the report file.
          # Note that we are ignoring any errors from 'print' below.
          # After all, the original error may have been caused by trying to write to this same file.
          my $msg = FILE_COMMENT . " Error during verification: " . remove_eol_from_perl_error( $errMsg ) . FILE_LINE_SEP;
          my $fd = $context->verificationReportFileHandle;
          print $fd $msg;

          die $errMsg;
        }
      };

      close_file_handle_and_rethrow_eventual_error( $context->verificationReportFileHandle,
                                                    $context->verificationReportFilename,
                                                    $@ );
    };

    close_file_handle_and_rethrow_eventual_error( $context->checksumFileHandle,
                                                  $context->checksumFilename,
                                                  $@ );
  }
  else
  {
    die "No operation specified." .
        " Examples of operations are '--@{[ OPT_NAME_CREATE ]}' and '--@{[ OPT_NAME_VERIFY ]}'." .
        " Use '--@{[ OPT_NAME_HELP ]}' for more information." .
        "\n";
  }

  if ( $g_wasInterruptionRequested )
  {
    $exitCode = EXIT_CODE_FAILURE;

    # Kill ourselves with the same signal. This is the recommended way of terminating
    # upon reception of a signal, after doing any clean-up work. Otherwise,
    # the parent process has no way of knowing that this process actually terminated
    # because a particular signal was received.

    $SIG{ $g_wasInterruptionRequested } = "DEFAULT";

    if ( 1 != kill( $g_wasInterruptionRequested, $$ ) )
    {
      write_stderr( "\n$Script: Error resending received signal $g_wasInterruptionRequested to itself.\n" );
      exit( EXIT_CODE_FAILURE );
    }


    # If killing itself fails, we do not want the script to carry on.

    write_stderr( "\n$Script: Cannot kill itself with signal $g_wasInterruptionRequested, terminating now.\n" );

    exit( EXIT_CODE_FAILURE );
  }

  return $exitCode;
}


eval
{
  exit main();
};

my $errorMessage = $@;

# We want the error message to be the last thing on the screen,
# so we need to flush the standard output first.
STDOUT->flush();

print STDERR "\nError running '$Script': $errorMessage";

exit EXIT_CODE_FAILURE;
