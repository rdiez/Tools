#!/bin/bash

# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3
#
# These are pieces of Bash code that I may need again in the future.


verify_var_not_empty ()
{
  # $1 = variable name

  verify_var_is_set "$1"

  if [ -z "${!1}" ]
  then
    abort "Variable \"$1\" is set but empty."
  fi

  # Alternative if the bash-specific syntax ${!VARNAME} is not available.
  #
  # local VAR_NAME
  # local VAR_VALUE
  # local OLD_OPTIONS  # We want to save option 'nounset'.
  #
  # VAR_NAME=$1
  # VAR_VALUE=""
  #
  # OLD_OPTIONS=$(set +o | grep "nounset")  # The Alternative without grep [ $(set +o) ] does not work when restoring the option.
  # set +o nounset
  #
  # eval VAR_VALUE=\$$VAR_NAME
  #
  # eval $OLD_OPTIONS
  #
  # if [ -z $VAR_VALUE ]; then abort "Variable \"$VAR_NAME\" not defined or has an empty value."; fi
}


upload_file_via_ftp ()
{
  # $1 = local filename
  # $2 = remote hostname
  # $3 = remote filename
  # $4 = user    , or "" for none
  # $5 = password, or "" for none
  # $6 = Remote file access rights in octal. Typical values are:
  #      -rw-r--r--  644
  #      -rwxr-xr-x  755

  local LOCAL_FILENAME="$1"
  local REMOTE_HOSTNAME="$2"
  local REMOTE_FILENAME="$3"
  local USER="$4"
  local PASSWORD="$5"
  local REMOTE_MASK="$6"

  local USER_PASSWORD

  if [ "$USER" != "" ] || [ "$PASSWORD" != "" ]
  then
    USER_PASSWORD="-u $USER,$PASSWORD"
  else
    USER_PASSWORD=""
  fi


  # The following works, but it cannot set the file access rights.
  #   curl --silent --show-error --ftp-pasv --ftp-method nocwd $USER_PASSWORD --upload-file $1 --url $2

  lftp -c "set cmd:fail-exit 1; open -e \"put $LOCAL_FILENAME -o $REMOTE_FILENAME; chmod $REMOTE_MASK $REMOTE_FILENAME\" $USER_PASSWORD $REMOTE_HOSTNAME" >/dev/null
}


run_command_on_server_over_telnet ()
{
  # $1 = remote hostname
  # $2 = command to run
  #
  # This example:
  #
  #   run_command_on_server_over_telnet  remotehost  "echo \"Value of \\\$TERM: \$TERM\""
  #
  # outputs the following (surrounded by other output):
  #
  #   Value of $TERM: cygwin
  #
  # WARNING: This script does not properly escape the special characters that expect/tk uses.
  #

  local REMOTE_HOSTNAME="$1"
  local REMOTE_COMMAND="$2"

  # Instead of the standard shell quoting here, we should probably do escaping specific for Tk or 'expect',
  # but the current implementation is apparently enough for most scenarios. One exception that causes problems
  # is the exclamation mark ('!'), but there may be others.
  printf -v REMOTE_COMMAND '%q' "$REMOTE_COMMAND"

  local EXPECT_MARKER_LEFT="++++ expect"
  local EXPECT_MARKER_SUCCESS="success"
  local EXPECT_MARKER_FAILURE="failure"
  local EXPECT_MARKER_RIGHT="maker ++++"

  expect -c "

    # To enable expect tracing:
    #   exp_internal 1

    proc kill_telnet {} {
        global TELNET_PID

        exec kill \$TELNET_PID
    }

    proc on_time_out {} {
        global TELNET_PID

        send_user \"\\nExpect error: timeout waiting for response from remote command.\\n\"
        exit 1
    }

    proc on_failed_command {} {
        global TELNET_PID

        send_user \"\\nExpect error: remote command failed.\\n\"
        exit 2
    }

    proc run_commands {} {

        expect timeout on_time_out \"Welcome to the whatever here\"
        expect timeout on_time_out \"\$ \"

        # This alternative places the command in a single line.
        # The drawback is that the shell output gets mixed with the input.
        #   send \"$REMOTE_COMMAND\\n\"
        #   send \"EXPECT_EXIT_CODE=\$? && echo -n \\\"$EXPECT_MARKER_LEFT \\\" && if \\[ \\\$EXPECT_EXIT_CODE -eq 0 \\]; then echo -n \\\"$EXPECT_MARKER_SUCCESS\\\"; else echo -n \\\"$EXPECT_MARKER_FAILURE\\\"; fi && echo \\\" $EXPECT_MARKER_RIGHT\\\"\\n\"

        send \"($REMOTE_COMMAND); \"

        send \"EXPECT_EXIT_CODE=\$? && echo -n \\\"$EXPECT_MARKER_LEFT \\\" && if \\[ \\\$EXPECT_EXIT_CODE -eq 0 \\]; then echo -n \\\"$EXPECT_MARKER_SUCCESS\\\"; else echo -n \\\"$EXPECT_MARKER_FAILURE\\\"; fi && echo \\\" $EXPECT_MARKER_RIGHT\\\"\\n\"

        expect timeout on_time_out \"$EXPECT_MARKER_LEFT $EXPECT_MARKER_SUCCESS $EXPECT_MARKER_RIGHT\" {} \"$EXPECT_MARKER_LEFT $EXPECT_MARKER_FAILURE $EXPECT_MARKER_RIGHT\" on_failed_command

        # We are slower under Cygwin, and the prompt always shows up. This does not happen under Linux.
        # This code waits for the prompt, in order to have a consistent behaviour.
        expect timeout on_time_out \"\$ \"
        send_user \"\\n\"

        # Under Ubuntu 9.04, there is a pause of around 2 seconds. I have tried with 'send exit' instead of kill_telnet,
        # but the pause is still there when the expect script terminates.
        # There is no pause under Cygwin.

        exit 0
    }


    set timeout 5

    spawn telnet -l root $REMOTE_HOSTNAME
    set TELNET_PID [ exp_pid -i \$spawn_id ]
    exit -onexit kill_telnet

    # If telnet starts but the connection to the remote host fails,
    # this is the only way to handle the error properly I know of,
    # so that this script yields a non-zero exit code.
    # The error message ('invalid spawn id') is of low quality,
    # but unfortunately I do not know how to get a better one.
    # If we do not handle the error here, the error message does show up,
    # but the exit code is zero. That is probably a shortcoming in 'expect'.

    if {[catch {run_commands} err_msg]} {
      puts stderr \"\\nExpect error: \$err_msg\\n\"
      exit 3
    }
  "

  # EXPECT_EXIT_CODE=$?
  # echo "Expect exit code: $EXPECT_EXIT_CODE"
}


set_to_boolean_and ()
{
  local VAR_NAME="$1"

  shift

  local RESULT=true
  local ARG

  for ARG in "$@"
  do

    if [[ $ARG = "false" ]]; then
      RESULT=false
      break
    fi

    if [[ $ARG != "true" ]]; then
      abort "Argument \"$ARG\" is neither 'true' nor 'false'.";
    fi

  done

  printf -v "$VAR_NAME" '%s' "$RESULT"
}

set_to_boolean_or ()
{
  local VAR_NAME="$1"

  shift

  local RESULT=false
  local ARG

  for ARG in "$@"
  do

    if [[ $ARG = "true" ]]; then
      RESULT=true
      break
    fi

    if [[ $ARG != "false" ]]; then
      abort "Argument \"$ARG\" is neither 'true' nor 'false'.";
    fi

  done

  printf -v "$VAR_NAME" '%s' "$RESULT"
}
