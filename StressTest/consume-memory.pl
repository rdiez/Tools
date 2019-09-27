#!/usr/bin/perl

# This script helps you simulate a process that consumes the given amount of memory.
# Useful to test cgroups memory limits.
#
# Just supply a single argument with the number of bytes.
# For example, with this Bash expression the script will consume 100 MiB of memory:
#
#   ./consume-memory.pl $(( 100 * 1024 * 1024 ))
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

use strict;
use warnings;

use FindBin qw( $Bin $Script );
use File::Spec;

use constant EXIT_CODE_FAILURE_ERROR => 1;


sub write_stdout ( $ )
{
  my $str = shift;

  ( print STDOUT $str ) or
     die "Error writing to standard output: $!\n";
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


sub main ()
{
  if ( 1 != scalar @ARGV )
  {
    die "Invalid number of arguments.\n";
  }

  my $byteCount = shift @ARGV;

  my $byteCountStr = AddThousandsSeparators( $byteCount, 3, "," );

  write_stdout( "Consuming $byteCountStr bytes...\n" );

  # By creating $hugeString in exactly this way, we allocate just the number of bytes requested.
  # This is of course sensitive to Perl interpreter optimisations. Future versions may handle memory
  # allocation differently and break this simple method.
  my $hugeString = 'X';
  $hugeString x= $byteCount;

  # By writing the data to the null device we will hopefully prevent future versions of the
  # Perl interpreter from optimising the string away.

  open( my $null, ">", File::Spec->devnull )
    or die "Cannot open the null device: $!\n";

  binmode( $null )  # Avoids CRLF conversion.
    or die "Cannot access the null device in binary mode: $!\n";

  ( print $null $hugeString ) or
    die "Error writing to null device: $!\n";

  $null->close()
    or die "Cannot close the null device: $!\n";

  write_stdout( "Finished consuming $byteCountStr bytes.\n" );
}


# ------------ Script entry point ------------

eval
{
  exit main();
};

my $errorMessage = $@;

# We want the error message to be the last thing on the screen,
# so we need to flush the standard output first.
STDOUT->flush();

print STDERR "\nError running \"$Bin/$Script\": $errorMessage";

exit EXIT_CODE_FAILURE_ERROR;
