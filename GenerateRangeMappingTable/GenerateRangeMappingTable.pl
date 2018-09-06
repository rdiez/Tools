#!/usr/bin/perl

=head1 OVERVIEW

GenerateRangeMappingTable version 1.00

This tool generates a mapping table (a look-up table) between an integer range
and another numeric range (integer or floating point).
The mapping can be linear or exponential.

This script takes no command-line arguments, so you will have to modify the
range parameters in the source code. This is probably worth improving in the future.

There are several options to control the table format, and an option to plot the values with gnuplot.
Other plotting options would be a nice addition, like a plain-text plotting.

=head1 EXIT CODE

Exit code: 0 on success, some other value on error.

=head1 FEEDBACK

Please send feedback to rdiezmail-tools at yahoo.de

=head1 LICENSE

Copyright (C) 2017 R. Diez

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

use strict;
use warnings;

# In order to install module Carp::Assert on Ubuntu/Debian, install package 'libcarp-assert-perl'.
# Use "no Carp::Assert;" in order to turn off assertions, which makes the script run faster.
use Carp::Assert;

use Pod::Usage;
use FindBin qw( $Bin $Script );


use constant TRUE  => 1;
use constant FALSE => 0;

use constant EXIT_CODE_SUCCESS => 0;
use constant EXIT_CODE_FAILURE => 1;


#------------------------------------------------------------------------
#
# User configuration.
#

my $sourceRangeBegin =  1;  # You can invert the range, like begin=10 and end=1.
my $sourceRangeEnd   = 10;

my $destinationRangeBegin =  10  ;
my $destinationRangeEnd   = 100.5;

use constant MAP_METHOD_LINEAR      => 1;
use constant MAP_METHOD_EXPONENTIAL => 2;
use constant EXPONENT => 1 / 2.2;

use constant MAP_METHOD => MAP_METHOD_EXPONENTIAL;


# Warning: Using a custom precision is much slower.
use constant SHOULD_USE_CUSTOM_PRECISION => FALSE;

BEGIN
{
  if ( SHOULD_USE_CUSTOM_PRECISION )
  {
    require bignum;
    bignum->import( accuracy => 30 );
  }
}


# If you do not round, you will get floating-point values.
use constant SHOULD_ROUND_RESULT => FALSE;

# Pads shorter values with spaces to that data columns are vertically aligned and right-justified.
# This delays the printing until the whole table has been calculated.
use constant SHOULD_ALIGN_PRINTED_COLUMNS => TRUE;

# If you want to embedded the generated look-up table in a C program,
# you will probably not need the source range column.
use constant SHOULD_PRINT_SRC_RANGE => TRUE;


use constant PLOTTING_METHOD_NONE                => 1;
use constant PLOTTING_METHOD_GNUPLOT_HTML        => 2;
use constant PLOTTING_METHOD_GNUPLOT_PDF         => 3;
# In order to use the X11 viewer on Ubuntu/Debian, install package 'gnuplot-x11' instead of 'gnuplot'.
use constant PLOTTING_METHOD_GNUPLOT_X11_VIEWER  => 4;

use constant GNUPLOT_FILENAME_HTML => "diagram.html";
use constant GNUPLOT_FILENAME_PDF  => "diagram.pdf";

use constant PLOTTING_METHOD => PLOTTING_METHOD_NONE;


#------------------------------------------------------------------------
#
# Generic routines.
#

sub write_stdout ( $ )
{
  my $str = shift;

  ( print STDOUT $str ) or
     die "Cannot write to standard output: $!\n";
}

sub write_stderr ( $ )
{
  my $str = shift;

  ( print STDERR $str ) or
     die "Error writing to standard error: $!\n";
}


sub max ($$) { $_[$_[0] < $_[1]] }
sub min ($$) { $_[$_[0] > $_[1]] }


sub is_value_in_range ($$$)
{
  my $value      = shift;
  my $rangeBegin = shift;
  my $rangeEnd   = shift;

  # These comparisons could fail because of floating point inaccuracy. I need to research this further.

  return $value >= min( $rangeBegin, $rangeEnd )  && $value <= max( $rangeBegin, $rangeEnd );
}


sub map_range_linearly ($$$$$)
{
  my $valueInSrcRange = shift;
  my $srcRangeBegin   = shift;
  my $srcRangeEnd     = shift;
  my $destRangeBegin  = shift;
  my $destRangeEnd    = shift;

  assert( is_value_in_range( $valueInSrcRange, $srcRangeBegin, $srcRangeEnd ) ) if DEBUG;

  my $mappedValue = $destRangeBegin + ( $destRangeEnd - $destRangeBegin ) * ( $valueInSrcRange - $srcRangeBegin ) / ( $srcRangeEnd - $srcRangeBegin );

  assert( is_value_in_range( $mappedValue, $destRangeBegin, $destRangeEnd ) ) if DEBUG;

  return $mappedValue;
}


sub round_to_nearest_integer ($)
{
  # Alternatively, we could use Perl module Math::Round.

  my $float = shift;

  my $rounded = int( $float + $float / abs( $float * 2 || 1 ) );
}


sub get_cmdline_help_from_pod ( $ )
{
  my $pathToThisScript = shift;

  my $memFileContents = "";

  open( my $memFile, '>', \$memFileContents )
      or die "Cannot create in-memory file: $!\n";

  binmode( $memFile );  # Avoids CRLF conversion.

  pod2usage( -exitval    => "NOEXIT",
             -verbose    => 2,
             -noperldoc  => 1,  # Perl does not come with the perl-doc package as standard (at least on Debian 4.0).
             -input      => $pathToThisScript,
             -output     => $memFile );

  $memFile->close()
      or die "Cannot close in-memory file: $!\n";

  return $memFileContents;
}


#------------------------------------------------------------------------
#
# Helpers to run a process.
#

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


sub run_process_exit_code_0
{
  my $exitCode = run_process( @_ );

  if ( $exitCode != 0 )
  {
    die "The following external command signalled an error with exit code $exitCode: " . join( ' ', @_ ) . "\n";
  }
}


#------------------------------------------------------------------------
#
# Aplication logic.
#

use constant COLUMN_INDEX_SRC  => 0;
use constant COLUMN_INDEX_DEST => 1;

sub calculate_row_format_string ( $$ )
{
  my $rowWidthSrc  = shift;
  my $rowWidthDest = shift;

  my $formatStr = "";

  if ( SHOULD_PRINT_SRC_RANGE )
  {
    $formatStr .= "%";
    $formatStr .= ( COLUMN_INDEX_SRC + 1 );
    $formatStr .= "\$";

    if ( $rowWidthSrc != 0 )
    {
      $formatStr .= $rowWidthSrc;
    }

    $formatStr .= "s, ";
  }

  $formatStr .= "%";
  $formatStr .= ( COLUMN_INDEX_DEST + 1 );
  $formatStr .= "\$";

  if ( $rowWidthDest != 0 )
  {
    $formatStr .= $rowWidthDest;
  }

  $formatStr .= "s,";

  if ( FALSE )
  {
    write_stdout( "Format string: $formatStr\n" );
  }

  $formatStr .= "\n";

  return $formatStr;
}


sub print_row ( $$$$ )
{
  my $shouldAlignPrintedColumns = shift;
  my $formatStr = shift;
  my $rowData   = shift;
  my $tableData = shift;

  if ( FALSE )
  {
    write_stdout( "Row data: " . join( ", ", @$rowData ) . "\n" );
  }

  if ( $shouldAlignPrintedColumns )
  {
    # We need to store the row data for later processing.
    push @$tableData, $rowData;
  }
  else
  {
    # We can print the row straight away.
    write_stdout( sprintf( $formatStr, @$rowData ) );
  }
}


sub generate_element ( $$$$ )
{
  my $valueInSrcRange = shift;
  my $plotValuesX     = shift;
  my $plotValuesY     = shift;
  my $rowData         = shift;

  if ( PLOTTING_METHOD != PLOTTING_METHOD_NONE )
  {
    push @$plotValuesX, $valueInSrcRange;
  }

  my $indexDelta = $valueInSrcRange - $sourceRangeBegin;

  my $valueInDestRange;

  if ( MAP_METHOD == MAP_METHOD_LINEAR )
  {
    $valueInDestRange = map_range_linearly( $valueInSrcRange, $sourceRangeBegin, $sourceRangeEnd, $destinationRangeBegin, $destinationRangeEnd );
  }
  elsif ( MAP_METHOD == MAP_METHOD_EXPONENTIAL )
  {
    my $srcNormalised = map_range_linearly( $valueInSrcRange, $sourceRangeBegin, $sourceRangeEnd, 0, 1 );

    my $temp1 = $srcNormalised ** EXPONENT;

    $valueInDestRange = map_range_linearly( $temp1, 0, 1, $destinationRangeBegin, $destinationRangeEnd );
  }
  else
  {
    die qq<Wrong mapping method "@{[MAP_METHOD]}".\n>;
  }

  push @$rowData, $valueInSrcRange;

  my $valueToPrint = SHOULD_ROUND_RESULT ? round_to_nearest_integer( $valueInDestRange ) : $valueInDestRange;

  push @$rowData, $valueToPrint;

  if ( PLOTTING_METHOD != PLOTTING_METHOD_NONE )
  {
    push @$plotValuesY, $valueInDestRange;
  }
}


#------------------------------------------------------------------------
# Main routine

sub main ()
{
  # Autoflushing helps prevent the normal output and errors getting intermixed
  # when this script is invoked from a shell that is redirecting output.
  autoflush STDOUT;
  autoflush STDERR;

  if ( scalar( @ARGV ) != 0 )
  {
    write_stderr( "\nThis script takes no command-line arguments. The help text is:\n\n" );

    write_stderr( get_cmdline_help_from_pod( "$Bin/$Script" ) );
    return EXIT_CODE_FAILURE;
  }


  my $formatStr;

  if ( !SHOULD_ALIGN_PRINTED_COLUMNS )
  {
    $formatStr = calculate_row_format_string( 0, 0 );
  }


  my @plotValuesX;
  my @plotValuesY;
  my @tableData;

  write_stdout( "Generated table:\n\n" );

  if ( $sourceRangeBegin <= $sourceRangeEnd )
  {
    for ( my $i = $sourceRangeBegin; $i <= $sourceRangeEnd; ++$i )
    {
      my @rowData;

      generate_element( $i, \@plotValuesX, \@plotValuesY, \@rowData );

      print_row( SHOULD_ALIGN_PRINTED_COLUMNS, $formatStr, \@rowData, \@tableData );
    }
  }
  else
  {
    for ( my $i = $sourceRangeBegin; $i >= $sourceRangeEnd; --$i )
    {
      my @rowData;

      generate_element( $i, \@plotValuesX, \@plotValuesY, \@rowData );

      print_row( SHOULD_ALIGN_PRINTED_COLUMNS, $formatStr, \@rowData, \@tableData );
    }
  }


  if ( SHOULD_ALIGN_PRINTED_COLUMNS )
  {
    my $srcLen  = 0;
    my $destLen = 0;

    foreach my $rowData ( @tableData )
    {
      $srcLen  = max( $srcLen , length( $rowData->[ COLUMN_INDEX_SRC  ] ) );
      $destLen = max( $destLen, length( $rowData->[ COLUMN_INDEX_DEST ] ) );
    }

    $formatStr = calculate_row_format_string( $srcLen, $destLen );

    foreach my $rowData ( @tableData )
    {
      print_row( FALSE, $formatStr, $rowData, undef );
    }
  }


  write_stdout( "\n" );

  my $isGnuPlot = PLOTTING_METHOD == PLOTTING_METHOD_GNUPLOT_HTML ||
                  PLOTTING_METHOD == PLOTTING_METHOD_GNUPLOT_PDF  ||
                  PLOTTING_METHOD == PLOTTING_METHOD_GNUPLOT_X11_VIEWER;

  if ( $isGnuPlot )
  {
    # In order to install module Chart::Gnuplot on Ubuntu/Debian, install package 'libchart-gnuplot-perl'.
    require Chart::Gnuplot;
    Chart::Gnuplot->import;

    my @gnuPlotOptions;
    my $outputFilename;

    if ( PLOTTING_METHOD == PLOTTING_METHOD_GNUPLOT_HTML )
    {
      # Unfortunately, the generated image in the HTML Canvas is actually a bitmap,
      # so it does not scale well.
      push @gnuPlotOptions, "terminal", "canvas size 500,400 standalone mousing enhanced";
      $outputFilename = GNUPLOT_FILENAME_HTML;
    }
    elsif ( PLOTTING_METHOD == PLOTTING_METHOD_GNUPLOT_PDF )
    {
      push @gnuPlotOptions, "terminal", "pdf";  # Alternative: pdfcairo
      $outputFilename = GNUPLOT_FILENAME_PDF;
    }
    elsif ( PLOTTING_METHOD == PLOTTING_METHOD_GNUPLOT_X11_VIEWER )
    {
      # Unfortunately, this method is inconvenient, because closing the window does not make gnuplot exit.
      push @gnuPlotOptions, "terminal", "x11";
    }
    else
    {
      die qq<Wrong plotting method "@{[PLOTTING_METHOD]}".\n>;
    }

    if ( PLOTTING_METHOD != PLOTTING_METHOD_GNUPLOT_X11_VIEWER )
    {
      push @gnuPlotOptions, "output", $outputFilename;
    }

    push @gnuPlotOptions, "title", "Range mapping diagram";
    push @gnuPlotOptions, "xlabel", "Source range";
    push @gnuPlotOptions, "ylabel", "Destination range";

    my $chart = Chart::Gnuplot->new( @gnuPlotOptions );

    my $dataSet = Chart::Gnuplot::DataSet->new(
         xdata => \@plotValuesX,
         ydata => \@plotValuesY,
         # title => "Plotted data",
         style => "linespoints"
       );

    write_stdout( "Generating plot...\n" );
    $chart->plot2d( $dataSet );

    if ( PLOTTING_METHOD != PLOTTING_METHOD_GNUPLOT_X11_VIEWER )
    {
      write_stdout( "Opening file \"" . $outputFilename . "\"...\n" );
      run_process_exit_code_0( "xdg-open", $outputFilename );
      write_stdout( "Finished opening file.\n" );
    }
  }

  return EXIT_CODE_SUCCESS;
}


# ----------- Entry point -----------

# Just call the main() routine.
# Note that main() returns the exit code.

my $ret_val;

$ret_val = main();

exit $ret_val;

# End of program
