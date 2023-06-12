#!/bin/bash

# This script demonstrates usage of RunAndReport.sh and GenerateHtmlReport.pl .
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


if (( $# != 0 )); then
  abort "This script takes no command-line arguments."
fi

BASE_DIR="$(readlink --canonicalize-existing --verbose -- ".")"

declare -r OUTPUT_DIR="$BASE_DIR/ExampleOutput"

rm -rf -- "$OUTPUT_DIR"
mkdir -- "$OUTPUT_DIR"

declare -r INTERNAL_REPORTS_DIR="$OUTPUT_DIR/InternalReports"
declare -r PUBLIC_REPORTS_BASE_DIR="$OUTPUT_DIR/Public"
declare -r SUBPROJECTS_PUBLIC_DIR="$OUTPUT_DIR/SubprojectPublic"

mkdir -- "$INTERNAL_REPORTS_DIR"
mkdir -- "$PUBLIC_REPORTS_BASE_DIR"
mkdir -- "$SUBPROJECTS_PUBLIC_DIR"

declare -r PUBLIC_LOG_FILES_SUBDIR="LogFiles"
declare -r REPORT_FILENAME="Report.html"

declare -r LOGS_DIR="$PUBLIC_REPORTS_BASE_DIR/$PUBLIC_LOG_FILES_SUBDIR"
mkdir -- "$LOGS_DIR"

declare -r GROUPS_FILENAME="$INTERNAL_REPORTS_DIR/groups.lst"
declare -r SUBPROJECTS_FILENAME="$INTERNAL_REPORTS_DIR/subprojects.lst"

# Create or truncate the groups file.
echo -n "" >"$GROUPS_FILENAME"

# Using a .txt extension for the log files, instead of a .log extension, is advisable.
# This way, the web browser will display logs immediately upon clicking on them,
# instead of asking how to open files which end in a .log extension.

./RunAndReport.sh  --id=TopLevel \
                   --userFriendlyName="My Report" \
                   --logFilename="$LOGS_DIR/TopLevel-Log.txt" \
                   --reportFilename="$INTERNAL_REPORTS_DIR/TopLevel.report" \
                   -- \
                   echo "Top level output."

./RunAndReport.sh  --id=Task1 \
                   --userFriendlyName="Task 1" \
                   --logFilename="$LOGS_DIR/Task1-Log.txt" \
                   --reportFilename="$INTERNAL_REPORTS_DIR/Task1.report" \
                   -- \
                   echo "Task 1 output."

./RunAndReport.sh  --id=Task2 \
                   --userFriendlyName="Task 2" \
                   --logFilename="$LOGS_DIR/Task2-Log.txt" \
                   --reportFilename="$INTERNAL_REPORTS_DIR/Task2.report" \
                   -- \
                   echo "Task 2 output."

echo "Group A = TaskA1 TaskA2"        >>"$GROUPS_FILENAME"
echo "Group B = TaskB1 TaskB2 TaskB3" >>"$GROUPS_FILENAME"

./RunAndReport.sh  --id=TaskA1 \
                   --userFriendlyName="Task A1" \
                   --logFilename="$LOGS_DIR/TaskA1-Log.txt" \
                   --reportFilename="$INTERNAL_REPORTS_DIR/TaskA1.report" \
                   -- \
                   echo "Task A1 output."

./RunAndReport.sh  --id=TaskA1 \
                   --userFriendlyName="Task A2" \
                   --logFilename="$LOGS_DIR/TaskA2-Log.txt" \
                   --reportFilename="$INTERNAL_REPORTS_DIR/TaskA2.report" \
                   -- \
                   echo "Task A2 output."

./RunAndReport.sh  --id=TaskB1 \
                   --userFriendlyName="Task B1" \
                   --logFilename="$LOGS_DIR/TaskB1-Log.txt"  \
                   --reportFilename="$INTERNAL_REPORTS_DIR/TaskB1.report" \
                   -- \
                   echo "Task B1 output."
set +o errexit
./RunAndReport.sh  --id=TaskB1 \
                   --userFriendlyName="Task B2" \
                   --logFilename="$LOGS_DIR/TaskB2-Log.txt" \
                   --reportFilename="$INTERNAL_REPORTS_DIR/TaskB2.report" \
                   -- \
                   bash -c "echo 'Task B2 failed output.' && false"
set -o errexit

./RunAndReport.sh  --id=TaskB3 \
                   --userFriendlyName="Task B3" \
                   --logFilename="$LOGS_DIR/TaskB3-Log.txt" \
                   --reportFilename="$INTERNAL_REPORTS_DIR/TaskB3.report" \
                   -- \
                   echo "Task B3 output."


# --- Subprojects, begin ---

declare -r SUBPROJECT_X_RESULTS_DIR="$SUBPROJECTS_PUBLIC_DIR/SubprojectXPublic"
declare -r SUBPROJECT_Y_RESULTS_DIR="$SUBPROJECTS_PUBLIC_DIR/SubprojectYPublic"
mkdir --parents -- "$SUBPROJECT_X_RESULTS_DIR"
mkdir --parents -- "$SUBPROJECT_Y_RESULTS_DIR"
echo "Subproject X report" >"$SUBPROJECT_X_RESULTS_DIR/SubprojectXReport.txt"
echo "Subproject Y report" >"$SUBPROJECT_Y_RESULTS_DIR/SubprojectYReport.txt"

# This extra file next to SubprojectXReport.txt will be copied along.
echo "Subproject X log file" >"$SUBPROJECT_X_RESULTS_DIR/SubprojectX-1-Log.txt"

echo "SubprojectX = $SUBPROJECT_X_RESULTS_DIR/SubprojectXReport.txt" >>"$SUBPROJECTS_FILENAME"
echo "SubprojectY = $SUBPROJECT_Y_RESULTS_DIR/SubprojectYReport.txt" >>"$SUBPROJECTS_FILENAME"

./RunAndReport.sh  --id=SubprojectX \
                   --userFriendlyName="Subproject X" \
                   --logFilename="$LOGS_DIR/SubprojectX-Log.txt" \
                   --reportFilename="$INTERNAL_REPORTS_DIR/SubprojectX.report" \
                   -- \
                   echo "Subproject X output."

./RunAndReport.sh  --id=SubprojectY \
                   --userFriendlyName="Subproject Y" \
                   --logFilename="$LOGS_DIR/SubprojectY-Log.txt" \
                   --reportFilename="$INTERNAL_REPORTS_DIR/SubprojectY.report" \
                   -- \
                   echo "Subproject Y output."

# --- Subprojects, end ---

echo

./GenerateHtmlReport.pl --topLevelReportFilename "$INTERNAL_REPORTS_DIR/TopLevel.report" \
                        --taskGroupsList "$GROUPS_FILENAME" \
                        --subprojectsList "$SUBPROJECTS_FILENAME" \
                        --title "My Title" \
                        --description "My description." \
                        --generateTarball \
                        --htmlLogs \
                        --failedCountFilename "$INTERNAL_REPORTS_DIR/FailedCount.txt" \
                        -- \
                        "$INTERNAL_REPORTS_DIR" \
                        "$PUBLIC_REPORTS_BASE_DIR" \
                        "$PUBLIC_LOG_FILES_SUBDIR" \
                        "$REPORT_FILENAME"

# Optionally lint the generated HTML.
if false; then
  echo "Running HTML tidy on the generated HTML report..."
  tidy --gnu-emacs yes  -quiet -output /dev/null "$PUBLIC_REPORTS_BASE_DIR/$REPORT_FILENAME"
fi


# Open the generated HTML with a web browser.

declare -r REPORT_URL="file://$PUBLIC_REPORTS_BASE_DIR/$REPORT_FILENAME"

if true; then
 xdg-open  "$REPORT_URL"  </dev/null  >/dev/null 2>&1  &
 disown

  # Without this pause, the child process is getting killed on my system.
  sleep 0.5
fi

if false; then
  firefox -no-remote "$REPORT_URL"  </dev/null  >/dev/null 2>&1  &
  disown
fi


echo "Finished. The HTML report filename is: $REPORT_FILENAME"
