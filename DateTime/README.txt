
days.sh

Given a date, this script prints how many days ago it was,
or how many days in the future it is.

Example outputs:

$ days.sh 21/10/2024
  21/10/2024 was 52 weeks and 2 days (366 days) ago.

$ days.sh 21/10/2024
  52 weeks and 1 day (365 days) until 21/10/2024.

The script currently recognises dates in the following formats:
  21/10/2024
  21.10.2024
  2024-10-21
But you can easily modify the script in oder to pass other
date format arguments to 'dateutils.ddiff'.

At the moment, this script can only print the number of days and weeks.
Months and years are problematic because they are ambiguous,
as one month can be 28 to 31 days long, and one year 365 or 366 days,
but I am sure there are ways to implement this properly.

This tool is actually just a wrapper for 'dateutils.ddiff' (aka 'datediff'),
so it inherits its quirks. For example, 'dateutils.ddiff' thinks that 2024-1x-x3
is a valid date. I actually reported this lack of robustness:
  Insufficient date validation in datediff
  https://github.com/hroptatyr/dateutils/issues/163
Possible improvement: The script could parse the supported date formats itself,
and validate better.
