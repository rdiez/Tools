
# Copyright (C) 2011-2019 R. Diez - Licensed under the GNU AGPLv3

package ConfigFile;

use strict;
use warnings;

use StringUtils;
use MiscUtils;
use FileUtils;

use constant CONFIG_LINE_IS_COMMENT        => 1;
use constant CONFIG_LINE_IS_NOT_RECOGNISED => 2;
use constant CONFIG_LINE_IS_NAME_VALUE     => 3;


sub read_config_file ( $ $ )
{
  my $filename      = shift;
  my $configEntries = shift;

  my @allLines = FileUtils::read_text_file( $filename );

  for ( my $i = 1; $i <= scalar( @allLines ); ++$i )
  {
    eval
    {
      my $line = $allLines[ $i - 1 ];

      my ( $parse_result, $name, $value );

      parse_config_file_line( $line, \$parse_result, \$name, \$value );

      if ( $parse_result != ConfigFile::CONFIG_LINE_IS_COMMENT )
      {
        die "Invalid line syntax.\n" if ( $parse_result == CONFIG_LINE_IS_NOT_RECOGNISED );
        die "Internal error.\n"      if ( $parse_result != CONFIG_LINE_IS_NAME_VALUE     );

        if ( FALSE )
        {
          print qq<Name "$name", value "$value".\n>;
        }

        if ( exists $configEntries->{ $name } )
        {
          die qq<Duplicate setting "$name".\n>;
        }

        $configEntries->{ $name } = $value;
      }
    };

    my $errorMsg = $@;

    if ( $errorMsg )
    {
      die "Error in file \"$filename\", line $i: $errorMsg\n";
    }
  }
}


#------------------------------------------------------------------------
#
# Parses a config file line.
#
# Arguments: $line, \$parse_result, \$name, \$value
#
# $parse_result is returned with one of the CONFIG_LINE_IS_XXX contants.
#
# Both the setting name and value returned are stripped of leading and trailing blanks.
# If CONFIG_LINE_IS_NAME_VALUE is returned, then the $value returned will NEVER be undef,
# although it may be an empty string.
#

sub parse_config_file_line ( $ $ $ $ )
{
  my $line_arg         = shift;
  my $parse_result_ref = shift;
  my $name_ref         = shift;
  my $value_ref        = shift;

  # Check for comment lines.

  my $line = StringUtils::trim_blanks( $line_arg );

  if ( length( $line ) == 0 or
       StringUtils::str_starts_with( $line, "#" ) or
       StringUtils::str_starts_with( $line, "[" ) )
  {
    $$parse_result_ref = CONFIG_LINE_IS_COMMENT;

    # The following is not strictly necessary, but helps catch bugs.
    $$name_ref = undef;
    $$value_ref = undef;

    return;
  }


  # Split "name=value" string.

  my @parts = $line =~ m/ ^                  # Beginning of the string.
                          (.+?)              # The setting name, non greedy.
                          \s*                # Any blanks before the '=' character.
                          =                  # The equal sign
                          \s*                # Any blanks after the '=' character.
                          (.*)               # The setting value.
                          $                  # End of the string.
                        /sxo ;

  if ( FALSE )
  {
    print "Parts: " . scalar(@parts) . "\n";
  }

  if ( scalar(@parts) < 1 )
  {
    $$parse_result_ref = CONFIG_LINE_IS_NOT_RECOGNISED;

    # The following is not strictly necessary, but helps catch bugs.
    $$name_ref  = undef;
    $$value_ref = undef;

    return;
  }

  my ($name, $value) = @parts;

  if ( not defined($value) )
  {
    $value = "";
  }

  $$parse_result_ref = CONFIG_LINE_IS_NAME_VALUE;
  $$name_ref  = $name;
  $$value_ref = $value;
}


sub check_config_file_contents ( $ $ $ $ )
{
  my $configEntries           = shift;  # Reference to a hash.
  my $mandatoryEntries        = shift;  # Reference to an array.
  my $optionalEntries         = shift;  # Reference to an array.
  my $filenameForErrorMessage = shift;

  my %man;

  foreach my $setting ( @$mandatoryEntries )
  {
    if ( exists $man{ $setting } )
    {
      die "Duplicate setting name \"$setting\".\n";
    }

    $man{ $setting } = 0;
  }

  my %opt;

  if ( defined $optionalEntries )
  {
    foreach my $setting ( @$optionalEntries )
    {
      if ( exists $opt{ $setting } )
      {
        die "Duplicate setting name \"$setting\".\n";
      }

      $opt{ $setting } = 0;
    }
  }

  foreach my $key ( keys %$configEntries )
  {
    if ( defined $man{ $key } )
    {
      if ( length( $configEntries->{ $key } ) == 0 )
      {
        die "Setting \"$key\" has an empty value in file \"$filenameForErrorMessage\".\n";
      }

      $man{ $key } = 1;
      next;
    }

    if ( defined $opt{ $key } )
    {
      next;
    }

    die "Unknown setting \"$key\" in file \"$filenameForErrorMessage\".\n";
  }

  foreach my $key ( keys %man )
  {
    if ( $man{ $key } != 1 )
    {
      die "Missing setting \"$key\" in file \"$filenameForErrorMessage\".\n";
    }
  }
}


1;  # The module returns a true value to indicate it compiled successfully.
