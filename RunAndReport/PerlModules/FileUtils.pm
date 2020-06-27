
# Copyright (C) 2011-2019 R. Diez - Licensed under the GNU AGPLv3

package FileUtils;

use strict;
use warnings;

use File::Path;

use StringUtils;
use MiscUtils;


#------------------------------------------------------------------------
#
# If the given directory exists, delete it. Then create it.
#

sub recreate_dir ( $ )
{
  my $subdirName = shift;

  if ( -d $subdirName )
  {
    my $deleteCount = File::Path::rmtree( $subdirName );

    if ( $deleteCount < 1 )
    {
      die "Cannot delete folder \"$subdirName\", the delete count was $deleteCount.\n";
    }
  }

  # Note that mkpath() raises an error if it fails.
  File::Path::mkpath( $subdirName );
}


#------------------------------------------------------------------------
#
# Creates folder if it doesn't exist.
#
# Security note: If it fails, the error message will contain the file it couldn't delete.
#

sub create_folder_if_does_not_exist ( $ )
{
  my $folder = shift;

  if ( not -d $folder )
  {
    # Note that mkpath() raises an error if it fails.
    File::Path::mkpath( $folder );
  }
}


#------------------------------------------------------------------------
#
# Concatenates different path components together,
# adding dir slashes where necessary.
#
# Normally, the last element to concatenate is the file name.
#
# Example:  cat_path( "dir", "subdir", "file.txt" )
#           returns "dir/subdir/file.txt".
#
# If a component is empty or undef, it ignores it.
# For example, the following are equivalent:
#    cat_path( "a", "b" )
#    cat_path( "", "a", "", "b", "" )
#    cat_path( undef, "a", undef, "b", undef )
# This helps when joining the results of File::Spec->splitpath().
#
# Never returns undef, the smallest thing it ever returns
# is the empty string "".
#
# An alternative to consider would be File::Spec->catpath().
#

sub cat_path
{
  my $slash = "/";
  my $res = "";

  for ( my $i = 0; $i < scalar(@_); $i++ )
  {
    if ( not defined($_[$i]) or $_[$i] eq "" )
    {
      next;
    }

    if ( $res eq "" or StringUtils::str_ends_with( $res, $slash ) )
    {
      $res .= $_[$i];
    }
    else
    {
      $res .= $slash . $_[$i];
    }
  }

  return $res;
}


#------------------------------------------------------------------------
#
# Reads a whole text file, returns it as an array of lines.
#
# Respects Windows or Unix line terminations.
#
# Security warning: The error messages contain the file path.
#

sub read_text_file ( $ )
{
  my $file_path = shift;

  open( my $f, "<", $file_path )
    or die "Cannot open file \"$file_path\": $!\n";

  binmode( $f )  # Avoids CRLF conversion.
    or die "Cannot access file in binary mode: $!\n";

  my @all_lines = readline( $f );

  close_or_die( $f );

  return @all_lines;
}


#------------------------------------------------------------------------
#
# Overwrites a file with the contents of a single string.
#
# Uses a binary write, so it respects any Windows / Unix new-line characters in the string.
#

sub write_string_to_new_file ( $ $ )
{
  my $file_path = shift;
  my $all_in_single_string = shift;

  open ( TEXT_FILE, ">", $file_path )
    or die "Cannot open for writing file \"$file_path\": $!\n";

  binmode( TEXT_FILE )  # Avoids CRLF conversion.
    or die "Cannot access file in binary mode: $!\n";

  (print TEXT_FILE $all_in_single_string) or
    die "Cannot write to file \"$file_path\": $!\n";

  close_or_die( *TEXT_FILE );
}


#------------------------------------------------------------------------
#
# Reads a whole binary file, returns it as a scalar.
#
# Security warning: The error messages contain the file path.
#
# Alternative: use Perl module File::Slurp
#

sub read_whole_binary_file ( $ )
{
  my $file_path = shift;

  open( FILE, "<", $file_path )
    or die "Cannot open file \"$file_path\": $!\n";

  binmode( FILE )  # Avoids CRLF conversion.
    or die "Cannot access file in binary mode: $!\n";

  my $file_content;
  my $file_size = -s FILE;

  my $read_res = read( FILE, $file_content, $file_size );

  if ( not defined($read_res) )
  {
    die qq<Error reading from file "$file_path": $!\n>;
  }

  if ( $read_res != $file_size )
  {
    die qq<Error reading from file "$file_path".\n>;
  }

  close_or_die( *FILE );

  return $file_content;
}


1;  # The module returns a true value to indicate it compiled successfully.
