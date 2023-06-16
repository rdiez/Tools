
# Copyright (C) 2011-2019 R. Diez - Licensed under the GNU AGPLv3

package StringUtils;

use strict;
use warnings;


#------------------------------------------------------------------------
#
# Returns a true value if the string ends in the given 'ending'.
#

sub str_ends_with ( $ $ )
{
  my $str    = shift;
  my $ending = shift;

  if ( length($str) < length($ending) )
  {
    return 0;
  }

  return substr($str, -length($ending), length($ending)) eq $ending;
}


#------------------------------------------------------------------------
#
# Returns a true value if the string starts with the given 'beginning' argument.
#

sub str_starts_with ( $ $ )
{
  my $str = shift;
  my $beginning = shift;

  if ( length($str) < length($beginning) )
  {
    return 0;
  }

  return substr($str, 0, length($beginning)) eq $beginning;
}




#------------------------------------------------------------------------
#
# Removes leading and trailing blanks.
#
# Perl's definition of whitespace (blank characters) for the \s
# used in the regular expresion includes, among others, spaces, tabs,
# and new lines (\r and \n).
#

sub trim_blanks ( $ )
{
  my $retstr = shift;

  # NOTE: Removing blanks could perhaps be done faster with transliterations (tr///).

  # Strip leading blanks.
  $retstr =~ s/\A\s*//a;  # a = ASCII (might improve performance).

  # Strip trailing blanks.
  $retstr =~ s/\s*\z//a;

  return $retstr;
}


1;  # The module returns a true value to indicate it compiled successfully.
