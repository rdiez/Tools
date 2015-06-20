
ReplaceTemplatePlaceholderWithFileContents.sh

This script reads a template text file and replaces all occurrences
of the given placeholder string with the contents of another file.
The resulting text is printed to stdout.


ReplaceTemplatePlaceholders.sh

This script reads a template text file and replaces all occurrences
of the given placeholder strings with the given strings.
The resulting text is printed to stdout.

Usage examples:
  ./ReplaceTemplatePlaceholders.sh  template.txt  "placeholder1" "replacement1"
  ./ReplaceTemplatePlaceholders.sh  form.txt  "[NAME]" "foo"  "[ADDRESS]" "bar"
  ./ReplaceTemplatePlaceholders.sh  spreadsheet.txt  "CURRENCY" "\$"
  ./ReplaceTemplatePlaceholders.sh  unix2dos.txt  $'\n' $'\r\n'

See the script source code for more information.
