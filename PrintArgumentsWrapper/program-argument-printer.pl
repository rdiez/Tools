#!/usr/bin/perl
use strict;
use warnings; 

use Data::Dumper;

my $scriptName = $0;

$Data::Dumper::Terse = 1;
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
