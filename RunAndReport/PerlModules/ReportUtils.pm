
# Copyright (C) 2011-2019 R. Diez - Licensed under the GNU AGPLv3

package ReportUtils;

use strict;
use warnings;

use XML::Parser;
use File::Spec;
use File::Glob;

use StringUtils;
use FileUtils;
use ConfigFile;
use MiscUtils;


sub write_stdout ( $ )
{
  ( print STDOUT $_[0] ) or
     die "Error writing to standard output: $!\n";
}


sub html_escape ( $ )
{
  if ( 1 )
  {
    use HTML::Escape qw();

    return HTML::Escape::escape_html( $_[0] );
  }
  else
  {
    use HTML::Entities;

    # Routine HTML::Entities::encode_entities() is rather slow. HTML::Escape::escape_html() is usually faster.

    return HTML::Entities::encode_entities( $_[0] );
  }
}


sub check_file_exists ( $ )
{
  my $filename = shift;

  if ( not -f $filename )
  {
    die "File \"$filename\" does not exist or is not a regular file.\n";
  }
}

sub collect_all_reports ( $ $ $ $ $ )
{
  my $dirname            = shift;
  my $reportExtension    = shift;
  my $optionalEntries    = shift;  # Reference to an array.
  my $allReportsArrayRef = shift;
  my $failedCount        = shift;

  my $globPattern = FileUtils::cat_path( $dirname, "*" . $reportExtension );

  my @matchedFiles = File::Glob::bsd_glob( $globPattern, &File::Glob::GLOB_ERR | &File::Glob::GLOB_NOSORT );

  if ( &File::Glob::GLOB_ERROR )
  {
    die "Error listing existing directories: $!\n";
  }

  $$failedCount = 0;

  foreach my $filename ( @matchedFiles )
  {
    if ( FALSE )
    {
      print "File found: $filename\n";
    }

    check_file_exists( $filename );

    my %allEntries;

    load_report( $filename, $optionalEntries, \%allEntries );

    my $hideOptionStr = $allEntries{ "HideFromReportIfSuccessful" };
    my $hideOption;

    if ( $hideOptionStr eq "true" )
    {
      $hideOption = TRUE;
    }
    elsif ( $hideOptionStr eq "false" )
    {
      $hideOption = FALSE;
    }
    else
    {
      die "Error loading report \"$filename\": Setting 'HideFromReportIfSuccessful' has invalid value '$hideOptionStr'.\n";
    }

    my $exitCode = $allEntries{ "ExitCode" };

    if ( $exitCode == 0 && $hideOption )
    {
      next;
    }

    if ( $exitCode != 0 )
    {
      ++$$failedCount;
    }

    push @$allReportsArrayRef, \%allEntries;
  }
}


sub load_report ( $ $ $ )
{
  my $filename          = shift;
  my $optionalEntries   = shift;  # Reference to an array.
  my $allEntriesHashRef = shift;

  ConfigFile::read_config_file( $filename, $allEntriesHashRef );

  my @mandatoryEntries = qw( ReportFormatVersion
                             UserFriendlyName
                             ProgrammaticName
                             ExitCode
                             HideFromReportIfSuccessful
                             LogFile
                             StartTimeLocal
                             StartTimeUTC
                             FinishTimeLocal
                             FinishTimeUTC
                             ElapsedSeconds  );

  ConfigFile::check_config_file_contents( $allEntriesHashRef,
                                          \@mandatoryEntries,
                                          $optionalEntries,
                                          $filename );

  my $formatVersion = $allEntriesHashRef->{ "ReportFormatVersion" };

  if ( $formatVersion != 1 )
  {
    die "Error loading report \"$filename\": Report file format version '$formatVersion' not supported.\n";
  }
}


sub add_setting ( $ $ $ )
{
  my $report  = shift;
  my $setting = shift;
  my $value   = shift;

  if ( exists $report->{ $setting } )
  {
    die "Internal error: The report has already a setting called '$setting'.\n";
  }

  $report->{ $setting } = $value;
}



use constant HTML_FILE_HEADER =>
    "<!DOCTYPE HTML>\n" .
    "<html>\n" .
    "<head>\n" .
    "<title>Log file</title>\n" .
    "<style type=\"text/css\">\n" .

    ".logLineTable td {\n" .
    "  font-family: monospace;\n" .
    "  text-align:left;\n" .
    "  padding-left:  10px;\n" .
    "  padding-right: 10px;\n" .
    "  border-width: 0px;\n" .
    "  word-break: break-all;\n" .  # CSS3, only supported by Microsoft Internet Explorer (tested with version 9) and
                                    # Chromium (tested with version 17), but not by Firefox 10.
                                    # Without it, very long lines will cause horizontal scroll-bars to appear at bottom of the page.
                                    # The alternative 'break-word' works well with Chromium, chopping at word boundaries except when the word is too long,
                                    # but unfortunately it does not well with IE 9 (scroll-bars appear again).
    "}\n" .

    "\n" .

    ".logLineTable td:first-child {\n" .
    "  text-align:right;\n" .
    "  padding-left: 2px;\n" .
    "  padding-right: 2px;\n" .
    "  border-style: solid;\n" .
    "  border-width: 1px;\n" .
    "  border-color: #B0B0B0;\n" .
    "  white-space: nowrap;\n" .
    "  vertical-align: top;\n" .
    "}\n" .

    "</style>\n" .
    "</head>\n" .
    "<body>\n" .
    "<table class=\"logLineTable\" border=\"1\" CELLSPACING=\"0\">\n" .
    "<thead>\n" .
    "<tr>\n" .
    "<th>Line</th>\n" .
    "<th style=\"text-align: left;\">Log Line Text</th>\n" .
    "</tr>\n" .
    "</thead>\n" .
    "<tbody>\n";

use constant HTML_FILE_FOOTER =>
    "</tbody>\n" .
    "</table>\n" .
    "<p>End of log.</p>\n" .
    "</body>\n" .
    "</html>\n";

my $compiledRegex_stripTrailingNewLineChars = qr/[\n\r]+\z/a;  # a = ASCII (might improve performance).
my $compiledRegex_substCarriageReturn = qr/\r/a;


sub convert_text_file_to_html ( $ $ $ )
{
  my $srcFilename     = shift;
  my $destFilename    = shift;
  my $defaultEncoding = shift;

  open( my $srcFile, "<", $srcFilename )
    or die "Cannot open file \"$srcFilename\": $!\n";

  if ( MiscUtils::FALSE )
  {
    # Turning on the encoding here slows reading down considerably,
    # at least with utf-8-strict, which seems the default under Linux.
    binmode( $srcFile, ":encoding($defaultEncoding)" )  # Also avoids CRLF conversion.
      or die "Cannot access file in binary mode or cannot set the file encoding: $!\n";
  }
  else
  {
    # I am experimenting without specifying the encoding.
    # I you encounter any problems, drop me a line.
    binmode( $srcFile )  # Also avoids CRLF conversion.
      or die "Cannot access file in binary mode: $!\n";
  }

  open( my $destFile, ">", $destFilename )
    or die "Cannot open for writing file \"$destFilename\": $!\n";

  binmode( $destFile )  # Avoids CRLF conversion.
    or die "Cannot access file in binary mode: $!\n";

  $destFile->autoflush( 0 );  # Make sure the file is being buffered, for performance reasons.

  # Alternative with HTML::FromText :
  #   my $logFilenameContents = FileUtils::read_whole_binary_file( $logFilename );
  #   my $t2h  = HTML::FromText->new( { lines => 1 } );
  #   my $logContentsAsHtml = $t2h->parse( $logFilenameContents );

  (print $destFile HTML_FILE_HEADER) or
      die "Cannot write to file \"$destFilename\": $!\n";


  # This loop is rather slow. I've tried the following, which wasn't any faster after all:
  #
  #  1) use File::Slurp;
  #     my @lines = read_file( $srcFilename, binmode => ":encoding($defaultEncoding)" );
  #
  #  2) my @all = readline( $file );
  #
  #  3) Reading the whole file as a single string at once, in the hope that the UTF-8
  #     conversion was done faster on a whole single string:
  #
  #       binmode( $file, ":encoding($default_encoding)" )  # Also avoids CRLF conversion.
  #         or die "Cannot access file in binary mode or cannot set the file encoding: $!\n";
  #       my $read_res = read( $file, $file_content, $file_size );
  #
  #     And then I split the lines with:
  #
  #       my @all_lines = split( /\x0A/, $file_content );
  #
  # The one thing I haven't tried is a trick like the following, which turns a string into hex:
  #
  #   $file_content =~ s/(.)/sprintf("%x",ord($1))/eg;
  #
  # I could be possible to modify the regex and map the calls in some way so that the routine
  # gets called on each match, without modifying the original string.


  for ( my $lineNumber = 1; ; ++$lineNumber )
  {
    my $line = readline( $srcFile );

    last if not defined $line;

    # Strip trailing new-line characters.
    $line =~ s/$compiledRegex_stripTrailingNewLineChars//;

    # Git shows and updates every second or so a progress message like this:
    #    Checking out files:   0% (2/38541)
    # These messages end with a Carriage Return (\r, 0x0D) only, without a Line Feed (\n, 0x0A) at the end,
    # and that's not displayed well in the HTML report. Therefore,
    # convert all embedded Carriage Return codes into HTML line breaks here.
    $line =~ s/$compiledRegex_substCarriageReturn/<br>/g;

    (print $destFile
           "<tr>" .
           "<td>$lineNumber</td>" .
           "<td>" . html_escape( $line ) . "</td>" .
           "</tr>\n"
    ) or
      die "Cannot write to file \"$destFilename\": $!\n";
  }

  (print $destFile HTML_FILE_FOOTER ) or
    die "Cannot write to file \"$destFilename\": $!\n";

  close_or_die( $destFile );
  close_or_die( $srcFile  );
}


sub generate_html_log_file_and_cell_links ( $ $ $ $ $ $ )
{
  my $logFilename     = shift;
  my $logsSubdir      = shift;
  my $defaultEncoding = shift;
  my $drillDownTarget = shift;  # Can be undef.
  my $disableConversionToHtml = shift;
  my $htmlLogFileCreationSkippedAsItWasUpToDate = shift;

  check_file_exists( $logFilename );

  use constant VERBOSE => 0;

  if ( VERBOSE )
  {
    write_stdout( "Processing log file: $logFilename\n" );
  }

  my ( $volume, $directories, $logFilenameOnly ) = File::Spec->splitpath( $logFilename );

  my $htmlLogFilenameOnly;

  if ( ! $disableConversionToHtml )
  {
  $htmlLogFilenameOnly = $logFilenameOnly . ".html";

  my $htmlLogFilename = FileUtils::cat_path( $volume, $directories, $htmlLogFilenameOnly );


  # Skip the HTML log file creation if already up to date.
  $$htmlLogFileCreationSkippedAsItWasUpToDate = MiscUtils::FALSE;

  if ( -f $htmlLogFilename )
  {
    my @htmlFileStats = stat( $htmlLogFilename );

    if ( scalar( @htmlFileStats ) == 0 )
    {
      die "Error accessing file \"$htmlLogFilename\": $!\n";
    }

    my $mtime2 = $htmlFileStats[ 9 ];

    if ( ! defined( $mtime2 ) )
    {
      die "Error accessing file \"$htmlLogFilename\": The stat routine does not support the 'last modification time'.\n";
    }

    if ( VERBOSE )
    {
      write_stdout( "Timestamp of HTML file: $mtime2 \n" );
    }


    my @textFileStats = stat( $logFilename );

    if ( scalar( @textFileStats ) == 0 )
    {
      die "Error accessing file \"$logFilename\": $!\n";
    }

    my $mtime1 = $textFileStats[ 9 ];

    if ( ! defined( $mtime1 ) )
    {
      die "Error accessing file \"$logFilename\": The stat routine does not support 'last modification time'.\n";
    }

    if ( VERBOSE )
    {
      write_stdout( "Timestamp of text file: $mtime1 \n" );
    }

    if ( $mtime2 >= $mtime1 )
    {
      $$htmlLogFileCreationSkippedAsItWasUpToDate = MiscUtils::TRUE;
    }
  }
  else
  {
    if ( VERBOSE )
    {
      write_stdout( "HTML version of log file does not exist: $htmlLogFilename\n" );
    }
  }

  if ( $$htmlLogFileCreationSkippedAsItWasUpToDate )
  {
    if ( VERBOSE )
    {
      write_stdout( "Skipping conversion to HTML because the HTML file is up to date.\n" );
    }
  }
  else
  {
    if ( VERBOSE )
    {
      write_stdout( "Converting the text file to HTML.\n" );
    }

    convert_text_file_to_html( $logFilename, $htmlLogFilename, $defaultEncoding );
  }
  }


  my $html = "";

  $html .= "<td style=\"text-align: center;\">";

  if ( defined $drillDownTarget )
  {
    $html .= html_link( $drillDownTarget, "Breakdown" );
    $html .= " or ";
  }

  if ( ! $disableConversionToHtml )
  {
    my $link1 = FileUtils::cat_path( $logsSubdir, $htmlLogFilenameOnly );
    $html .= html_link( $link1, "HTML" );
    $html .= " or ";
  }

  my $plainTextLinkCaption = $disableConversionToHtml ? "log" : "plain txt";

  my $link2 = FileUtils::cat_path( $logsSubdir, $logFilenameOnly );

  $html .= html_link( $link2, $plainTextLinkCaption );
  $html .= "</td>\n";

  if ( VERBOSE )
  {
    write_stdout( "\n" );
  }

  return $html;
}


sub html_link ( $ $ )
{
  my $link = shift;
  my $text = shift;

  return "<a href=\"" . html_escape( $link ) . "\">" . html_escape( $text ) . "</a>";
}


1;  # The module returns a true value to indicate it compiled successfully.
