#!/usr/bin/perl

# The following POD section contains placeholders, so it has to be preprocessed by this script first.
#
# HelpBeginMarker

=head1 OVERVIEW

SCRIPT_NAME version SCRIPT_VERSION

From all the filenames and directory names given as arguments, determine which one
leads to the file with the highest modification time
(the file that has been modified most recently).

Optionally compare the highest time found with the last modification time of a given file,
in order to determine whether the file is up to date.

This tool helps write makefile rules that trigger whenever some
files in a complex directory structure have changed.

=head1 RATIONALE

This script is designed as a drop-in replacement for OpenWrt's I<< timestamp.pl >> script.
While investigating the OpenWrt build system, I needed to trace why some parts were being rebuilt,
and the existing script did not help and was hard to understand.
This script works in a similar way, but is actually a complete rewrite.

OpenWrt's I<< timestamp.pl >> has a number of shortcomings as of march 2020:

=over

=item * No documentation.

=item * No way to trace what is going on during the file scan.

=item * Almost no error detection. Most errors are just ignored.

=item * Filenames not properly escaped when passed to I<< find >>.

=item * Inefficient: An extra shell instance is created for each I<< find >> invocation.

=item * Any unknown command-line options are silently ignored.

Therefore mistakes in options can easily go unnoticed.

=item * The argument position does matter.

For example:

 timestamp.pl -f .  # Follow symbolic links.
 timestamp.pl . -f  # Option -f has no effect.

This kind of positional effect is very confusing.
Tool I<< find >> has actually deprecated option I<< -follow >>, which has this kind of positional behaviour,
in favour of option I<< -L >>, which is position independent.

Similarly, the I<< -x >> option only excludes in any search names afterwards.
It is even more confusing for option I<< -F >>. Anything found before it will use the corresponding search name, and anything after it will use the exact filename found.

=item * The handling of symbolic links is confusing.

If a search name is a symbolic link to a file, it is ignored, so the file is not considered.
However, if a search name is a symbolic link to a directory, it is followed.

Option I<< -f >> turns on following symbolic links, but only for directories.
Any symbolic links to files are always ignored.

=back

This script improves on all the issues above. There are some differences in behaviour though:

=over

=item * At least one filename or directory name is required.

The OpenWrt script defaulted to the current directory ('.').

=item * Names to exclude I<< .svn >> and I<< CVS >> are no longer hard-coded.

Use the I<< -x >> option to exclude such names.

=item * All arguments are processed before doing any scanning. Therefore, their position does not matter anymore.

=item * Symbolic links to files in search names are handled differently.

If a search name references a symbolic link to a file, the symbolic link is followed.

If a search name references a symbolic link to a directory, the symbolic link is followed too,
but this is the same behaviour as OpenWrt's I<< timestamp.pl >> script.

=back

=head1 USAGE

 perl SCRIPT_NAME [options] [--] <filename or directory name to search for> ...

Options are read from environment variable OPT_ENV_VAR_NAME first, and then from the command line.

The output is a single line of text with a filename or directory name,
a tab character as a separator, and the corresponding modification time (as seconds since the epoch).
For example:

 some-file.txt    1551470607

If no file at all is found, the reported filename is I<< - >>, and the timestamp is 0:

 -       0

Only file modification dates are looked at. If any directories are specified or are encountered during scanning,
their last modification dates are not taken into consideration.

Beware that symbolic links are not followed by default. See option I<< -f >> below for more information.

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

B<< -p >>

Only print the directory name or filename, and not the modification time.

=item *

B<< -t >>

Only print the modification time (as seconds since the epoch), and not the directory name or filename.

=item *

B<< -n E<lt>filenameE<gt> >>

Instead of printing anything, yield exit code 0 if the given file has the highest modification time.
Otherwise, the exit code is 1.
This helps determine if a file is up to date.

If the I<< -n >> file is not found, then it is considered to be out of date, so the exit code will be 1.
This is still true even if no other files are found at all with the given search names.

If the filename happens to be a directory name, an error will be generated. Processing directories
can easily lead to ambiguities if some files are older and some newer than the files found under
the other search names. If directories were to be accepted, this script should probably
take the lowest modification time under the I<< -n >> directory.

Option I<< -n >> can appear only once.

Using this option like follows is a bad idea:

 timestamp.pl -n file dir || make some-target

Using a boolean shell expression effectively turns off error detection. This is what can happen:

 timestamp.pl --bad-option -n file dir || echo Rebuilding...

 Unknown option: bad-option
 Rebuilding...

You could capture the exit status code, but it is cumbersome and a Perl script cannot
actually guarantee the exact exit code under all circumstances.

It is best to use option I<< --up-to-date >> instead of I<< -n >>.

=item * B<< --up-to-date E<lt>filenameE<gt> >>

This option behaves line I<< -n >>, but instead of using exit codes, it prints
"up-to-date" or "out-of-date" to stdout. This way, error detection is not compromised.

Usage example in a GNU Make command:

 TSRES="$(timestamp.pl --up-to-date "file" "dir")" && \
 if [ up-to-date != "$TSRES" ]; then echo "Rebuild necessary."; else echo "No rebuild necessary."; fi

Usage example in a Bash script:

 #!/bin/bash

 set -o errexit

 TSRES="$(timestamp.pl --up-to-date "file" "dir")"

 if [ up-to-date != "$TSRES" ]; then
   echo "Rebuild necessary."
 else
   echo "No rebuild necessary."
 fi

=item *

B<< -x E<lt>pattern to excludeE<gt> >>

This example excludes all I<< .svn >> subdirectories:

 -x "*/.svn"

See option I<< -path >> in tool I<< find >> for more information. Because I<< -x >> uses I<< -path >>,
it is sometimes hard to exclude filenames that start with a period ('.') if a search term
is also a period to indicate the current directory. This script should probably offer a way
to use I<< find >> option I<< -name >> instead.

Option I<< -x >> can appear multiple times.

=item *

B<< -f >>

Independently of this option, if a search name references a symbolic link, the symbolic link is followed.

This option affects what happens when a search name references a directory (directly or via a symbolic link),
and symbolic links are found underneath.

By default, all symbolic links are ignored. With I<< -f >>, any symbolic links that point to directories
are followed. Symbolic links that point to files are still ignored.

This behaviour matches what OpenWrt's I<< timestamp.pl >> script used to do, but it is weird.
I guess more symbolic link options will be needed in the future.

=item *

B<< -F >>

Report the exact filename found with the highest modification time.

Normally, the search name passed as an argument that led to that exact file is printed instead.

=item *

B<< --trace-search-args >>

Prints file search arguments and related information to stderr.

=item *

B<< --trace-scan >>

Prints all files scanned to stderr. Useful to see if your exclusion arguments are working correctly.

=item *

B<< --trace-up-to-date >>

Prints to stderr a description of what options I<< -n >> or I<< --up-to-date >> determined.
If the file is out of date, it shows which other file has been found to have the highest
modification time.

=back

=head1 EXIT CODE

Exit code: 0 on success, some other value on error.

=head1 CAVEATS

=over

=item * Ignoring symbolic links to files does not seem such a good idea.

It is still not clear what options should be provided to deal with symbolic links.
If you look at the I<< find >> documentation, you will realise how many
possible ways there are to handle them.

=item * This script is still using I<< find >> to scan subdirectories.

It would be better to use Perl's File::Find core module instead.

When using options I<< -n >> or I<< --up-to-date >>, this script could stop
as soon as a higher modification time is found. Or at least use I<< find >> option
I<< -cnewer >> to skip unnecessary files.

=item * The current exclusion method is inefficient.

We should be using I<< find >> option I<< -prune >> in order to avoid recursing into subdirectories
that are to be completely skipped anyway.

=item * This script should switch to subsecond resolution for the file modification time if the system
supports it (which is almost always nowadays).

=back

=head1 FEEDBACK

Please send feedback to rdiezmail-tools at yahoo.de

=head1 LICENSE

Copyright (C) 2019-2020 R. Diez

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

use FindBin qw( $Bin $Script );
use Getopt::Long qw(GetOptionsFromString);
use Pod::Usage;
use POSIX;
use Fcntl qw();
use Cwd qw();

use constant SCRIPT_VERSION => "1.06";

use constant OPT_ENV_VAR_NAME => "TIMESTAMP_PL_OPTIONS";


# ----------- Generic constants and routines -----------

use constant EXIT_CODE_SUCCESS        => 0;
use constant EXIT_CODE_NOT_UP_TO_DATE => 1;
# Beware that other errors, like those from die(), can yield other exit codes.
# It is very hard to guarantee that all possible failures will always yield
# an exit code of 2.
use constant EXIT_CODE_FAILURE        => 2;


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


sub flush_stderr ()
{
  if ( ! defined( STDERR->flush() ) )
  {
    # The documentation does not say whether $! is set. I am hoping that it does,
    # because otherwise there is no telling what went wrong.
    die "Error flushing standard error: $!\n";
  }
}


sub pad_right_to_same_length ( $$ )
{
  if ( length( ${$_[0]} ) < length( ${$_[1]} ) )
  {
    ${$_[0]} .= ' ' x ( length( ${$_[1]} ) - length( ${$_[0]} ) );
  }
  else  # Alternatively: elsif ( length( ${$_[0]} ) > length( ${$_[1]} ) )
  {
    ${$_[1]} .= ' ' x ( length( ${$_[0]} ) - length( ${$_[1]} ) );
  }
}


sub pad_left_to_same_length ( $$ )
{
  if ( length( ${$_[0]} ) < length( ${$_[1]} ) )
  {
    ${$_[0]} = ' ' x ( length( ${$_[1]} ) - length( ${$_[0]} ) ) . ${$_[0]};
  }
  else  # Alternatively: elsif ( length( ${$_[0]} ) > length( ${$_[1]} ) )
  {
    ${$_[1]} = ' ' x ( length( ${$_[0]} ) - length( ${$_[1]} ) ) . ${$_[1]};
  }
}


#------------------------------------------------------------------------
#
# Returns a true value if the string starts with the given 'beginning' argument.
#

sub str_starts_with ( $ $ )
{
  my $str       = shift;
  my $beginning = shift;

  if ( length($str) < length($beginning) )
  {
    return 0;
  }

  return substr($str, 0, length($beginning)) eq $beginning;
}


sub reason_died_from_wait_code ( $ )
{
  my $wait_code = shift;

  my $exit_code   = $wait_code >> 8;
  my $signal_num  = $wait_code & 127;
  my $dumped_core = $wait_code & 128;

  if ( $signal_num != 0 )
  {
    return "Indication of signal $signal_num.";
  }

  if ( $dumped_core != 0 )
  {
    return "Indication of core dump.";
  }

  return "Exit code $exit_code.";
}


#------------------------------------------------------------------------
#
# Reads a whole binary file, returns it as a scalar.
#
# Security warning: The error messages contain the file path.
#
# Alternative: use Perl module File::Slurp
#

sub read_whole_binary_file ( $ )
{
  my $file_path = shift;

  open( my $file, "<", $file_path )
    or die "Cannot open file \"$file_path\": $!\n";

  binmode( $file )  # Avoids CRLF conversion.
    or die "Cannot access file in binary mode: $!\n";

  my $file_content;
  my $file_size = -s $file;

  my $read_res = read( $file, $file_content, $file_size );

  if ( not defined($read_res) )
  {
    die qq<Error reading from file "$file_path": $!>;
  }

  if ( $read_res != $file_size )
  {
    die qq<Error reading from file "$file_path".>;
  }

  close( $file ) or die "Cannot close file descriptor: $!\n";

  return $file_content;
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

  $podAsStr =~ s/SCRIPT_VERSION/@{[ SCRIPT_VERSION ]}/gs;
  $podAsStr =~ s/SCRIPT_NAME/$Script/gs;
  $podAsStr =~ s/OPT_ENV_VAR_NAME/@{[ OPT_ENV_VAR_NAME ]}/gs;

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

  pod2usage( -exitval    => "NOEXIT",
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

sub find_highest_modification_time ( $$$$$$ )
{
  my $filename = shift;
  my $arg_trace_search_args = shift;
  my $arg_trace_scan        = shift;
  my $arg_f                 = shift;
  my $arg_x_ref             = shift;
  my $maxFileModificationTime = shift;


  my $highestLastModificationTime             = 0;
  my $filenameWithHighestLastModificationTime = "";


  # Possible optimisation:
  #  Before running 'find', check if the filename references a file,
  #  and then we do not need to run 'find'.
  #  Only a single 'stat' or 'lstat' would suffice in order to determine
  #  whether the file exists, and what kind of file it is.


  # If the file does not exist, let us not waste time running 'find'.

  if ( not -e $filename )
  {
    return ( $highestLastModificationTime, $filenameWithHighestLastModificationTime );
  }

  if ( $arg_trace_scan )
  {
    write_stderr( "- Scanning $filename\n" );
  }

  my @cmdArgs;

  push @cmdArgs, "find";

  if ( $arg_f )
  {
    push @cmdArgs, "-L";
  }
  else
  {
    push @cmdArgs, "-H";
  }

  push @cmdArgs, $filename;

  push @cmdArgs, "-type", "f";

  foreach my $excludeArg ( @$arg_x_ref )
  {
    push @cmdArgs, "-and", "-not", "-path", $excludeArg;
  }

  push @cmdArgs, "-print0";

  if ( 0 )
  {
    write_stderr( "Find args: " . join( ", ", @cmdArgs ) .  "\n" );
  }

  local $/ = "\000";  # We are using -print0 with 'find'.

  # The original script silenced the stderr from 'find' with "2>/dev/null".
  # I think that this is undesirable, because it prevents us from seeing
  # any errors during the scan.

  open ( my $fh, "-|", @cmdArgs )
    or die "Cannot run the 'find' command: $!\n";

  binmode( $fh )  # Avoids CRLF conversion.
    or die "Cannot access the 'find' command pipe in binary mode: $!\n";

  for ( ; ; )
  {
    if ( eof( $fh ) )
    {
      last;
    }

    my $fn = readline( $fh );

    if ( ! defined( $fn ) )
    {
      die "Error reading the output from 'find': $!";
    }

    chomp $fn;


    # Note that stat and lstat behave differently in the face of a symbolic link.
    # If we decide not to skip symbolic links to files, we need to stat() the file
    # in order to get the pointed-to file information, because lstat() only returns
    # information about the symbolic link itself.

    my @fileStats = lstat( $fn );

    if ( scalar( @fileStats ) == 0 )
    {
      die "Cannot access file \"$fn\": $!\n";
    }

    my $mode = $fileStats[ 2 ];

    my $isLink = Fcntl::S_ISLNK( $mode );

    if ( $isLink )
    {
      if ( 0 )
      {
        write_stderr( "Skipping symbolic link: $fn\n" );
      }

      next;
    }

    if ( $arg_trace_scan )
    {
      write_stderr( "  - $fn\n" );
    }

    my $lastModificationTime = $fileStats[ 9 ];

    if ( $lastModificationTime > $maxFileModificationTime )
    {
      # This is a sympton that something is wrong with the filesystem dates or
      # with the current clock. In this situation, the timestamps may not be reliable.
      die "File \"$fn\" has a modification time in the future.\n";
    }

    if ( $lastModificationTime > $highestLastModificationTime )
    {
      $highestLastModificationTime             = $lastModificationTime;
      $filenameWithHighestLastModificationTime = $fn;
    }
  }

  if ( ! close( $fh ) )
  {
    if ( $! == 0 )
    {
      die "Error running the 'find' command: " . reason_died_from_wait_code( $? ) . "\n";
    }
    else
    {
      die "Cannot close pipe file descriptor: $!\n";
    }
  }

  return ( $highestLastModificationTime, $filenameWithHighestLastModificationTime );
}


# ----------- Main routine -----------

sub main ()
{
  my $arg_help       = 0;
  my $arg_h          = 0;
  my $arg_help_pod   = 0;
  my $arg_version    = 0;
  my $arg_license    = 0;
  my $arg_p          = 0;
  my $arg_t          = 0;
  my $arg_f           = 0;
  my $arg_reportExactFilename = 0;
  my $arg_trace_up_to_date    = 0;
  my $arg_trace_search_args   = 0;
  my $arg_trace_scan          = 0;
  my @arg_n;
  my @arg_up_to_date;
  my @arg_x;

  Getopt::Long::Configure( "no_auto_abbrev",  "prefix_pattern=(--|-)", "no_ignore_case" );

  my %options =
  (
    'help'       => \$arg_help,
    'h'          => \$arg_h,
    'help-pod'   => \$arg_help_pod,
    'version'    => \$arg_version,
    'license'    => \$arg_license,
    'p'          => \$arg_p,
    't'          => \$arg_t,
    'f'          => \$arg_f,
    'F'          => \$arg_reportExactFilename,
    'trace-scan' => \$arg_trace_scan,
    'trace-search-args' => \$arg_trace_search_args,
    'trace-up-to-date'  => \$arg_trace_up_to_date,
    'n=s'          => \@arg_n,
    'up-to-date=s' => \@arg_up_to_date,
    'x=s'          => \@arg_x,
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


  if ( $arg_p && $arg_t )
  {
    die "Options -p and -t are incompatible with each other.\n";
  }


  foreach my $excludeArg ( @arg_x )
  {
    if ( $excludeArg eq "" )
    {
      die "Option -x has an empty name to exclude.\n";
    }
  }

  if ( scalar( @arg_n ) > 1 )
  {
    die "Option -n is duplicated.\n";
  }

  if ( scalar( @arg_up_to_date ) > 1 )
  {
    die "Option --up-to-date is duplicated.\n";
  }

  if ( scalar( @arg_n ) == 1 && scalar( @arg_up_to_date ) == 1 )
  {
    die "Options -n and --up-to-date are incompatible.\n";
  }

  if ( scalar( @arg_n ) == 1 || scalar( @arg_up_to_date ) == 1 )
  {
    if ( $arg_p || $arg_t )
    {
      die "Options -n and --up-to-date are incompatible with options -p and -t .\n";
    }
  }
  else
  {
    # If only had the command line, then we could check the error below.
    # However, we can now also pass options globally in an environment variable.
    # If we continue to do the check below, we can never reliably set --trace-up-to-date in the environment variable.
    if ( 0 )
    {
      if ( $arg_trace_up_to_date )
      {
        die "Option --trace-up-to-date needs option -n or --up-to-date.\n";
      }
    }
  }


  if ( scalar( @ARGV ) == 0 )
  {
    die "Invalid number of command-line arguments. Run this tool with the --help option for usage information.\n";
  }


  if ( $arg_trace_search_args )
  {
    write_stderr( "$Script: File search arguments:\n" );
    write_stderr( "- Cur: " . Cwd::cwd() . "\n" );

    if ( scalar( @arg_n ) == 1 )
    {
      write_stderr( "-  -n: $arg_n[0]\n" );
    }

    if ( scalar( @arg_up_to_date ) == 1 )
    {
      write_stderr( "- Upd: $arg_up_to_date[0]\n" );
    }

    foreach my $filename ( @ARGV )
    {
      write_stderr( "- Arg: $filename\n" );
    }

    foreach my $pattern ( @arg_x )
    {
      write_stderr( "-  -x: $pattern\n" );
    }
  }


  if ( $arg_trace_scan )
  {
    write_stderr( "$Script: Tracing scan:\n" );
  }

  my $maxFileModificationTime = time;


  # If there is an -n option, its filename must be processed first.

  my $upToDateFilename;
  my $upToDateLastModificationTime;  # If undef, the $upToDateFilename file does not exist.

  if ( scalar( @arg_n ) == 1 )
  {
    $upToDateFilename = $arg_n[0];
  }

  if ( scalar( @arg_up_to_date ) == 1 )
  {
    $upToDateFilename = $arg_up_to_date[0];
  }

  my $highestLastModificationTime                = 0;
  my $filenameWithHighestLastModificationTime    = "";
  my $filenameArgWithHighestLastModificationTime = "";

  if ( defined( $upToDateFilename ) )
  {
    if ( $upToDateFilename eq "" )
    {
      die "Option -n or --up-to-date has an empty search name.\n";
    }

    if ( -d $upToDateFilename )
    {
      # We could allow this, but there are reasons against it. Check out
      # the documentation for the -n option for more information.
      die "The name \"$upToDateFilename\" passed in option -n or --up-to-date refers to a directory, but it must be a file.\n";
    }

    my ( $mt, $fn ) = find_highest_modification_time( $upToDateFilename,
                                                      $arg_trace_search_args,
                                                      $arg_trace_scan,
                                                      $arg_f,
                                                      \@arg_x,
                                                      $maxFileModificationTime );
    if ( $fn ne "" )
    {
      $highestLastModificationTime                = $mt;
      $filenameWithHighestLastModificationTime    = $fn;
      $filenameArgWithHighestLastModificationTime = $upToDateFilename;

      $upToDateLastModificationTime               = $mt;
    }
  }


  foreach my $filename( @ARGV )
  {
    if ( $filename eq "" )
    {
      die "A search name is empty.\n";
    }

    if ( str_starts_with( $filename, "-" ) )
    {
      # We could lift this restriction, but then we need be careful
      # about how we pass filenames to 'find', and whether the exclude patterns
      # still work if you modify the filenames for escaping purposes.
      die "Search name \"$filename\" is invalid because it starts with a hyphen ('-').\n";
    }

    # Possible optimisation: Skip searching for files if -n or --up-to-date are in effect
    #                        and the file they reference does not exist.

    my ( $mt, $fn ) = find_highest_modification_time( $filename,
                                                      $arg_trace_search_args,
                                                      $arg_trace_scan,
                                                      $arg_f,
                                                      \@arg_x,
                                                      $maxFileModificationTime );
    if ( $mt > $highestLastModificationTime )
    {
      $highestLastModificationTime                = $mt;
      $filenameWithHighestLastModificationTime    = $fn;
      $filenameArgWithHighestLastModificationTime = $filename;
    }
  }


  my $fnToReport = $arg_reportExactFilename
                     ? $filenameWithHighestLastModificationTime
                     : $filenameArgWithHighestLastModificationTime;

  if ( $fnToReport eq "" )
  {
    $fnToReport = "-";
  }


  my $exitCode = EXIT_CODE_SUCCESS;

  if ( defined( $upToDateFilename ) )
  {
    my $isUpToDate = $filenameArgWithHighestLastModificationTime eq $upToDateFilename;

    if ( $arg_trace_up_to_date )
    {
      if ( $isUpToDate )
      {
        write_stderr( "$Script: File is up to date: $upToDateFilename\n" );
      }
      elsif ( ! defined( $upToDateLastModificationTime ) )
      {
        write_stderr( "$Script: File is considered to be out of date because it does not exist: $upToDateFilename\n" );
      }
      else
      {
        my $msg1 = "File is out of date";
        my $msg2 = "This file is newer";

        pad_right_to_same_length( \$msg1, \$msg2 );

        my $formatStr = '%Y-%m-%d %H:%M:%S';

        my $ts1 = POSIX::strftime( $formatStr, localtime( $upToDateLastModificationTime ) );
        my $ts2 = POSIX::strftime( $formatStr, localtime( $highestLastModificationTime  ) );

        $msg1 .= " from $ts1";
        $msg2 .= " from $ts2";

        write_stderr( "$Script: $msg1: $upToDateFilename\n" );
        write_stderr( "$Script: $msg2: $filenameWithHighestLastModificationTime\n" );
      }
    }

    if ( scalar( @arg_n ) == 1 )
    {
      $exitCode = $isUpToDate ? EXIT_CODE_SUCCESS : EXIT_CODE_NOT_UP_TO_DATE;
    }
    else
    {
      flush_stderr();
      write_stdout( ( $isUpToDate ? "up-to-date" : "out-of-date" ) . "\n" );
    }
  }
  elsif ( $arg_p )
  {
    flush_stderr();
    write_stdout( $fnToReport . "\n" );
  }
  elsif ( $arg_t )
  {
    flush_stderr();
    write_stdout( $highestLastModificationTime . "\n" );
  }
  else
  {
    flush_stderr();
    write_stdout( $fnToReport . "\t" . $highestLastModificationTime . "\n" );
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
