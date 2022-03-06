#!/usr/bin/perl

# This script is no wrapper (it does not run the command) like print-arguments-wrapper.sh .
# It just prints the arguments and all environment variables it received, together with
# some other user-account information, and quits.
#
# This tool can also run under Windows if you install a Perl version for Windows.
#
# Script version 1.02.
#
# Copyright (c) 2011-2022 R. Diez - Licensed under the GNU AGPLv3

use strict;
use warnings;

use Data::Dumper;

my $scriptName = $0;

$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 1;


sub write_stdout ( $ )
{
  my $str = shift;

  ( print STDOUT $str ) or
     die "Error writing to standard output: $!\n";
}


write_stdout( "Report from $scriptName:\n" );

write_stdout( "\n" );

my $realUserName      = getpwuid( $< ) || "<unknown>";
my $effectiveUserName = getpwuid( $> ) || "<unknown>";

write_stdout( "Real user ID:        $< ($realUserName)"      . "\n" );
write_stdout( "Effective user ID:   $> ($effectiveUserName)" . "\n" );

# write_stdout( "Real group IDs:      $(\n" );
# write_stdout( "Effective group IDs: $)\n" );

write_stdout( "\n" );

write_stdout( "Real group IDs:\n" );

my @allRealGroupIds = split( /\s+/, $( );

foreach my $realGroupId ( @allRealGroupIds )
{
  my $realGroupName = getgrgid( $realGroupId ) || "<unknown>";

  write_stdout( "- $realGroupId ($realGroupName)\n" );
}

write_stdout( "\n" );

write_stdout( "Effective group IDs:\n" );

my @allEffectiveGroupIds = split( /\s+/, $) );

foreach my $effectiveGroupId ( @allEffectiveGroupIds )
{
  my $effectiveGroupName = getgrgid( $effectiveGroupId ) || "<unknown>";

  write_stdout( "- $effectiveGroupId ($effectiveGroupName)\n" );
}

write_stdout( "\n" );


write_stdout( "Environment variables, as seen by Perl's \%ENV variable:\n" . Dumper(\%ENV) . "\n" );

write_stdout( "Command-line arguments, as seen by Perl's \@ARGV variable:\n" );

if ( @ARGV == 0 )
{
  write_stdout( "[No command-line arguments were passed]\n\n" );
}
else
{
  write_stdout( Dumper(\@ARGV) . "\n" );
}

write_stdout( "Note that the above lists are in Perl syntax, so for example '\\\\' means a single '\\'.\n" );

write_stdout( "End of $scriptName.\n" );
