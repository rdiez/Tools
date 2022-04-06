
RunAndReport.sh and GenerateHtmlReport.pl

Say you want to execute several tasks (commands) in a row, and each one of them generates sizeable log out.
Or you want to run a complex makefile with lots of targets, and each one runs long build commands.

At the end, you normally get a huge text file with all log output together. It is then difficult
to tell at once which tasks or targets failed, and which portion of the log output belongs to each one of them.

If you run each command with the RunAndReport.sh wrapper, copies of the log outputs will be placed
into separate files. The log files have a header with the command and the environment variables at execution time,
and a footer with the elapsed time.

Afterwards, you can use GenerateHtmlReport.pl to create a report table which neatly summarises
the succedded (green) or failed (red) status of each task. You can then drill down to the separate task log files.

In order to provide a quick overview, task results can be divided into groups, and execution reports can be nested
into subprojects.

Run Example.sh to create an example report file.
