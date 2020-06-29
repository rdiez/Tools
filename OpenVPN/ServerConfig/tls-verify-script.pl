#!/usr/bin/perl

# You need to install Ubuntu/Debian package 'libx500-dn-perl' before running this script.
#
# For more information about this kind of script, see the example script verify-cn in the OpenVPN distribution.
#
# I have completely rewritten the example script because it did not implement error handling properly
# and had little documentation. It also did not parse the certificate subject string correctly.
#
# The file format with the allowed clients has following features:
# - Empty lines are discarded.
# - Comment lines are discarded. Such lines begin with optional whitespace (spaces or tabs) and a hash ('#') character.
# - Normal lines containing the 'common name' of a client certificate can have optional whitespace to the left or right,
#   but no comment is allowed at the end (unlike usual in programming languages).
# Example file contents:
#
#   # This is a comment.
#   client 1
#
#   # Yet another comment.
#   client 2
#   client 3
#
#   client wrong  # This line with a comment at the end is invalid and will not work.
#
#
# After removing a certificate from the whitelist file, you should restart the OpenVPN server,
# in case the removed certificate is currently in use.
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

use strict;
use warnings;

use FindBin qw( $Bin $Script );

use X500::DN ();

use constant EXIT_CODE_SUCCESS       => 0;
use constant EXIT_CLIENT_DISALLOWED  => 1;
use constant EXIT_CODE_FAILURE_ERROR => 2;


sub write_stdout ( $ )
{
  my $str = shift;

  ( print STDOUT $str ) or
     die "Error writing to standard output: $!\n";
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


sub check_common_name( $$ )
{
  my $filename   = shift;
  my $commonName = shift;

  open( my $file, "<", $filename )
    or die "Cannot open file \"$filename\": $!\n";

  binmode( $file )  # Avoids CRLF conversion.
    or die "Cannot access file in binary mode: $!\n";

  my $whitespaceExpression = "[\x20\x09]";  # Whitespace is only a space or a tab.

  my $isClientAllowed = 0;

  for ( ; ; )
  {
    if ( eof( $file ) )
    {
      last;
    }

    my $line = readline( $file );

    if ( ! defined( $line ) )
    {
      die "Error reading a file line: $!";
    }

    chomp $line;

    if ( 0 )
    {
      write_stdout( "Line read: " . $line . "\n" );
    }


    # POSSIBLE OPTIMISATION: Removing blanks could perhaps be done faster with transliterations (tr///).
    # Strip leading blanks.
    my $withoutLeadingWhitespace = $line;
    $withoutLeadingWhitespace =~ s/\A$whitespaceExpression*//;

    if ( length( $withoutLeadingWhitespace ) == 0 )
    {
      if ( 0 )
      {
        write_stdout( "Discarding empty or whitespace-only line.\n" );
      }

      next;
    }

    if ( str_starts_with( $withoutLeadingWhitespace, "#" ) )
    {
      if ( 0 )
      {
        write_stdout( "Discarding comment line: $line\n" );
      }

      next;
    }

    my $withoutTrailingWhitespace = $withoutLeadingWhitespace;
    $withoutTrailingWhitespace =~ s/$whitespaceExpression*\z//;

    my $cnFound = $withoutTrailingWhitespace;

    if ( 0 )
    {
      write_stdout( "Client certificate common name found: $cnFound\n" );
    }

    if ( $cnFound eq $commonName )
    {
      $isClientAllowed = 1;
      last;
    }
  }

  close( $file ) or die "Cannot close file descriptor: $!\n";

  if ( $isClientAllowed )
  {
    if ( 0 )
    {
      write_stdout( "$Script: Client with common name \"$commonName\" has been found in the allowed clients list.\n" );
    }

    return EXIT_CODE_SUCCESS;
  }

  # I think that rejects should land in the system log file.
  if ( 1 )
  {
    write_stdout( "$Script: Client with common name \"$commonName\" was not found in the allowed clients list.\n" );
  }

  exit EXIT_CLIENT_DISALLOWED;
}


sub main ()
{
  if ( 3 != scalar @ARGV )
  {
    die "Invalid number of arguments.\n";
  }

  my $filename              = shift @ARGV;
  my $certificateChainDepth = shift @ARGV;
  my $x509SubjectString     = shift @ARGV;

  # On a standard setup, this script gets run twice.
  # The 1st time you get a depth of 1 and this subject string:
  #   C=US, ST=CA, L=SanFrancisco, O=Fort-Funston, OU=MyOrganizationalUnit, CN=Fort-Funston CA, name=EasyRSA, emailAddress=me@myhost.mydomain
  # The 2nd time you get a depth of 0 and this subject string:
  #   C=US, ST=CA, L=SanFrancisco, O=Fort-Funston, OU=MyOrganizationalUnit, CN=client1        , name=EasyRSA, emailAddress=me@myhost.mydomain
  # The only difference is the CN (Common Name).

  if ( 0 )
  {
    write_stdout( "$Script: Filename: $filename, depth: $certificateChainDepth, subject string: $x509SubjectString\n" );
  }

  if ( $certificateChainDepth != 0 )
  {
    # Tell OpenVPN to continue processing the certificate chain.
    return EXIT_CODE_SUCCESS;
  }

  # If depth is zero, we know that this is the final certificate in the chain (i.e. the client certificate).
  # That is the one we want to check.

  # OpenVPN's documentation for configuration option 'tls-verify' does not mention it, but it looks like
  # the "X509 subject string" is string with Distinguished Name (DN) fields. Such a format is defined in RFC 2253.
  # Tarsing it properly is a pain.

  my $dn = X500::DN->ParseRFC2253( $x509SubjectString );

  if ( ! $dn )
  {
    die "Cannot parse the following subject string: $x509SubjectString\n";
  }

  if ( 0 )
  {
    write_stdout( "$Script: " . $dn->getRFC2253String() . "\n" );
  }

  my @allRdns = $dn->getRDNs();

  use constant CN_ATTR_NAME => "CN";

  foreach my $rdn ( @allRdns )
  {
    my $commonName = $rdn->getAttributeValue( CN_ATTR_NAME );

    if ( $commonName )
    {
      if ( 0 )
      {
        write_stdout( "$Script: Common name found: $commonName\n" );
      }

      return check_common_name( $filename, $commonName );
    }
  }

  die "Cannot find attribute @{[ CN_ATTR_NAME ]} in subject string: $x509SubjectString\n";
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
