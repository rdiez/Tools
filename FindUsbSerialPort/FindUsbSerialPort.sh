#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r VERSION_NUMBER="1.03"
declare -r SCRIPT_NAME="FindUsbSerialPort.sh"

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1

declare -r SYS_BUS_USB_DEVICES_PATH="/sys/bus/usb/devices"
declare -r DEV_PATH_PREFIX="/dev/"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2014-2017 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script finds the device file associated to a USB virtual serial port. You can search
for any combination of Vendor ID, Product ID, Serial Number, etc.

Typically, such device filenames look like /dev/ttyACM0 or /dev/ttyUSB0. This tool comes in
handy because such filenames are unpredictable, so your USB device may get a
different one depending on how many other USB virtual serial ports happen to be
connected to your system.

On success, only the device path is printed, so that this script's output can be easily
captured from another script.

There is a '--list' option that, instead of searching for a particular port, prints a list
of all detected USB virtual serial ports that match the given criteria.

As an alternative to using this script, you can write a UDEV rules file that assigns
a fixed filename to your USB device. But writing rules files is inconvenient and requires system
changes (root access) to each PC you want to connect your USB device to.

You can also open serial ports with a filename under /dev/serial/by-id, which is independent
of the USB port the device is connected to. The trouble is, those filenames include the device's serial number,
which may be inconvenient when shipping generic software for any user, or if you swap a device
for another identical one, but with a different serial number. There is also /dev/serial/by-path ,
which lets you open the serial port by its USB port location, but then you have to remember every time
which port you should connect the device to.

Note that this script's current implementation looks inside /sys/bus/usb/devices , so it only works under Linux.
I must admit that I have not looked at all the Linux USB documentation in detail, so I am not sure if it works
for all possible USB serial port types. So far it seems to work well with drivers cdc_acm (for the standard
USB Communications Device Class) and ftdi_sio (for chips manufactured by FTDI).

Syntax:
  $SCRIPT_NAME <options...>

Options:
 --vendor-id=<xxx>     the Vendor ID to look for
 --product-id=<xxx>    the Product ID to look for
 --serial-number=<xxx> the Serial Number to look for
 --manufacturer=<xxx>  the Manufacturer to look for
 --product=<xxx>       the Product name to look for
 --list     prints all discovered ports which match the search criteria
 --help     displays this help text
 --version  displays the tool's version number (currently $VERSION_NUMBER)
 --license  prints license information

Usage example 1, as you would manually type it:
  ./FindUsbSerialPort.sh --vendor-id=2341 --product-id=1234

Usage example 2, where the search result is used by a script:
  % SERIAL_PORT="\$(./FindUsbSerialPort.sh --vendor-id=2341 --product-id=1234)"
  % echo "Connecting to serial port \"\$SERIAL_PORT\"..."
  % socat READLINE,echo=0 "\$SERIAL_PORT",b115200,raw,echo=0

Exit status: 0 means success. Any other value means error.

Race conditions whilst reading /sys/bus/usb/devices :

It is hard to read virtual files under /sys/bus/usb/devices in a robust manner,
because the user can unplug a USB device at any point in time, which can make
complete subdirectories suddenly disappear. This script tries to survive
unexpected read errors caused by such a scenario, but I haven't really tested
it thoroughly.

It is also theoretically possible, but extremely unlikely, that a USB device
disconnects and another one connects while this tool is reading the
device information at that particular USB port. In this case, the data read
will be a mix of old and new device information, and therefore inconsistent.

Possible improvements:
 - The user may wish to search using regular expressions, instead of fixed string values.
 - More search parameters could be added. For example, you could search for devices
   connected to a particular USB hub.

Alternative implementations:

Instead of walking the /sys/bus/usb/devices tree, this tool could look at /sys/class/tty
or /dev/serial/by-path and then call "udevadm info --query=path --name=/dev/ttyUSB0" or similar
to find out whether a given port is a USB virtual serial port.

Alternatives to /sys/bus/usb/devices are also /proc/bus/usb/devices for Linux kernels before 2.6.31,
if usbfs is mounted, and /sys/kernel/debug/usb/devices for Linux kernel 2.6.31 and later,
if debugfs is mounted, but that requires root privileges.

Under Linux, instead of writing a shell script, it would have been possible to write
a C program that uses libudev in order to get the device mappings programmatically.
However, I think libudev gets the information from sysfs too.

If you wish to contribute alternative implementations for platforms other than Linux,
please drop me a line.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

EOF
}


display_license()
{
cat - <<EOF

Copyright (c) 2014-2017 R. Diez

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License version 3 for more details.

You should have received a copy of the GNU Affero General Public License version 3
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

EOF
}


# --------------------------------------------------

add_to_comma_separated_list ()
{
  local NEW_ELEMENT="$1"
  local MSG_VAR_NAME="$2"

  if [[ ${!MSG_VAR_NAME} = "" ]]; then
    eval "$MSG_VAR_NAME+=\"$NEW_ELEMENT\""
  else
    eval "$MSG_VAR_NAME+=\", $NEW_ELEMENT\""
  fi
}


print_usb_device_entry ()
{
  local TTY_NAME="$1"
  local ENTRY_VENDOR_ID="$2"
  local ENTRY_PRODUCT_ID="$3"
  local ENTRY_SERIAL_NUMBER="$4"
  local MANUFACTURER="$5"
  local PRODUCT="$6"

  local MSG=""

  # I guess a Vendor ID is mandatory.
  if [[ $ENTRY_VENDOR_ID != "" ]]; then
    add_to_comma_separated_list "USB VID: $ENTRY_VENDOR_ID" MSG
  fi

  # I guess a Product ID is mandatory.
  if [[ $ENTRY_PRODUCT_ID != "" ]]; then
    add_to_comma_separated_list "USB PID: $ENTRY_PRODUCT_ID" MSG
  fi

  if [[ $ENTRY_SERIAL_NUMBER != "" ]]; then
    add_to_comma_separated_list "S/N: $ENTRY_SERIAL_NUMBER" MSG
  fi

  if [[ $MANUFACTURER != "" ]]; then
    add_to_comma_separated_list "Man: $MANUFACTURER" MSG
  fi

  if [[ $PRODUCT != "" ]]; then
    add_to_comma_separated_list "Prod: $PRODUCT" MSG
  fi

  if [[ $MSG = "" ]]; then
    # This will probably never happen.
    MSG="<no info available>"
  fi

  echo "$DEV_PATH_PREFIX$TTY_NAME : $MSG"
}


apply_search_criteria_to_usb_device_entry ()
{
  local TTY_NAME="$1"
  local ENTRY_VENDOR_ID="$2"
  local ENTRY_PRODUCT_ID="$3"
  local ENTRY_SERIAL_NUMBER="$4"
  local ENTRY_MANUFACTURER="$5"
  local ENTRY_PRODUCT="$6"
  # This is the return value, true or false.
  local FULFILLS_SEARCH_CRITERIA_VAR_NAME="$7"

  eval "$FULFILLS_SEARCH_CRITERIA_VAR_NAME=false"

  if [[ $SEARCHED_FOR_VENDOR_ID != "" ]]; then
    if [[ $SEARCHED_FOR_VENDOR_ID != "$ENTRY_VENDOR_ID" ]]; then
      return 0
    fi
  fi

  if [[ $SEARCHED_FOR_PRODUCT_ID != "" ]]; then
    if [[ $SEARCHED_FOR_PRODUCT_ID != "$ENTRY_PRODUCT_ID" ]]; then
      return 0
    fi
  fi

  if [[ $SEARCHED_FOR_SERIAL_NUMBER != "" ]]; then
    if [[ $SEARCHED_FOR_SERIAL_NUMBER != "$ENTRY_SERIAL_NUMBER" ]]; then
      return 0
    fi
  fi

  if [[ $SEARCHED_FOR_MANUFACTURER != "" ]]; then
    if [[ $SEARCHED_FOR_MANUFACTURER != "$ENTRY_MANUFACTURER" ]]; then
      return 0
    fi
  fi

  if [[ $SEARCHED_FOR_PRODUCT != "" ]]; then
    if [[ $SEARCHED_FOR_PRODUCT != "$ENTRY_PRODUCT" ]]; then
      return 0
    fi
  fi

  eval "$FULFILLS_SEARCH_CRITERIA_VAR_NAME=true"
}


process_usb_device_entry ()
{
  # We could use an associative array for all possible search parameters.

  local TTY_NAME="$2"
  local SEARCH_RESULTS_VAR_NAME="$8"

  local FULFILLS_SEARCH_CRITERIA

  apply_search_criteria_to_usb_device_entry "$2" "$3" "$4" "$5" "$6" "$7" FULFILLS_SEARCH_CRITERIA

  if ! $FULFILLS_SEARCH_CRITERIA; then
    return 0
  fi

  # We need this array even if just listing all elements, in oder to print a "no ports found"
  # message at the end, if necessary.
  eval "$SEARCH_RESULTS_VAR_NAME+=(\"$TTY_NAME\")"

  case "$1" in
    list)   print_usb_device_entry "$2" "$3" "$4" "$5" "$6" "$7";;
    search) ;;
    *) abort "Internal error, wrong mode '$MODE'.";;
  esac
}


read_file_if_it_exists ()
{
  local FILENAME="$1"
  local RESULT_VAR_NAME="$2"

  if [ -e "$FILENAME" ]; then

    # The virtual files under /sys/bus/usb/devices can go away at any point in time, so do not abort this script
    # if we cannot read the file contents.
    set +o errexit
    {
      FILE_CONTENTS="$(<"$FILENAME")"
    } 2>/dev/null
    set -o errexit

    eval "$RESULT_VAR_NAME=\"$FILE_CONTENTS\""
  fi
}


get_params_for_associated_usb_device ()
{
  local USB_INTERFACE_NAME="$1"
  local VENDOR_ID_VAR_NAME="$2"
  local PRODUCT_ID_VAR_NAME="$3"
  local SERIAL_NUMBER_VAR_NAME="$4"
  local MANUFACTURER_VAR_NAME="$5"
  local PRODUCT_VAR_NAME="$6"
  local IS_OK_VAR_NAME="$7"

  eval "$VENDOR_ID_VAR_NAME="
  eval "$PRODUCT_ID_VAR_NAME="
  eval "$SERIAL_NUMBER_VAR_NAME="
  eval "$MANUFACTURER_VAR_NAME="
  eval "$PRODUCT_VAR_NAME="
  eval "$IS_OK_VAR_NAME=false"

  local REGEXP="([0-9]+-[0-9,\\.]+):[0-9,\\.]+"

  if ! [[ $USB_INTERFACE_NAME =~ $REGEXP ]]; then
    return 0
  fi

  local DEVICE_PART=${BASH_REMATCH[1]}

  pushd "$SYS_BUS_USB_DEVICES_PATH" >/dev/null

  if ! [ -d "$DEVICE_PART" ]; then
    echo "Warning: USB Device \"$DEVICE_PART\" not found. This script's logic is probably not quite right."
    return 0
  fi

  read_file_if_it_exists "$DEVICE_PART/idVendor"     "$VENDOR_ID_VAR_NAME"
  read_file_if_it_exists "$DEVICE_PART/idProduct"    "$PRODUCT_ID_VAR_NAME"
  read_file_if_it_exists "$DEVICE_PART/serial"       "$SERIAL_NUMBER_VAR_NAME"
  read_file_if_it_exists "$DEVICE_PART/manufacturer" "$MANUFACTURER_VAR_NAME"
  read_file_if_it_exists "$DEVICE_PART/product"      "$PRODUCT_VAR_NAME"

  popd >/dev/null

  eval "$IS_OK_VAR_NAME=true"
}


scan_usb_devices ()
{
  local MODE="$1"

  local AT_LEAST_ONE_USB_SERIAL_PORT_FOUND=false
  local -a SEARCH_RESULTS=()

  if ! [ -d "$SYS_BUS_USB_DEVICES_PATH" ]; then
    abort "Directory \"$SYS_BUS_USB_DEVICES_PATH\" does not exist. Note that this script only works on Linux at the moment."
  fi

  pushd "$SYS_BUS_USB_DEVICES_PATH" >/dev/null

  local SYS_ENTRY
  for SYS_ENTRY in *; do

    # Note that a USB device can be disconnected any time, so its directory entries
    # can suddenly disappear.
    if ! pushd "$SYS_ENTRY" >/dev/null 2>&1; then
     continue
    fi

    local ENTRY_VENDOR_ID ENTRY_PRODUCT_ID
    local ENTRY_SERIAL_NUMBER MANUFACTURER
    local PRODUCT

    # The ftdi_sio driver seems to create "ttyUSBnnn" entries.
    shopt -s nullglob
    local TTY_USB_ENTRY
    for TTY_USB_ENTRY in ttyUSB* ; do
      get_params_for_associated_usb_device "$SYS_ENTRY" ENTRY_VENDOR_ID ENTRY_PRODUCT_ID ENTRY_SERIAL_NUMBER MANUFACTURER PRODUCT IS_OK
      if $IS_OK; then
        AT_LEAST_ONE_USB_SERIAL_PORT_FOUND=true
        process_usb_device_entry "$MODE" "$TTY_USB_ENTRY" "$ENTRY_VENDOR_ID" "$ENTRY_PRODUCT_ID" "$ENTRY_SERIAL_NUMBER" "$MANUFACTURER" "$PRODUCT" SEARCH_RESULTS
      fi
    done

    # The cdc_acm driver seems to create a "tty" entry.
    TTY_SUBDIR="tty"

    if [ -d "$TTY_SUBDIR" ]; then

      get_params_for_associated_usb_device "$SYS_ENTRY" ENTRY_VENDOR_ID ENTRY_PRODUCT_ID ENTRY_SERIAL_NUMBER MANUFACTURER PRODUCT IS_OK

      if $IS_OK; then
        TTY_SUBDIR_PREFIX_LEN=$(( ${#TTY_SUBDIR} + 1 ))
        shopt -s nullglob
        local TTY_SUBDIR_ENTRY
        for TTY_SUBDIR_ENTRY in "$TTY_SUBDIR"/*; do
          AT_LEAST_ONE_USB_SERIAL_PORT_FOUND=true

          TTY_SUBDIR_ENTRY_WITHOUT_PREFIX="${TTY_SUBDIR_ENTRY:$TTY_SUBDIR_PREFIX_LEN}"

          process_usb_device_entry "$MODE" "$TTY_SUBDIR_ENTRY_WITHOUT_PREFIX" "$ENTRY_VENDOR_ID" "$ENTRY_PRODUCT_ID" "$ENTRY_SERIAL_NUMBER" "$MANUFACTURER" "$PRODUCT" SEARCH_RESULTS
        done
      fi
    fi

    popd >/dev/null  # This should never fail, because "$SYS_BUS_USB_DEVICES_PATH" should still exist.

  done

  local RESULT_PORT_COUNT=${#SEARCH_RESULTS[@]}

  case "$MODE" in
    list)
        if ! $AT_LEAST_ONE_USB_SERIAL_PORT_FOUND; then
          echo "No USB virtual serial ports found."
        elif [ "$RESULT_PORT_COUNT" -eq 0 ]; then
          echo "No USB virtual serial ports found which match the search parameters."
        fi
        ;;

    search)
        if ! $AT_LEAST_ONE_USB_SERIAL_PORT_FOUND; then
          abort "No USB virtual serial ports found."
        fi

        if [ "$RESULT_PORT_COUNT" -eq 0 ]; then
          abort "No USB virtual serial ports found which match the search parameters."
        fi

        if [ "$RESULT_PORT_COUNT" -gt 1 ]; then
          local JOINED
          JOINED="$(printf ", $DEV_PATH_PREFIX%s" "${SEARCH_RESULTS[@]}")"
          JOINED="${JOINED:2}"
          abort "The search parameters yield more than a single, unique match. The $RESULT_PORT_COUNT ports found are: $JOINED"
        fi

        echo "$DEV_PATH_PREFIX${SEARCH_RESULTS[0]}"
        ;;
  esac

  popd >/dev/null
}


process_command_line_argument ()
{
  case "$OPTION_NAME" in
    help)
        display_help
        exit $EXIT_CODE_SUCCESS
        ;;
    version)
        echo "$VERSION_NUMBER"
        exit $EXIT_CODE_SUCCESS
        ;;
    license)
        display_license
        exit $EXIT_CODE_SUCCESS
        ;;
    vendor-id)
        if [[ $OPTARG = "" ]]; then
          abort "The Vendor ID option has an empty value.";
        fi
        SEARCHED_FOR_VENDOR_ID="$OPTARG"
        SEARCH_REQUESTED=true
        ;;
    product-id)
        if [[ $OPTARG = "" ]]; then
          abort "The Product ID option has an empty value.";
        fi
        SEARCHED_FOR_PRODUCT_ID="$OPTARG"
        SEARCH_REQUESTED=true
        ;;
    serial-number)
        if [[ $OPTARG = "" ]]; then
          abort "The Serial Number option has an empty value.";
        fi
        SEARCHED_FOR_SERIAL_NUMBER="$OPTARG"
        SEARCH_REQUESTED=true
        ;;
    manufacturer)
        if [[ $OPTARG = "" ]]; then
          abort "The Manufacturer option has an empty value.";
        fi
        SEARCHED_FOR_MANUFACTURER="$OPTARG"
        SEARCH_REQUESTED=true
        ;;
    product)
        if [[ $OPTARG = "" ]]; then
          abort "The Product name option has an empty value.";
        fi
        SEARCHED_FOR_PRODUCT="$OPTARG"
        SEARCH_REQUESTED=true
        ;;
    list)
        LIST_REQUESTED=true
        ;;
    *)  # We should actually never land here, because parse_command_line_arguments() already checks if an option is known.
        abort "Unknown command-line option \"--${OPTION_NAME}\".";;
  esac
}


parse_command_line_arguments ()
{
  # The way command-line arguments are parsed below was originally described on the following page:
  #   http://mywiki.wooledge.org/ComplexOptionParsing
  # But over the years I have rewritten or amended most of the code myself.

  if false; then
    echo "USER_SHORT_OPTIONS_SPEC: $USER_SHORT_OPTIONS_SPEC"
    echo "Contents of USER_LONG_OPTIONS_SPEC:"
    for key in "${!USER_LONG_OPTIONS_SPEC[@]}"; do
      printf -- "- %s=%s\\n" "$key" "${USER_LONG_OPTIONS_SPEC[$key]}"
    done
  fi

  # The first colon (':') means "use silent error reporting".
  # The "-:" means an option can start with '-', which helps parse long options which start with "--".
  local MY_OPT_SPEC=":-:$USER_SHORT_OPTIONS_SPEC"

  local OPTION_NAME
  local OPT_ARG_COUNT
  local OPTARG  # This is a standard variable in Bash. Make it local just in case.
  local OPTARG_AS_ARRAY

  while getopts "$MY_OPT_SPEC" OPTION_NAME; do

    case "$OPTION_NAME" in

      -) # This case triggers for options beginning with a double hyphen ('--').
         # If the user specified "--longOpt"   , OPTARG is then "longOpt".
         # If the user specified "--longOpt=xx", OPTARG is then "longOpt=xx".

         if [[ "$OPTARG" =~ .*=.* ]]  # With this --key=value format, only one argument is possible.
         then

           OPTION_NAME=${OPTARG/=*/}
           OPTARG=${OPTARG#*=}
           OPTARG_AS_ARRAY=("")

           if ! test "${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]+string_returned_if_exists}"; then
             abort "Unknown command-line option \"--$OPTION_NAME\"."
           fi

           # Retrieve the number of arguments for this option.
           OPT_ARG_COUNT=${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]}

           if (( OPT_ARG_COUNT != 1 )); then
             abort "Command-line option \"--$OPTION_NAME\" does not take 1 argument."
           fi

           process_command_line_argument

         else  # With this format, multiple arguments are possible, like in "--key value1 value2".

           OPTION_NAME="$OPTARG"

           if ! test "${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]+string_returned_if_exists}"; then
             abort "Unknown command-line option \"--$OPTION_NAME\"."
           fi

           # Retrieve the number of arguments for this option.
           OPT_ARG_COUNT=${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]}

           if (( OPT_ARG_COUNT == 0 )); then
             OPTARG=""
             OPTARG_AS_ARRAY=("")
             process_command_line_argument
           elif (( OPT_ARG_COUNT == 1 )); then
             OPTARG="${!OPTIND}"
             OPTARG_AS_ARRAY=("")
             process_command_line_argument
           else
             OPTARG=""
             # OPTARG_AS_ARRAY is not standard in Bash. I have introduced it to make it clear that
             # arguments are passed as an array in this case. It also prevents many Shellcheck warnings.
             OPTARG_AS_ARRAY=("${@:OPTIND:OPT_ARG_COUNT}")

             if [ ${#OPTARG_AS_ARRAY[@]} -ne "$OPT_ARG_COUNT" ]; then
               abort "Command-line option \"--$OPTION_NAME\" needs $OPT_ARG_COUNT arguments."
             fi

             process_command_line_argument
           fi;

           ((OPTIND+=OPT_ARG_COUNT))
         fi
         ;;

      *) # This processes only single-letter options.
         # getopts knows all valid single-letter command-line options, see USER_SHORT_OPTIONS_SPEC above.
         # If it encounters an unknown one, it returns an option name of '?'.
         if [[ "$OPTION_NAME" = "?" ]]; then
           abort "Unknown command-line option \"$OPTARG\"."
         else
           # Process a valid single-letter option.
           OPTARG_AS_ARRAY=("")
           process_command_line_argument
         fi
         ;;
    esac
  done

  shift $((OPTIND-1))
  ARGS=("$@")
}


# --------------------------------------------------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [list]=0 )
USER_LONG_OPTIONS_SPEC+=( [vendor-id]=1 )
USER_LONG_OPTIONS_SPEC+=( [product-id]=1 )
USER_LONG_OPTIONS_SPEC+=( [serial-number]=1 )
USER_LONG_OPTIONS_SPEC+=( [manufacturer]=1 )
USER_LONG_OPTIONS_SPEC+=( [product]=1 )

SEARCHED_FOR_VENDOR_ID=""
SEARCHED_FOR_PRODUCT_ID=""
SEARCHED_FOR_SERIAL_NUMBER=""
SEARCHED_FOR_MANUFACTURER=""
SEARCHED_FOR_PRODUCT=""
LIST_REQUESTED=false
SEARCH_REQUESTED=false

parse_command_line_arguments "$@"

if false; then
  echo ARGS:
  printf -- '- %s\n' "${ARGS[@]}"
fi

if [ ${#ARGS[@]} -ne 0 ]; then
  abort "Too many command-line arguments. Run this tool with the --help option for usage information."
fi


if $LIST_REQUESTED; then
  scan_usb_devices list
else
  if ! $SEARCH_REQUESTED; then
    abort "No search options specified. Run this tool with the --help option for usage information."
  fi

  scan_usb_devices search
fi
