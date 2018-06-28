#!/usr/bin/perl

# This script is no wrapper (it does not run the command) like print-arguments-wrapper.sh .
# It just prints the arguments and all environment variables it received, and quits.
#
# This tool can also run under Windows if you install a Perl version for Windows.
#
# Copyright (c) 2011-2014 R. Diez - Licensed under the GNU AGPLv3

use strict;
use warnings;

use Data::Dumper;

my $scriptName = $0;

$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 1;

print "Script $scriptName was invoked with the following environment variables, as seen by Perl's \%ENV variable:\n\n", Dumper(\%ENV);

print "\nScript $scriptName was invoked with the following command-line arguments, as seen by Perl's \@ARGV variable:\n\n";

if ( @ARGV == 0 )
{
  print "[No command-line arguments were passed]\n\n";
}
else
{
  print Dumper(\@ARGV), "\n";
}

print "Note that the above lists are in Perl syntax, so for example '\\\\' means a single '\\'.\n";

print "End of $scriptName.\n";
