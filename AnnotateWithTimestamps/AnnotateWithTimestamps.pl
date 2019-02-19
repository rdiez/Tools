#!/usr/bin/perl

# The following POD section contains placeholders, so it has to be preprocessed by this script first.
#
# HelpBeginMarker

=head1 OVERVIEW

SCRIPT_NAME version SCRIPT_VERSION

This tool prints a text line for each byte read, with timestamp, time delta,
byte value and ASCII character name. In order to improve readability,
the time delta is only printed if it has changed with respect
to the previous byte.

The output looks like this:

  2018-09-06 17:12:56     0,000  +  0,000   97  0x61  a
  2018-09-06 17:12:56     0,000         -   98  0x62  b
  2018-09-06 17:12:56     0,092  +  0,092   99  0x63  c
  2018-09-06 17:12:56     0,092         -  100  0x64  d
  2018-09-06 17:12:57     0,295  +  0,203  101  0x65  e
  2018-09-06 17:12:56     0,295         -  102  0x66  f

The data log above means that a first data packet was received with 2 bytes (ASCII codes 'a' and 'b').
The second colum shows the number of seconds elapsed since the arrival of the first packet.
A second data packet arrived 92 ms later with 2 more bytes ('c' and 'd').
Finally, a third data packed arrived 203 ms later with 2 more bytes ('e' and 'f').

I wrote this tool mainly to help troubleshoot data timing issues
over serial ports. But this script can read from stdin or from any file,
so you can use it for example with FIFOs.

=head1 USAGE

S<perl SCRIPT_NAME [options] [--] E<lt>filenameE<gt>>

If the filename is a single hyphen ('-'), then data is read from stdin. This is useful when piping between processes.

If you always want the English thousands separator (',') and decimal separator ('.')
in the date stamp and time delta values, no matter what the current locale is,
set environment variable LANG=C before running this script. The easiest way is like this:

  env LANG=C  perl SCRIPT_NAME ...

When piping stdout from other processes to this script, stdout buffering may cause
the data stream to 'stutter'. See tools I<< unbuffer >> and I<< S<< stdbuf -o0 >> >> for more information.

Example for a serial port under Linux:

  stty  -F "/dev/serial/by-id/my_serial_port"  cs8  -parenb  -cstopb  -clocal  -echo  raw  speed 9600
  perl SCRIPT_NAME "/dev/serial/by-id/my_serial_port"

Example for a serial port under Windows:

  mode COM1 BAUD=9600 PARITY=n DATA=8 STOP=1
  perl SCRIPT_NAME COM1

Here is a one-shot TCP server that redirects all received data to this script:

  socat -u TCP4-LISTEN:1234,bind=localhost STDOUT | perl SCRIPT_NAME -

And this command connects to the TCP server above and sends some data:

  printf "Test data" | socat -u STDIN TCP4:localhost:1234

=head1 OPTIONS

=over

=item *

B<--no-hints>

Do not print any hints, just the annotated data.

=item *

B<--show-microseconds>

Display timing information down to microseconds.

If you need this level of accuracy, make sure that your system can actually deliver it.
Start by finding out the timing resolution:

  perl -MTime::HiRes -e 'print Time::HiRes::clock_getres( CLOCK_REALTIME ) . "\n"'

And then see further below on how to benchmark this script.

=item *

B<-h, --help>

Print this help text.

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

=back

=head1 EXIT CODE

Exit code: 0 on success, some other value on error.

=head1 SIGNALS

SIGINT (Ctrl+C) causes this script to print a message about having received this signal
(assuming that hints have not been disabled) and terminate with an exit code of 0.

=head1 CAVEATS

=over

=item * There are performance limitations.

The Perl interpreter is not very fast, so do not expect a high timing accuracy.

There is a considerable start-up delay due to Perl interpreter initialisation.
If you are starting the script and immediately feeding it with data,
the timing for the first data packets will probably be inaccurate due
to this delay.

This script will probably only keep up with moderate data rates.
See the section below about testing for benchmark information.

=item *

This script is sensitive to changes to the clock.

If the local time changes, the timing reflected in the data log will not be accurate.

An improvement would be to provide a command-line argument to use
the CLOCK_MONOTONIC POSIX high resolution timer, if available on the system,
instead of the realtime clock. The data log would then show relative time offsets,
which are insensitive to clock changes, in place of the time of the day.

However, having the local time in the data log is often very convenient for
cross-reference purposes, so I fear that such an option would hardly be used in practice.

=item * A Perl interpreter with 64-bit integer support is required.

That should actually be the case for all modern Perl distributions, even on 32-bit operating systems.
This script does check, but you can also manually find out like this:

  perl -V | grep USE_64_BIT_INT

Otherwise, you would quickly encounter integer overflows. Using multiprecision arithmetic would be too slow.

=back

=head1 TESTING THIS SCRIPT

=over

=item *

Test with simulated data pauses:

  ./GenerateTestDatagrams.sh | ./SCRIPT_NAME -

=item *

Test with a FIFO:

  ./GenerateTestBytes-0-to-255.sh testFifo & ./SCRIPT_NAME testFifo && wait

=item *

Benchmark the raw CPU performance generating the data log:

  dd bs=$(( 1024 * 1024 )) count=1 if=/dev/urandom | ./SCRIPT_NAME - >/dev/null

Example values:

  Intel Core i3-6100 CPU @ 3.70 GHz
  Perl v5.26.2
  Windows 10, 64-bit Cygwin
  Speed: 800 kB/s

  Intel Core 2 Duo T8100 @ 2.10 GHz
  Perl v5.22.1
  Ubuntu 16.04.5 LTS, x86_64
  Speed: 402 kB/s

  Intel Atom CPU N450 @ 1.66 GHz
  Perl v5.26.1
  Ubuntu 18.04.1 LTS, x86_64
  Speed: 86 kB/s

=back

=head1 ALTERNATIVES

There are many tools to annotate and timestamp data streams. You can achieve a similar data log with I<< hexdump >> and I<< ts >> as follows:

  ./GenerateTestDatagrams.sh | stdbuf -o0 hexdump -v  -e '/1  "% 6_ad# "'  -e '/1 " %3u  "'  -e '/1  "0x%02X  "'  -e '/1 "%_u\n"' | ts '%F %H:%M:%.S'

In Ubuntu/Debian, package I<< moreutils >> provides tool I<< ts >>. The trouble is, I<< ts >> is a shell script and runs very slowly.
Furthermore, the command line above does not print relative times, which makes it harder to see where the data transmission pauses occur.

=head1 FEEDBACK

Please send feedback to rdiezmail-tools at yahoo.de

=head1 LICENSE

Copyright (C) 2018 R. Diez

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
use Config;
use Getopt::Long;
use Pod::Usage;
use Time::HiRes qw( CLOCK_MONOTONIC );
use POSIX;

use constant SCRIPT_VERSION => "1.05";  # If you update it, update also the perldoc text above.

use constant EXIT_CODE_SUCCESS => 0;
use constant EXIT_CODE_FAILURE => 1;  # Beware that other errors, like those from die(), can yield other exit codes.

use constant TRUE  => 1;
use constant FALSE => 0;


# ----------- Generic constants and routines -----------

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

  open( my $file, "<$file_path" )
    or die "Cannot open file \"$file_path\": $!\n";

  binmode( $file );  # Avoids CRLF conversion.

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

  my $regex = "# HelpBeginMarker(.*?)# HelpEndMarker";

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

  seek $memFileWithPod,0,0
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


sub AddThousandsSeparators ($$$)
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

# This is for manually testing of AddThousandsSeparators().
if ( FALSE )
{
  write_stdout( AddThousandsSeparators( "", 3, "," ) . "\n" );
  write_stdout( AddThousandsSeparators( 1, 3, "," ) . "\n" );
  write_stdout( AddThousandsSeparators( 12, 3, "," ) . "\n" );
  write_stdout( AddThousandsSeparators( 123, 3, "," ) . "\n" );
  write_stdout( AddThousandsSeparators( 1234, 3, "," ) . "\n" );
  write_stdout( AddThousandsSeparators( 12345, 3, "," ) . "\n" );
  write_stdout( AddThousandsSeparators( 123456, 3, "," ) . "\n" );
  write_stdout( AddThousandsSeparators( 1234567, 3, "," ) . "\n" );
  write_stdout( AddThousandsSeparators( 12345678, 3, "," ) . "\n" );
  write_stdout( AddThousandsSeparators( 123456789, 3, "," ) . "\n" );
  write_stdout( AddThousandsSeparators( 1234567890, 3, "," ) . "\n" );

  exit 0;
}


# Arguments: pastEpochSec, pastEpocUs, futureEpochSec, futureEpochUs

sub CalculateTimeDeltaUs ($$$$)
{
  use integer;
  return ( $_[2] - $_[0] ) * 1000 * 1000 + $_[3] - $_[1];
}


# ----------- Global variables -----------

my %asciiCharNames =
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
   # 9  => "HT",  # The 'tab' character. This one is handled separately.
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
  31  => "US",

 127  => "DEL",
);


my $g_thousandsSep;
my $g_decimalSep;
my $g_grouping;

my $g_showMicroseconds = FALSE;
my $g_noHints = FALSE;


# ----------- Script-specific constants and routines -----------

sub sig_int_handler
{
  if ( not $g_noHints )
  {
    write_stdout( "\n$Script: Terminating upon reception of SIGINT.\n" );
  }

  exit( EXIT_CODE_SUCCESS );
}


sub UsValueToStr ($$)
{
  my $us           = $_[0];
  my $secondsWidth = $_[1];

  use integer;

  if ( $g_showMicroseconds )
  {
    return sprintf( "%${secondsWidth}s%s%03d%s%03d",
                    AddThousandsSeparators( $us / 1000 / 1000, $g_grouping, $g_thousandsSep ),
                    $g_decimalSep,
                    ( $us / 1000 ) % 1000,
                    $g_thousandsSep,
                    $us % 1000 );
  }
  else
  {
    return sprintf( "%${secondsWidth}s%s%03d",
                    AddThousandsSeparators( $us / 1000 / 1000, $g_grouping, $g_thousandsSep ),
                    $g_decimalSep,
                    ( $us / 1000 ) % 1000 );
  }
}


sub GenerateTimestampStr ($$$$$)
{
  my $secondsSinceEpoch = $_[0];
  my $microseconds      = $_[1];
  my $initialSecondsSinceEpoch = $_[2];
  my $initialMicroseconds = $_[3];
  my $relTimeSecondsWidth = $_[4];

  my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime( $secondsSinceEpoch );

  # Beware that the shortcut "%F" for "%Y-%m-%d" does not work under Win32.
  my $timingLinePrefix = POSIX::strftime( "%Y-%m-%d %H:%M:%S", $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst );

  my $relTime = CalculateTimeDeltaUs( $initialSecondsSinceEpoch, $initialMicroseconds, $secondsSinceEpoch, $microseconds );

  return $timingLinePrefix . " " . UsValueToStr( $relTime, $relTimeSecondsWidth );
}


sub OutputByte ($$)
{
  my $byte             = $_[0];
  my $timingLinePrefix = $_[1];

  my $charVal = ord( $byte );

  my $charDescription;

  if ( $charVal == 32 )
  {
    # Display the character description slightly to the right, so that it
    # does not impact the vertical readability of the ASCII column.
    $charDescription = "  (space)";
  }
  elsif ( $charVal == 9 )
  {
    # Display the character description slightly to the right, so that it
    # does not impact the vertical readability of the ASCII column.
    $charDescription = "  (tab)";
  }
  elsif ( $charVal < 32 || $charVal == 127 )
  {
    $charDescription = $asciiCharNames{ $charVal };
  }
  elsif ( $charVal > 127 )
  {
    $charDescription = "(not ASCII)";
  }
  else
  {
    $charDescription = $byte;
  }

  write_stdout( sprintf( "%s  %3d  0x%02X  %s\n", $timingLinePrefix, $charVal, $charVal, $charDescription ) );
}


# ----------- Main routine -----------

sub main ()
{
  if ( not $Config{ use64bitint } )
  {
    die "This script requires a Perl interpreter with 64-bit integer support (see build flag USE_64_BIT_INT).\n"
  }

  my $arg_help    = 0;
  my $arg_h       = 0;
  my $arg_version = 0;
  my $arg_license = 0;

  Getopt::Long::Configure( "no_auto_abbrev",  "prefix_pattern=(--|-)" );

  my $result = GetOptions(
                 'help'      =>  \$arg_help,
                 'h'         =>  \$arg_h,
                 'version'   =>  \$arg_version,
                 'license'   =>  \$arg_license,

                 'show-microseconds' => \$g_showMicroseconds,
                 'no-hints'          => \$g_noHints,
               );

  if ( not $result )
  {
    # GetOptions has already printed an error message.
    return EXIT_CODE_FAILURE;
  }

  if ( $arg_help || $arg_h )
  {
    print_help_text();
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


  if ( scalar( @ARGV ) != 1 )
  {
    write_stderr( "\nInvalid number of command-line arguments. Run this tool with the --help option for usage information.\n" );

    return EXIT_CODE_FAILURE;
  }

  my $filename = $ARGV[0];


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


  $SIG{INT}  = \&sig_int_handler;


  # With 3 characters we can represent at most   "999" seconds, around  16 minutes.
  # With 5 characters we can represent at most "9,999" seconds, around 2.7 hours.
  # Any bigger values will make the affected column grow, creating one column misalignment at that row.
  my $relTimeSecondsWidth = 5;
  my $deltaSecondsWidth   = 3;

  my $isStdin = ( $filename eq "-" );

  my $file;

  if ( $isStdin )
  {
    $file = *STDIN;
  }
  else
  {
    if ( FALSE )
    {
      write_stdout( "Reading from file \"$filename\"...\n" );
    }

    open( $file, '<:raw', $filename )
      or die "Cannot open file \"$filename\": $!\n";

    binmode( $file )  # Avoids CRLF conversion.
      or die "Cannot access file \"$filename\" in binary mode: $!\n";
  }


  if ( not $g_noHints )
  {
    my $msg = "Output columns are: local time, seconds from first received data packet, seconds from previous received data packet, byte value in decimal, in hex, ASCII character name.";
    write_stdout( "$msg\n" );
  }


  my $initialSecondsSinceEpoch;
  my $initialMicroseconds;

  my $lastSecondsSinceEpoch;
  my $lastMicroseconds;

  my $isFirstTime = TRUE;

  use constant SOME_ARBITRARY_BUFFER_SIZE => 16 * 1024;

  my $readBuffer;

  # Buffering is important for performance. We manually flush just once after every sysread().
  STDOUT->autoflush( 0 );

  for ( ; ; )
  {
    # Alternative function read() waits until the specified number of bytes arrives, which is not what we want.
    my $readByteCount = sysread( $file, $readBuffer, SOME_ARBITRARY_BUFFER_SIZE );

    if ( not defined $readByteCount )
    {
      die "Error reading from file \"$filename\": $!\n";
    }

    if ( $readByteCount == 0 )
    {
      if ( not $g_noHints )
      {
        write_stdout( "Terminating upon reaching end of file.\n" );
      }

      last;
    }

    if ( FALSE )
    {
      write_stdout( "Number of bytes read: $readByteCount\n" );
    }

    my ( $currentSecondsSinceEpoch, $currentMicroseconds ) = Time::HiRes::gettimeofday;

    my $timeDelta;

    if ( $isFirstTime )
    {
      $initialSecondsSinceEpoch = $currentSecondsSinceEpoch;
      $initialMicroseconds      = $currentMicroseconds;

      $timeDelta                = 0;
    }
    else
    {
      $timeDelta = CalculateTimeDeltaUs( $lastSecondsSinceEpoch, $lastMicroseconds, $currentSecondsSinceEpoch, $currentMicroseconds );
    }

    my $timestampStr = GenerateTimestampStr( $currentSecondsSinceEpoch, $currentMicroseconds, $initialSecondsSinceEpoch, $initialMicroseconds, $relTimeSecondsWidth );

    my $deltaStr = " +" . UsValueToStr( $timeDelta, $deltaSecondsWidth );

    my $firstByte = substr( $readBuffer, 0, 1 );

    OutputByte( $firstByte, $timestampStr . " " . $deltaStr  );


    # All other bytes received together with the first one have the same timestamp, but no delta.

    my $timingLinePrefix = $timestampStr . " " . ( ' ' x ( length( $deltaStr ) - 1 ) ) . "-";

    for ( my $i = 1; $i < $readByteCount; ++$i )
    {
      my $otherByte = substr( $readBuffer, $i, 1 );

      OutputByte( $otherByte, $timingLinePrefix );
    }


    if ( not defined STDOUT->flush() )
    {
      die "Error flushing STDOUT.\n";  # The documentation does not say that $! is set.
    }

    $lastSecondsSinceEpoch = $currentSecondsSinceEpoch;
    $lastMicroseconds      = $currentMicroseconds;
    $isFirstTime           = FALSE;
  }

  if ( ! $isStdin )
  {
    $file->close() or
      die "Cannot close file \"$filename\": $!\n";
  }

  return EXIT_CODE_SUCCESS;
}


exit main();
