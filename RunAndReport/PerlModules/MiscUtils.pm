
# Copyright (C) 2011-2019 R. Diez - Licensed under the GNU AGPLv3

package MiscUtils;

require Exporter;
  @ISA = qw(Exporter);

  # Symbols to export by default.
  @EXPORT = qw( close_or_die TRUE FALSE );

  # Symbols to export on request.
  @EXPORT_OK = qw();

use strict;
use warnings;

use constant TRUE  => 1;
use constant FALSE => 0;


#------------------------------------------------------------------------
#
# Thin wrapper around close().
#

sub close_or_die ( $ )
{
  close ( $_[0] ) or die "Cannot close file descriptor: $!\n";
}


1;  # The module returns a true value to indicate it compiled successfully.
