
Office Software Automation Scripts

These scripts try to generate easy-to-understand error messages if some file operation fails.


- RDiezDocUtils.vbs is for LibreOffice:

  - This file has code to convert a LibreOffice Writer document to a PDF file,
    and then generate a second PDF file with extra content in the background or foreground
    (typically a letterhead or watermark) on all pages.

  - There is also code to create an "Archived" subdirectory where the given file resides and copy
    the file there. The current date and time are appended to the archived filename.

  - A routine and a companion script are provided in order to automate opening a password-protected
    LibreOffice document or spreadsheet.


The following .vbs scripts for Microsoft Windows support user messages in English, German or Spanish.

  - PromptAndProcess.vbs

    Sometimes you need to write a small script that lets a user select a file
    and do some operation on it, like convert it to another format.
    This script provides a full-blown example for a simple file copy operation.


  - PromptForFile.vbs and PromptForFileExample.sh

    Prompts the user for a file with Windows' standard "open file" dialog,
    and prints the selected filename to stdout. Useful for Cygwin bash scripts.


  - AddLetterhead.vbs

    Given a PDF file, generates a second PDF with extra content in the background or foreground
    (typically a letterhead or watermark) on all pages.


  - ConvertWordToPDFWithBackground.vbs

    Converts a Microsoft Word document to a PDF file, and then generates a second PDF file with
    extra content in the background or foreground (typically a letterhead or watermark) on all pages.


  - CopyToOldVersionsArchive.vbs

    Creates an "Archived" subdirectory where the given file resides and copies
    the file there. The current date and time are appended to the archived filename.


The following scripts are primarily for Linux (or Cygwin):

  - add-letterhead.sh

    Adds extra content in the background (typically a letterhead or watermark)
    to all pages of a PDF document.


  - copy-to-old-versions-archive.sh

    Creates an "Archived" subdirectory where the given file resides and copies
    the file there. The current date and time are appended to the archived filename.
    There is also a move-to-old-versions-archive.sh variant.
