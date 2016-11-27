
I usually write documentation in POD (Plain Old Documentation) format,
which is a markup language. You can embeded POD in Perl scripts (.pl files)
or have separate .pod files.

This script checks that the POD syntax in the given file is OK, and then
converts the documentation to HTML (in a fixed temporary file) and opens it
with the standard Web browser. Such automated steps are convenient when
writing or reading documentation.
