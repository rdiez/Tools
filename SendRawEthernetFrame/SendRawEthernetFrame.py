#!/usr/bin/env python

# Use this script on a Linux system to send raw Ethernet frames over a network interface.
#
# You will probably need to run this script with 'sudo', or you will get the following error message:
#
#   socket.error: [Errno 1] Operation not permitted
#
# About hardware offloading:
#
#   It is increasingly difficult to find a network card with a corresponding Linux driver that allows turning off
#   the automatic setting or appending of the IP header, TCP, etc. checksums and of the Ethernet Frame CRC-32.
#
#   The first thing you can try is:
#
#     ethtool --show-offload eth0
#
#   Among other information, you will see something like this:
#
#     tx-checksumming: off
#     tx-checksum-ipv4: off
#     tx-checksum-ip-generic: off [fixed]
#     tx-checksum-ipv6: off
#     tx-checksum-fcoe-crc: off [fixed]
#     tx-checksum-sctp: off [fixed]
#
#   'fcoe' above probably means "Fibre Channel over Ethernet" (FCoE), which you probably are not using.
#
#   Parameters that are not marked as [fixed] can be changed. To change all Tx checksumming at once:
#
#     sudo ethtool --offload eth0 tx off
#
#   The next thing to try are driver parameters. Issue this command to find out the driver name:
#
#     ethtool -i eth0
#
#   And then list all available parameters (if any) like this:
#
#     modinfo 3c59x
#
#   The 3c59x driver reports among others this one:
#
#     parm:  hw_checksums:3c59x Hardware checksum checking by adapter(s) (0-1) (array of int)
#
#   Also look for parameters named "crc" or "fcs" (for Frame Check Sequence).
#
#   With the example above, you can do the following:
#
#     sudo rmmod 3c59x && sudo modprobe 3c59x hw_checksums=0
#
#   Look for CaptureSetup/Offloading in the Wireshark documentation for more details about hardware offloading.
#
#
# Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3


from socket import *

interface_name = "eth0"

s = socket( AF_PACKET, SOCK_RAW )

# With some network cards, this might prevent the CRC-32 from being appended:
#   s.setsockopt( SOL_SOCKET, SO_NOFCS, 1 )

s.bind( ( interface_name, 0 ) )


src_mac_addr = "\x01\x02\x03\x04\x05\x06"
dst_mac_addr = "\x01\x02\x03\x04\x05\x06"  # For broadcasting, use "\xff\xff\xff\xff\xff\xff".

ethertype = "\x08\x01"

payload = "P" * 100

# Manually adding the CRC-32 will probably not work, see the comment above about hardware offloading.
# Otherwise, use a value like this:  "\x01\x02\x03\x04"
crc32 = ""

s.send( dst_mac_addr + src_mac_addr + ethertype + payload + crc32 )
