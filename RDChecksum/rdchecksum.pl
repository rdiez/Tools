#!/usr/bin/perl

# The following POD section contains placeholders, so it has to be preprocessed by this script first.
#
# HelpBeginMarker

=head1 OVERVIEW

PROGRAM_NAME version SCRIPT_VERSION

Creates or verifies a list of file checksums (hashes).

=head1 RATIONALE

In an ideal world, all filesystems would have integrated data checksums like ZFS does.
This tool is a poor man's substitute for such filesystem-level checksums.
It can also help detect data corruption when transferring files over a network.

Storage devices are supposed to use checksums to detect or even correct data errors,
and most transport protocols should do the same. However, computer systems are becoming
more complex and more brittle at the same time.

However, I have very rarely performed a large backup or file copy operation without hitting some data
integrity issue. For example, interrupting with Ctrl+C an rsync transfer to an SMB network share
tends to corrupt the destination files, and resuming the transfer will not fix such corruption.

There are many alternative checksum/hash tools around, but I decided to write a new one out of frustration
with the existing software.

=head1 USAGE

 ./SCRIPT_NAME --create [options] [--] [directory]
 ./SCRIPT_NAME --verify [options]

Argument 'directory' is optional and defaults to the current directory ('.').

If 'directory' is the current directory ('.'), then the filenames in the checksum list will be like 'file1.txt'.
Otherwise, the filenames will be like 'directory/file1.txt'.

The checksum file itself (DEFAULT_CHECKSUM_FILENAME by default) and any other temporary files with that basename
will be automatically skipped from the checksum list (assuming that the checksum filename's basedir and
argument 'directory' match, because mixing relative and absolute paths will confuse the script).

Usage examples:

 cd some-directory && /somewhere/SCRIPT_NAME --create

 cd some-directory && /somewhere/SCRIPT_NAME --verify

Command-line options are read from environment variable OPT_ENV_VAR_NAME first, and then from the command line.

=head1 OPTIONS

=over

=item *

B<-h, --help>

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

B<-->

Terminate options processing. Useful to avoid confusion between options and filenames
that begin with a hyphen ('-'). Recommended when calling this script from another script,
where the filename comes from a variable or from user input.

=item *

B<< --checksum-file=filename >>

The default filename is DEFAULT_CHECKSUM_FILENAME .

=item *

B<< --create  >>

Creates a checksum file.

When creating a checksum file named DEFAULT_CHECKSUM_FILENAME, a temporary file named DEFAULT_CHECKSUM_FILENAME.IN_PROGRESS_EXTENSION
will also be created.

=item *

B<< --verify  >>

Verifies the files listed in the checksum file.

=back

=head1 EXIT CODE

Exit code: 0 on success, some other value on error.

=head1 SIGNALS

SIGINT (usually Ctrl+C) makes this script gracefully stop. Any other signal will kill it.

=head1 USING I<< background.sh >>

It is probably most convenient to run this tool with another script of mine called I<< background.sh >>,
so that it runs with low priority and you get a visual notification when finished.

The optional memory limit below reduces the performance impact on other processes by preventing
the checksum operation from flushing the complete Linux filesystem cache. For example:

 export BACKGROUND_SH_LOW_PRIORITY_METHOD="systemd-run"
 cd some-directory
 background.sh --memory-limit=512M /somewhere/SCRIPT_NAME --verify

=head1 CHECKSUM FILE

The generated file with the list of checksums looks like this:

 2019-12-31T20:15:01.200  CRC-32  12345678  1,234,567  subdir/file1.txt
 2019-12-31T20:15:01.300  CRC-32  90ABCDEF  2,345,678  subdir/file2.txt

=head1 CAVEATS

=over

=item *

This tool is rather simple at the moment. The only checksum type supported at the moment ist CRC-32 from zlib.

If you need more features, drop me a line.

=item *

There is no symbolic link loop detection (protection against circular links).

In such a situation, this tool will run forever.

=back

=head1 FEEDBACK

Please send feedback to rdiezmail-tools at yahoo.de

=head1 LICENSE

Copyright (C) 2020 R. Diez

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
use Class::Struct qw();


use constant SCRIPT_VERSION => "0.52";

use constant OPT_ENV_VAR_NAME => "RDCHECKSUM_OPTIONS";
use constant DEFAULT_CHECKSUM_FILENAME => "FileChecksums.txt";

use constant IN_PROGRESS_EXTENSION => "inProgress";

use constant PROGRAM_NAME => "RDChecksum";

use constant FILE_FORMAT_V1 => "1";

use constant FILE_THOUSANDS_SEPARATOR => ",";

use constant FILE_COL_SEPARATOR => "\011";  # Tab, \t, ASCII code 9.

use constant FILE_LINE_SEP => "\012";  # "\n" is defined in Perl as "logical newline". Avoid eventual portability
                                       # problems by using its ASCII code. Name: LF, decimal: 10, hex: 0x0A.

use constant FILE_FIRST_LINE_PREFIX => PROGRAM_NAME . " - list of checksums - file format version ";

use constant FILE_FIRST_LINE => FILE_FIRST_LINE_PREFIX . FILE_FORMAT_V1;

# The UTF-8 BOM actually consists of 3 bytes: EF, BB, BF.
# However, the UTF-8 I/O layer that we are using will convert it to U+FEFF.
use constant UTF_BOM => "\x{FEFF}";


use constant OPERATION_CREATE => 1;
use constant OPERATION_VERIFY => 2;


# use constant CHECKSUM_METHOD => "Adler-32";
use constant CHECKSUM_METHOD => "CRC-32";

use constant CHECKSUM_IF_EMPTY => 0;

use constant PROGRESS_DELAY => 4;  # In seconds.


# ----------- Generic constants and routines -----------

use constant TRUE  => 1;
use constant FALSE => 0;

use constant EXIT_CODE_SUCCESS => 0;
# Beware that other errors, like those from die(), can yield other exit codes.
# It is very hard to guarantee that all possible failures will always yield
# an exit code of 1.
use constant EXIT_CODE_FAILURE => 1;


# Do not enable this for production, because Perl's internal behaviour may change and still
# remain compatible, breaking the checks but not really affecting functionality.
use constant ENABLE_UTF8_RESEARCH_CHECKS => FALSE;


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


# Returns a true value if the string ends in the given 'prefix' argument.

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
  my $str    = shift;
  my $prefix = shift;  # Pass here a reference to a string.

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

  if ( str_ends_with( $str, $suffix ) )
  {
    return substr( $str, 0, length( $str ) - length( $suffix ) );
  }
  else
  {
    return $str;
  }
}


sub plural_s ( $ )
{
  return ( $_[0] == 1 ) ? "" : "s";
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
                               # in the loop below, so just do it once at the beginnig.

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


sub write_stdout ( $ )
{
  ( print STDOUT $_[0] ) or
     die "Error writing to standard output: $!\n";
}

sub write_stderr ( $ )
{
  ( print STDERR $_[0] ) or
     die "Error writing to standard error: $!\n";
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


sub open_file_for_utf8_reading ( $ )
{
  my $filename = shift;

  # Layer ":raw" disables the automatic end-of-line handling that the default ":crlf" does.
  # I would rather see the end-of-line characters when reading text lines,
  # and deal with them in this script.

  # Layer ":encoding(UTF-8)" checks the data is actually valid UTF-8, so ":utf8" would probably be faster.
  # I would rather detect malformed or corrupted input early than pass it along.

  open( my $fileHandle, "<:raw:encoding(UTF-8)", $filename )
    or die "Cannot open file ". format_str_for_message( $filename ) . ": $!\n";

  return $fileHandle;
}


# Read the next line, skipping any empty, whitespace-only or comment lines.
#
# Returns 'undef' if end of file is reached.

sub read_text_line ( $ $ $ )
{
  my $fileHandle = shift;
  my $filename   = shift;
  my $lineNumber = shift;

  my $whitespaceExpression = "[\x20\x09]";  # Whitespace is only a space or a tab.

  for ( ; ; )
  {
    my $textLine = read_text_line_raw( $fileHandle, $filename );

    if ( ! defined( $textLine ) )
    {
      return undef;
    }

    ++$$lineNumber;

    if ( ENABLE_UTF8_RESEARCH_CHECKS )
    {
      # We are (normally) reading from a file that we have declared to be in UTF-8,
      # so we expect all strings to be flagged as UTF-8.
      if ( ! utf8::is_utf8( $textLine ) )
      {
        die "\$textLine is unexpectedly marked as native/byte string.\n";
      }
    }

    if ( FALSE )
    {
      write_stdout( "Line read: " . $textLine . "\n" );
    }


    # POSSIBLE OPTIMISATION: Removing blanks could perhaps be done faster with transliterations (tr///).
    # Strip leading blanks.
    my $withoutLeadingWhitespace = $textLine;
    $withoutLeadingWhitespace =~ s/^$whitespaceExpression*//;

    if ( length( $withoutLeadingWhitespace ) == 0 )
    {
      if ( FALSE )
      {
        write_stdout( "Discarding empty or whitespace-only line.\n" );
      }

      next;
    }

    if ( str_starts_with( $withoutLeadingWhitespace, "#" ) )
    {
      if ( FALSE )
      {
        write_stdout( "Discarding comment line: $textLine\n" );
      }

      next;
    }

    my $withoutTrailingWhitespace = $withoutLeadingWhitespace;
    $withoutTrailingWhitespace =~ s/$whitespaceExpression*\z//;

    my $str = $withoutTrailingWhitespace;

    if ( FALSE )
    {
      write_stdout( "Resulting text line: <$str>\n" );
    }

    return $str;
  }
}


sub read_text_line_raw ( $ $ )
{
  my $filehandle = shift;
  my $filename   = shift;

  if ( eof( $filehandle ) )
  {
    return undef;
  }

  my $textLine = readline( $filehandle );

  if ( ! defined( $textLine ) )
  {
    die "Error reading a text line from file " . format_str_for_message( $filename ) . ": $!\n";
  }


  # Remove the trailing new-line character, if any (the last line may not have any).
  # Accept both Linux and Windows end-of-line characters.
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
  my $fd = $_[0];

  ( print $fd $_[2] ) or
    die "Cannot write to file " . format_str_for_message( $_[1] ) . ": $!\n";
}


# It is very rare that closing a file handle fails. This is usually only the case
# if it has already been closed (or if there is some serious memory corruption).
#
# If closing the file handle fails, it would be interesting to know the related
# filename, but that is a rare error, and it is not worth the effort.

sub close_file_handle_and_rethrow_eventual_error ( $ $ )
{
  my $fileHandle       = shift;
  my $errorMsgFromEval = shift;

  if ( $errorMsgFromEval )
  {
    # Close the file handle before propagating the first error.
    #
    # Do not die from an eventual error from close(), because we would otherwise be
    # hiding the first error that happened.
    #
    # Writing to STDERR may also fail, but ignore any such eventual error
    # for the same reason.

    close( $fileHandle )
      or print STDERR "Warning: Internal error in '$Script': Cannot close file handle: $!\n";

    die $errorMsgFromEval;
  }

  close( $fileHandle ) or
    die "Internal error: Cannot close file handle: $!\n";
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

    close_file_handle_and_rethrow_eventual_error( $fileHandle, $@ );
  };

  rethrow_eventual_error_with_filename( $filename, $@ );

  return $fileContent;
}


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


  # Replace some known placeholders. This is the only practical way to make sure
  # that the script name and version number in the help text are always right.
  # If you duplicate name and version in the source code and in the help text,
  # they will inevitably get out of sync at some point in time.
  #
  # There are faster ways to replace multiple placeholders, but optimising this
  # is not worth the effort.

  $podAsStr =~ s/PROGRAM_NAME/@{[ PROGRAM_NAME ]}/gs;
  $podAsStr =~ s/SCRIPT_NAME/$Script/gs;
  $podAsStr =~ s/SCRIPT_VERSION/@{[ SCRIPT_VERSION ]}/gs;
  $podAsStr =~ s/OPT_ENV_VAR_NAME/@{[ OPT_ENV_VAR_NAME ]}/gs;
  $podAsStr =~ s/DEFAULT_CHECKSUM_FILENAME/@{[ DEFAULT_CHECKSUM_FILENAME ]}/gs;
  $podAsStr =~ s/IN_PROGRESS_EXTENSION/@{[ IN_PROGRESS_EXTENSION ]}/gs;

  return $podAsStr;
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

my $g_wasInterruptionRequested = FALSE;

sub sig_int_handler
{
  if ( $g_wasInterruptionRequested )
  {
    write_stdout( "\n$Script: Request to stop (SIGINT) received again, but stopping has not completed yet...\n" );
  }
  else
  {
    write_stdout( "\n$Script: Stopping upon reception of SIGINT...\n" );
  }

  $g_wasInterruptionRequested = TRUE;
}


sub update_progress ( $ $ )
{
  my $filename = shift;
  my $context  = shift;

  my $currentTime = Time::HiRes::clock_gettime( CLOCK_MONOTONIC );

  # Do not update the screen every time, but only every few seconds,
  # to avoid using too much CPU time (or file space, if the output
  # is redirected to a file).

  if ( $currentTime < $context->lastProgressUpdate + PROGRESS_DELAY )
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

  $txt .= format_human_friendly_elapsed_time( $currentTime - $context->startTime, FALSE ) . " at " . $speed . ", ";

  $txt .= "curr: $filename";

  STDERR->flush();

  write_stdout( $txt . "\n" );

  STDOUT->flush();

  $context->lastProgressUpdate( $currentTime );
}


# Warning: This routine can return undef on SIGINT.

sub checksum_file ( $ $ $ )
{
  my $filename       = shift;
  my $checksumMethod = shift;
  my $context        = shift;

  my $totalReadByteCount = 0;
  my $checksum = undef;

  my $fileHandle = open_file_for_binary_reading( $filename );

  eval
  {
    # I believe that standard tool 'cat' uses a 128 KiB buffer size under Linux.
    use constant SOME_ARBITRARY_BUFFER_SIZE_CHKSUM => 128 * 1024;
    my $readBuffer;

    for ( ; ; )
    {
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
        last;
      }

      $totalReadByteCount += $readByteCount;

      $context->totalSizeProcessed( $context->totalSizeProcessed + $readByteCount );

      if ( $checksumMethod eq "Adler-32" )
      {
        # The 'seed' is documented to be 1. Compress::Zlib::adler32() does return 1 if called with
        # a zero-lenght buffer. Passing 2 binary zeros as data makes the Adler-32 checksum change,
        # so the starting value seems to be working OK.

        $checksum = Compress::Zlib::adler32( $readBuffer, $checksum );
      }
      elsif ( $checksumMethod eq "CRC-32" )
      {
        # The 'seed' is not clear. Compress::Zlib::crc32() returns 0 if called with
        # a zero-lenght buffer. Passing 2 binary zeros as data makes the CRC-32 checksum change,
        # so the starting value seems to be working OK.

        $checksum = Compress::Zlib::crc32( $readBuffer, $checksum );
      }
      else
      {
        die "Unsupported checksum method " . format_str_for_message( $checksumMethod ) . ".\n";
      }

      update_progress( $filename, $context );
    }

    if ( $totalReadByteCount == 0 )
    {
      # If the file is empty, we could have skipped opening it.
      # But if we do not open it, we do not actually know whether we have read access to it.
      $checksum = CHECKSUM_IF_EMPTY;
    }
  };

  close_file_handle_and_rethrow_eventual_error( $fileHandle, $@ );

  if ( $g_wasInterruptionRequested )
  {
    return ( undef, undef );
  }
  else
  {
    return( sprintf("%08X", $checksum ), $totalReadByteCount );
  }
}


sub break_up_stat_mtime ( $ )
{
  my $statMtime = shift;

  # We will be outputting the time formatted in ISO 8601.
  # POSIX::strftime() does not support printing fractions of a second.
  # This is a limitation in Perl that should be fixed.
  #
  # Therefore, we need to separate the integer part from the fractional part here.
  # You would normally use tricks like:
  #   my $fractionalPart = $v - int ( $v );
  # Or you could use POSIX::modf( $mtime ).
  # However, I am worried that floating point inaccuracies may give us grief
  # in some obscure case. So I am converting to a string first, which is slow but safe
  # for our purposes.
  #
  # We are losing some precision because Time::HiRes::stat() is converting the timestamp
  # to a floating point value. The underlying filesystem probably uses integers to
  # encode timestamps, so I find this a limitation in Perl that should be fixed.
  # I mean that Perl should give you access to an integer-based timestamp.
  #
  # The timestamp is also going through a conversion to local time in Time::HiRes::stat()
  # and back to UTC in this script, as a floating point, so this further contributes
  # to the inaccuracy.
  #
  # Furthermore, some local times are ambiguous due to sommer time changes, so it can become
  # a problem. The underyling filesystem probably uses UTC, so I find this a limitation
  # in Perl that should be fixed. I mean that Perl should give you access to a UTC timestamp
  # without any local time conversion.
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


use constant SYSCALL_ENCODING_ASSUMPTION => 'UTF-8';  # 'UTF-8' in uppercase and with a hyphen means "follow strict UTF-8 decoding rules".

sub convert_native_to_utf8 ( $ )
{
  my $filename = shift;

  # The filename comes ultimately from readdir and is marked as native/raw byte.
  #
  # We do not know how that string is encoded. Perl does not know. Even the operating system
  # may not know (it may depend on the filesystem encoding, which may not be known).
  #
  # We are assuming here that such strings coming from syscalls are in UTF-8,
  # which is almost always the case on Linux.
  #
  # We need to convert the string to UTF-8 for sorting and other purposes. Even if no conversion
  # is needed, because both source and destination encodings are UTF-8, we still have to flag
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
  # That is, UTF-8 as raw bytes -> internal flagged as UTF-8.

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    if ( utf8::is_utf8( $filename ) )
    {
      die "\$subdirAndFilenameEscaped is unexpectedly marked as UTF-8 string.\n";
    }
  }

  my $filenameUtf8 = Encode::decode( SYSCALL_ENCODING_ASSUMPTION,
                                     $filename,
                                     Encode::FB_CROAK  # Die with an error message if invalid UTF-8 is found.
                                     # Note that, without flag Encode::LEAVE_SRC, the $filename string gets cleared.
                                   );

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    if ( ! utf8::is_utf8( $filenameUtf8 ) )
    {
      die "\$filenameUtf8 is unexpectedly marked as native/byte string.\n";
    }
  }

  return $filenameUtf8;
}


sub convert_utf8_to_native ( $ )
{
  my $filenameUtf8 = shift;

  # Sometimes we have a Perl string flagged as UTF-8, and we need to pass it
  # as a filename to a syscall.
  #
  # We do not know what encoding we should pass to the syscall. Perl does not know.
  # Even the operating system may not know (it may depend on the filesystem encoding,
  # which may not be known).
  #
  # We are assuming here that such strings going into syscalls should be in UTF-8,
  # which is almost always the case on Linux.
  #
  # We need to convert the string to native/raw byte. Even if no conversion is needed,
  # because both source and destination encodings are UTF-8, we still have to flag
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
    if ( ! utf8::is_utf8( $filenameUtf8 ) )
    {
      die "\$filenameUtf8 is unexpectedly marked as native/byte string.\n";
    }
  }

  my $filename = Encode::encode( SYSCALL_ENCODING_ASSUMPTION,
                                 $filenameUtf8,
                                 Encode::FB_CROAK  # Die with an error message if invalid UTF-8 is found.
                                 # Note that, without flag Encode::LEAVE_SRC, the $filenameUtf8string gets cleared.
                               );

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    if ( utf8::is_utf8( $filename ) )
    {
      die "\$filename is unexpectedly marked as UTF-8 string.\n";
    }
  }

  return $filename;
}


sub add_line_for_file ( $ $ $ $ )
{
  my $subdirAndFilename     = $_[0];
  my $subdirAndFilenameUtf8 = $_[1];
  my $fileStats             = $_[2];  # Reference to file stats array.
  my $context               = $_[3];

  my $size = $fileStats->[ 7 ];

  my ( $mtime_integer_part, $mtime_fractional_part ) = break_up_stat_mtime( $fileStats->[ 9 ] );

  my @utc = gmtime( $mtime_integer_part );

  my $iso8601Time = POSIX::strftime( "%Y-%m-%d" . "T" . "%H:%M:%S", @utc ) .
                    "." .
                    $mtime_fractional_part;

  my ( $checksum, $fileSize ) = checksum_file( $subdirAndFilename, CHECKSUM_METHOD, $context );

  if ( $g_wasInterruptionRequested )
  {
    return;
  }

  if ( $fileSize != $size )
  {
    die "File size mismatch. Are the files changing?\n";
  }

  my $sizeStr = AddThousandsSeparators( $size, 3, FILE_THOUSANDS_SEPARATOR );

  # Our escaping only affects characters < 127 and therefore does not interfere with any UTF-8 characters
  # before or after the conversion to UTF-8.
  my $subdirAndFilenameUtf8Escaped = escape_filename( $subdirAndFilenameUtf8 );

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    if ( ! utf8::is_utf8( $subdirAndFilenameUtf8Escaped ) )
    {
      die "\$subdirAndFilenameUtf8Escaped is unexpectedly marked as native/byte string.\n";
    }
  }

  my $line1 = $iso8601Time .
              FILE_COL_SEPARATOR .
              CHECKSUM_METHOD .
              FILE_COL_SEPARATOR .
              $checksum .
              FILE_COL_SEPARATOR .
              $sizeStr .
              FILE_COL_SEPARATOR;

  # Most of the line is plain ASCII and needs no conversion to UTF-8.
  # Only the filename is problematic.

  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    if ( utf8::is_utf8( $line1 ) )
    {
      die "\$line1 is unexpectedly marked as UTF-8 string.\n";
    }
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


# We want to make sure that the sort order does not depend on the platform or on the current locale. Therefore:
# 1) Do not use "use locale;" in this script.
# 2) Make sure that the strings are in UTF-8 when being compared lexicographically. This means that:
#    - Character 'B' comes before 'a', because all uppercase characters come before the lowercase ones.
#    - Character "LATIN CAPITAL LETTER E WITH ACUTE" will not come right after "LATIN CAPITAL LETTER E", but after "Z".

sub lexicographic_utf8_comparator ( $ $ )
{
  if ( ENABLE_UTF8_RESEARCH_CHECKS )
  {
    if ( ! utf8::is_utf8( $_[0] ) )
    {
      die "\$_[0] is unexpectedly marked as native/byte string.\n";
    }

    if ( ! utf8::is_utf8( $_[1] ) )
    {
      die "\$_[1] is unexpectedly marked as native/byte string.\n";
    }
  }

  if ( FALSE )
  {
    write_stdout( "Comparing left : " . $_[0] . "\n" .
                  "Comparing right: " . $_[1] . "\n" );
  }

  return $_[0] cmp $_[1];
};


sub scan_disk_files ( $ )
{
  my $context = shift;

  scan_directory( $context->startDirname,
                  convert_native_to_utf8( $context->startDirname ),
                  $context );

  STDERR->flush();

  my $exitCode = EXIT_CODE_SUCCESS;
  my $msg;

  $msg .= "Directory count: " . AddThousandsSeparators( $context->directoryCountOk, $g_grouping, $g_thousandsSep ) . "\n";

  if ( FALSE )
  {
    $context->directoryCountFailed( 1 );
    $context->fileCountFailed     ( 2 );
  }

  if ( $context->directoryCountFailed != 0 )
  {
    $msg .= "Dir fail count : " . AddThousandsSeparators( $context->directoryCountFailed, $g_grouping, $g_thousandsSep ) . "\n";
    $exitCode = EXIT_CODE_FAILURE;
  }

  $msg .= "File      count: " . AddThousandsSeparators( $context->fileCountOk, $g_grouping, $g_thousandsSep ) . "\n";

  if ( $context->fileCountFailed != 0 )
  {
    $msg .= "File fail count: " . AddThousandsSeparators( $context->fileCountFailed, $g_grouping, $g_thousandsSep ) . "\n";
    $exitCode = EXIT_CODE_FAILURE;
  }

  write_stdout( $msg );

  return $exitCode;
}


my $dirEntryInfoComparator = sub
{
  return lexicographic_utf8_comparator( $a->[ 1 ],
                                        $b->[ 1 ] );
};


sub scan_directory
{
  my $dirname     = shift;
  my $dirnameUtf8 = shift;
  my $context     = shift;

  if ( $g_wasInterruptionRequested )
  {
    return;
  }

  # Prevent filenames that start with the current directory like "./file.txt".
  my $dirnamePrefix;
  my $dirnamePrefixUtf8;

  if ( $dirname eq "." )
  {
    $dirnamePrefix     = "";
    $dirnamePrefixUtf8 = "";
  }
  else
  {
    $dirnamePrefix     = $dirname     . "/";
    $dirnamePrefixUtf8 = $dirnameUtf8 . "/";
  }

  update_progress( $dirname, $context );

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

      # There does not seem to be a way to detect any error in the readdir() call.

      my $dirEntryName= readdir( $dh );

      if ( ! defined( $dirEntryName ) )
      {
        last;
      }

      if ( $dirEntryName eq "." ||
           $dirEntryName eq ".." )
      {
        if ( FALSE )
        {
          write_stdout( "Skipping '$dirEntryName'\n" );
        }

        next;
      }

      my $prefixAndDirEntryName = $dirnamePrefix. $dirEntryName;

      my @dirEntryStats = Time::HiRes::stat( $prefixAndDirEntryName );

      if ( scalar( @dirEntryStats ) == 0 )
      {
        die "Cannot access " . format_str_for_message( $prefixAndDirEntryName ) . ": $!\n";
      }

      my $mode = $dirEntryStats[ 2 ];

      if ( Fcntl::S_ISDIR( $mode ) )
      {
        push @subdirectories, [ $dirEntryName,
                                convert_native_to_utf8( $dirEntryName ),
                                \@dirEntryStats  # We are not actually using this one yet.
                              ];

        next;
      }

      if ( $prefixAndDirEntryName eq $context->checksumFilename           or
           $prefixAndDirEntryName eq $context->checksumFilenameInProgress )
      {
        if ( FALSE )
        {
          write_stdout( "Checksum file $prefixAndDirEntryName skipped.\n" );
        }

        next;
      }

      push @files, [ $dirEntryName,
                     convert_native_to_utf8( $dirEntryName ),
                     \@dirEntryStats
                   ];
    }

    if ( $g_wasInterruptionRequested )
    {
      return;  # Exit the eval.
    }

    my @sortedFileEntries = sort $dirEntryInfoComparator @files;

    foreach my $fileEntry( @sortedFileEntries )
    {
      my $filename = $fileEntry->[ 0 ];

      my $prefixAndFilename = $dirnamePrefix. $filename;

      if ( FALSE )
      {
        write_stdout( "File: $filename\n" );
      }

      eval
      {
        add_line_for_file( $prefixAndFilename,
                           $dirnamePrefixUtf8 . $fileEntry->[ 1 ],
                           $fileEntry->[ 2 ],
                           $context );
      };

      my $errorMsg = $@;

      if ( $g_wasInterruptionRequested )
      {
        last;
      }

      if ( $errorMsg )
      {
        $context->fileCountFailed( $context->fileCountFailed + 1 );

        STDOUT->flush();

        write_stderr( "Error processing file " . format_str_for_message( $prefixAndFilename ) . ": $errorMsg" );
      }
      else
      {
        $context->fileCountOk( $context->fileCountOk + 1 );
      }
    }

    if ( $g_wasInterruptionRequested )
    {
      return;  # Exit the eval.
    }

    my @sortedDirectoryEntries = sort $dirEntryInfoComparator @subdirectories;

    foreach my $subdirEntry ( @sortedDirectoryEntries )
    {
      my $subdirname = $subdirEntry->[ 0 ];

      if ( FALSE )
      {
        write_stdout( "Subdirectory: $subdirname\n" );
      }

      eval
      {
        # Recursive call.
        scan_directory( $dirnamePrefix     . $subdirname,
                        $dirnamePrefixUtf8 . $subdirEntry->[ 1 ],
                        $context );
      };

      my $errorMsg = $@;

      if ( $g_wasInterruptionRequested )
      {
        last;
      }

      if ( $errorMsg )
      {
        $context->directoryCountFailed( $context->directoryCountFailed + 1 );

        STDOUT->flush();

        write_stderr( $errorMsg );
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
    $filename =~ s/^(\040+)/  "%20" x length( $1 ) /e;
  }
  else
  {
    # A single leading space.
    $filename =~ s/^\040/%20/;
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

  $filename =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

  return $filename;
}


# Test code for the escaping routines above.

if ( FALSE )
{
  my $original = " a\tb%c ";

  my $escaped   = escape_filename( $original );
  my $unescaped = unescape_filename( $escaped );

  write_stdout( "Original : <$original>\n");
  write_stdout( "Escaped  : <$escaped>\n");
  write_stdout( "Unescaped: <$unescaped>\n");

  die "Test finished.\n";
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

  34 => "QUOT", # Double quotation mark, in octal: 042

 127  => "DEL", # In octal: 0177

 # Anything above 127 may display as rubbish in a terminal or in a text editor, depending on the encoding,
 # but it will probably cause no big problems like a line break.
);

sub format_str_for_message ( $ )
{
  my $str = shift;

  $str =~ s/([\000-\037\042\177])/ '<' . $escapeTable{ ord $1 } . '>' /eg;

  # This is some arbitrary limit.
  use constant FSFM_MAX_LEN => 300;

  use constant FSFM_SUFFIX => "[...]";

  if ( length( $str ) > FSFM_MAX_LEN )
  {
    $str = substr( $str, 0, FSFM_MAX_LEN - length( FSFM_SUFFIX ) ) . FSFM_SUFFIX;

  }

  return '"' . $str . '"';
}

# Use this code for test purposes only.
if ( FALSE )
{
  my $str;

  for ( my $i = 0 ; $i <= 127; ++$i )
  {
    $str .= chr( $i );
  }

  write_stdout( "Result: " . format_str_for_message( $str ) . "\n" );

  die "Stop.\n";
}


# This alternative to remove thousand separators works, but it cannot use constant FILE_THOUSANDS_SEPARATOR:
#   $expectedFileSize =~ tr/,//d;
my $matchThousandsSeparatorsRegex = qr/${\(FILE_THOUSANDS_SEPARATOR)}/;

sub parse_file_line ( $ $ )
{
  my $textLine = shift;
  my $context  = shift;

  use constant LINE_COMPONENT_COUNT => 5;

  my @textLineComponents;

  eval
  {
    @textLineComponents = split( /\t/, $textLine );

    if ( scalar @textLineComponents != LINE_COMPONENT_COUNT )
    {
      die "Cannot separate the @{[ LINE_COMPONENT_COUNT ]} line components.\n";
    }

    if ( ENABLE_UTF8_RESEARCH_CHECKS )
    {
      # We are (normally) reading from a file that we have declared to be in UTF-8,
      # so we expect all strings to be flagged as UTF-8.
      # Most of them are plain ASCII, so we could turn them into native/byte strings
      # in order to perhaps gain some performance.
      # Only the filename can be problematic.

      for my $str ( @textLineComponents )
      {
        if ( ! utf8::is_utf8( $str ) )
        {
          die "One of the strings read from the file is unexpectedly marked as native/byte string.\n";
        }
      }
    }


    # Remove the thousands separators from the file size.
    $textLineComponents[ 3 ] =~ s/$matchThousandsSeparatorsRegex//g;

    # Unescape the filename.
    # Our escaping only affects characters < 127 and therefore does not interfere with any UTF-8 characters
    # before or after the conversion to UTF-8.
    $textLineComponents[ 4 ] = unescape_filename( $textLineComponents[ 4 ] );

    # It does not look like we need this extra element yet.
    if ( FALSE )
    {
      # $textLineComponents[ 5 ] remains with the original UTF-8 encoding read from the file.
      # We need it later on for sorting purposes.
      push @textLineComponents, $textLineComponents[ 4 ];
    }

    # $textLineComponents[ 4 ] can then be used in syscalls to open the file etc.
    $textLineComponents[ 4 ] = convert_utf8_to_native( $textLineComponents[ 4 ] );
  };

  if ( $@ )
  {
    my $errorMsg = $@;

    die "Error parsing file " . format_str_for_message( $context->checksumFilename ) .
        ", line " . $context->checksumFileLineNumber .
        ", text " . format_str_for_message( $textLine ) .
        ": " . $errorMsg;
  }

  return @textLineComponents;
}


sub scan_listed_files ( $ )
{
  my $context = shift;

  for ( ; ; )
  {
    # We cannot pass a struct member as a reference, so we need a temporary variable.
    my $lineNumber = $context->checksumFileLineNumber;

    my $textLine = read_text_line( $context->checksumFileHandle,
                                   $context->checksumFilename,
                                   \$lineNumber );

    if ( ! defined ( $textLine ) )
    {
      last;
    }

    $context->checksumFileLineNumber( $lineNumber );


    my @textLineComponents = parse_file_line( $textLine, $context );

    my $checksumMethod   = $textLineComponents[ 1 ];
    my $expectedChecksum = $textLineComponents[ 2 ];
    my $expectedFileSize = $textLineComponents[ 3 ];
    my $filename         = $textLineComponents[ 4 ];

    eval
    {
      my @entryStats = Time::HiRes::stat( $filename );

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

      if ( $expectedFileSize ne $detectedFileSize )
      {
        die "File size of " .
            AddThousandsSeparators( $detectedFileSize, $g_grouping, $g_thousandsSep ) .
            " bytes differs from the expected " .
            AddThousandsSeparators( $expectedFileSize, $g_grouping, $g_thousandsSep ) .
            " bytes.\n";
      }

      my ( $calculatedChecksum, $fileSize ) = checksum_file( $filename, $checksumMethod, $context );

      if ( $g_wasInterruptionRequested )
      {
        return;  # Breaks out of eval
      }

      if ( $calculatedChecksum ne $expectedChecksum )
      {
        die "The calculated $checksumMethod checksum " . format_str_for_message( $calculatedChecksum ) .
            " does not match the expected " . format_str_for_message( $expectedChecksum ) . ".\n";
      }
    };

    my $errorMsg = $@;

    if ( $g_wasInterruptionRequested )
    {
      last;
    }

    if ( $errorMsg )
    {
      $context->fileCountFailed( $context->fileCountFailed + 1 );

      STDOUT->flush();

      write_stderr( "Error verifying file " . format_str_for_message( $filename ) . ": $errorMsg" );
    }
    else
    {
      $context->fileCountOk( $context->fileCountOk + 1 );
    }
  }

  STDERR->flush();

  my $exitCode = EXIT_CODE_SUCCESS;
  my $msg;

  $msg .= "Successfully verified: " . AddThousandsSeparators( $context->fileCountOk, $g_grouping, $g_thousandsSep ) .
          " file" . plural_s( $context->fileCountOk ) . "\n";

  if ( $context->fileCountFailed != 0 )
  {
    $msg .= "Failed               : " . AddThousandsSeparators( $context->fileCountFailed, $g_grouping, $g_thousandsSep ) .
            " file" . plural_s( $context->fileCountFailed ) . "\n";
    $exitCode = EXIT_CODE_FAILURE;
  }

  write_stdout( $msg );

  return $exitCode;
}


sub open_checksum_file ( $ )
{
  my $context = shift;

  $context->checksumFileHandle( open_file_for_utf8_reading( $context->checksumFilename ) );

  my $firstTextLine = read_text_line_raw( $context->checksumFileHandle,
                                          $context->checksumFilename );
  if ( ! defined ( $firstTextLine ) )
  {
    die "File " . format_str_for_message( $context->checksumFilename ) . " is empty.\n";
  }

  if ( ! remove_str_prefix( \$firstTextLine, UTF_BOM ) )
  {
    die "File " . format_str_for_message( $context->checksumFilename ) . " does not begin with the UTF-8 BOM.\n"
  }

  if ( ! remove_str_prefix( \$firstTextLine, FILE_FIRST_LINE_PREFIX ) )
  {
    die "File " . format_str_for_message( $context->checksumFilename ) . " does not begin with the file format header.\n"
  }

  if ( $firstTextLine ne FILE_FORMAT_V1 )
  {
    die "File " . format_str_for_message( $context->checksumFilename ) . " has an unsupported format version of " . format_str_for_message( $firstTextLine ) . ".\n"
  }

  $context->checksumFileLineNumber( 1 );
}


# ----------- Main routine -----------

sub main ()
{
  # I think I have all Unicode issues in filenames sorted, so we do not need to change
  # the character encoding in stdout/stderr anymore. Anything this script writes
  # to stdout/stderr has to be clean ASCII (charcode < 127), or the
  # Perl string has to be marked internally as a native/raw byte string,
  # see convert_utf8_to_native().
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

  my $arg_help       = 0;
  my $arg_h          = 0;
  my $arg_help_pod   = 0;
  my $arg_version    = 0;
  my $arg_license    = 0;

  my $arg_create     = 0;
  my $arg_verify     = 0 ;

  my $arg_checksum_filename = DEFAULT_CHECKSUM_FILENAME;

  Getopt::Long::Configure( "no_auto_abbrev",  "prefix_pattern=(--|-)", "no_ignore_case" );

  my %options =
  (
    'help'       => \$arg_help,
    'h'          => \$arg_h,
    'help-pod'   => \$arg_help_pod,
    'version'    => \$arg_version,
    'license'    => \$arg_license,

    'create'     => \$arg_create,
    'verify'     => \$arg_verify,

    'checksum-file=s' => \$arg_checksum_filename,
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


  if ( $arg_checksum_filename eq "" )
  {
    die "The checksum filename is empty.\n";
  }

  Class::Struct::struct( CFileFindCallbackContext =>
                         [ # A bracket here means we will be creating an array-based struct (as opposed to a hash based).

                           operation                    => '$',
                           startDirname                 => '$',

                           checksumFilename             => '$',
                           checksumFileHandle           => '$',
                           checksumFilenameInProgress   => '$',
                           checksumFileHandleInProgress => '$',

                           checksumFileLineNumber       => '$',

                           totalSizeProcessed           => '$',

                           directoryCountOk             => '$',
                           directoryCountFailed         => '$',
                           fileCountOk                  => '$',
                           fileCountFailed              => '$',

                           lastProgressUpdate           => '$',
                           startTime                    => '$',
                         ]
                       );

  my $context =
      CFileFindCallbackContext ->new(

        totalSizeProcessed      => 0,

        directoryCountOk        => 0,
        directoryCountFailed    => 0,
        fileCountOk             => 0,
        fileCountFailed         => 0,
      );

  $context->checksumFilename( $arg_checksum_filename );

  # Unfortunately, Perl does not document any way to get an error code from Time::HiRes::clock_gettime(),
  # in order to know whether CLOCK_MONOTONIC is supported. But most systems do support it,
  # and it is a lot of work to find a good alternative.
  $context->startTime( Time::HiRes::clock_gettime( CLOCK_MONOTONIC ) );
  $context->lastProgressUpdate( $context->startTime() );

  $SIG{INT}  = \&sig_int_handler;

  my $exitCode;

  if ( $arg_create )
  {
    if ( scalar( @ARGV ) > 1 )
    {
      die "Option '--create' takes at most one argument.\n";
    }

    my $dirname = scalar( @ARGV ) == 0 ? "." : $ARGV[0];

    $dirname = str_remove_optional_suffix( $dirname, "/" );

    if ( not -d $dirname )
    {
      die qq<Directory "$dirname" does not exist.\n>;
    }

    $context->operation( OPERATION_CREATE );

    $context->startDirname( $dirname );

    # We could silently overwrite any existing file, but it can take a lot of time to generate
    # such a checksum file, so we do not want the user to inadvertently lose one.

    if ( -e $context->checksumFilename )
    {
      die "Filename " . format_str_for_message( $arg_checksum_filename ) . " already exists.\n";
    }


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

      my $header = UTF_BOM . FILE_FIRST_LINE . FILE_LINE_SEP .
                   FILE_LINE_SEP .
                   "# Warning: The filename sorting order will probably be unexpected for humans," . FILE_LINE_SEP .
                   "# like this sorted sequence: 'Z', 'a', '@{[ LATIN_SMALL_LETTER_N_WITH_TILDE ]}'." . FILE_LINE_SEP .
                   FILE_LINE_SEP;

      write_to_file( $context->checksumFileHandleInProgress,
                     $context->checksumFilenameInProgress,
                     $header );

      $exitCode = scan_disk_files( $context );
    };

    close_file_handle_and_rethrow_eventual_error( $context->checksumFileHandleInProgress, $@ );

    if ( ! File::Copy::move( $context->checksumFilenameInProgress,
                             $context->checksumFilename ) )
    {
      die "Cannot move file " . format_str_for_message( $context->checksumFilenameInProgress ) . " to " . format_str_for_message( $context->checksumFilename ) . ": $!\n";
    }
  }
  elsif ( $arg_verify )
  {
    if ( scalar( @ARGV ) != 0 )
    {
      die "Option '--verify' takes no arguments.\n";
    }

    $context->operation( OPERATION_VERIFY );

    open_checksum_file( $context );

    eval
    {
      $exitCode = scan_listed_files( $context );
    };

    close_file_handle_and_rethrow_eventual_error( $context->checksumFileHandle, $@ );
  }
  else
  {
    die "No operation specified.\n";
  }

  if ( $g_wasInterruptionRequested )
  {
    write_stdout( "Stopped because SIGINT was received.\n" );
    $exitCode = EXIT_CODE_FAILURE;
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
