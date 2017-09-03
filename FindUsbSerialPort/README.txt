
FindUsbSerialPort.sh version 1.02
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
  FindUsbSerialPort.sh <options...>

Options:
 --vendor-id=<xxx>     the Vendor ID to look for
 --product-id=<xxx>    the Product ID to look for
 --serial-number=<xxx> the Serial Number to look for
 --manufacturer=<xxx>  the Manufacturer to look for
 --product=<xxx>       the Product name to look for
 --list     prints all discovered ports which match the search criteria
 --help     displays this help text
 --version  displays the tool's version number (currently 1.02)
 --license  prints license information

Usage example 1, as you would manually type it:
  ./FindUsbSerialPort.sh --vendor-id=2341 --product-id=1234

Usage example 2, where the search result is used by a script:
  % SERIAL_PORT="$(./FindUsbSerialPort.sh --vendor-id=2341 --product-id=1234)"
  % echo "Connecting to serial port \"$SERIAL_PORT\"..."
  % socat READLINE,echo=0 "$SERIAL_PORT",b115200,raw,echo=0

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

