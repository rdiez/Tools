
# Copyright (C) 2011-2019 R. Diez - Licensed under the GNU AGPLv3

package ProcessUtils;

use strict;
use warnings;


sub run_process_exit_code_0
{
  my $exitCode = run_process( @_ );

  if ( $exitCode != 0 )
  {
    die "The following external command signalled an error with exit code $exitCode: " . join( ' ', @_ ) . "\n";
  }
}


sub run_process
{
  my $ret = system( @_ );

  if ( $ret == -1 )
  {
    # system() has probably already printed an error message, but you cannot be sure.
    # In any case, the error message does not contain the whole failed command.
    die "Failed to execute external command \"" . join( ' ', @_ ) . "\", ".
        "the error returned was: $!" . "\n";
  }

  my $exit_code   = $ret >> 8;
  my $signal_num  = $ret & 127;
  my $dumped_core = $ret & 128;

  if ( $signal_num != 0 || $dumped_core != 0 )
  {
    die "Error: Child process \"" . join( ' ', @_ ) . "\" died: ".
        reason_died_from_wait_code( $ret ) . "\n";
  }

  return $exit_code;
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


1;  # The module returns a true value to indicate it compiled successfully.
