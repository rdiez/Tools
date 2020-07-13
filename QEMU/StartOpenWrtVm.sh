#!/bin/bash

# This is a script I have used for a while in order to start a KVM virtual machine
# with Linux and OpenWrt images.
#
# I am no longer using it, but I wanted to keep it because it has code and information
# about using QEMU that I may need again in the future.

# Copyright (c) 2019-2020 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r -i EXIT_CODE_ERROR=1

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


quote_and_append_args ()
{
  local -n VAR="$1"
  shift

  local STR

  # Shell-quote all arguments before joining them into a single string.
  printf -v STR  "%q "  "$@"

  # Remove the last character, which is one space too much.
  STR="${STR::-1}"

  if [ -z "$VAR" ]; then
    VAR="$STR"
  else
    VAR+="  $STR"
  fi
}


str_ends_with ()
{
  # $1 = string
  # $2 = suffix

  # From the bash manual, "Compound Commands" section, "[[ expression ]]" subsection:
  #   "Any part of the pattern may be quoted to force the quoted portion to be matched as a string."
  # Also, from the "Pattern Matching" section:
  #   "The special pattern characters must be quoted if they are to be matched literally."

  if [[ $1 == *"$2" ]]; then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


find_where_this_script_is ()
{
  # In this routine, command 'local' is often in a separate line, in order to prevent
  # masking any error from the external command inkoved.

  if ! is_var_set BASH_SOURCE; then
    # This happens when feeding the script to bash over an stdin redirection.
    abort "Cannot find out in which directory this script resides: built-in variable BASH_SOURCE is not set."
  fi

  local SOURCE="${BASH_SOURCE[0]}"

  local TRACE=false

  while [ -h "$SOURCE" ]; do  # Resolve $SOURCE until the file is no longer a symlink.
    TARGET="$(readlink --verbose -- "$SOURCE")"
    if [[ $SOURCE == /* ]]; then
      if $TRACE; then
        echo "SOURCE '$SOURCE' is an absolute symlink to '$TARGET'"
      fi
      SOURCE="$TARGET"
    else
      local DIR1
      DIR1="$( dirname "$SOURCE" )"
      if $TRACE; then
        echo "SOURCE '$SOURCE' is a relative symlink to '$TARGET' (relative to '$DIR1')"
      fi
      SOURCE="$DIR1/$TARGET"  # If $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located.
    fi
  done

  if $TRACE; then
    echo "SOURCE is '$SOURCE'"
  fi

  local DIR2
  DIR2="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

  if $TRACE; then
    local RDIR
    RDIR="$( dirname "$SOURCE" )"
    if [ "$DIR2" != "$RDIR" ]; then
      echo "DIR2 '$RDIR' resolves to '$DIR2'"
    fi
  fi

  DIR_WHERE_THIS_SCRIPT_IS="$DIR2"
}


start_vm ()
{
  local CMD=""

  local -r IMAGE="Gluon"

  local -r IMAGE_UPPERCASE=${IMAGE^^}

  case "$IMAGE_UPPERCASE" in

    LINUX) local -r IS_LINUX_GUEST=true
           local -r VM_NAME="Linux"
           local -r CONSOLE_TITLE="Linux VM"
           local -r IMAGE_TO_RUN="$HOME/rdiez/temp/Linux/ubuntu-mate-18.04.3-desktop-amd64.iso"
           local -r MODIFY_IMAGE=false
           ;;

    OPENWRT) local -r IS_LINUX_GUEST=false
             local -r VM_NAME="OpenWrt"
             local -r CONSOLE_TITLE="OpenWrt VM"

             # OpenWrt release:
             local -r IMAGE_TO_RUN="$HOME/rdiez/Freifunk/OpenWrt/OpenWrtBinaries/OfficialReleases/openwrt-19.07.2-x86-64-combined-ext4.img"

             local -r MODIFY_IMAGE=false
             ;;

    GLUON) local -r IS_LINUX_GUEST=false
           local -r VM_NAME="Gluon"
           local -r CONSOLE_TITLE="Gluon VM"

           local -r IMAGE_TO_RUN="$UNPACKED_IMAGES_DIR/gluon-ffnet-lgf-203001010101-rdiez-test-x86-64.img"

           local -r MODIFY_IMAGE=true
           ;;

     *) abort "Unknown image '$IMAGE'.";;
  esac


  # Automatically unpack .gz images, because it is very common that images are compressed.
  # WARNING: The unpacked filename is based on the image name, therefore:
  #          - Running the same image again concurrently will overwrite the first image file.
  #          - Images with the same name but from different directories will overwrite each other.
  #          - Unpacked images will accumulate over time, so you will have to manually clean up
  #            every now and then.
  # We could unpack the image every time into a temporary file, but then we would have
  # to delete them at the end, and that cannot actually be done reliably.
  # Another alternative would be to lock the unpacked file (assuming that the underlying filesystem supports it).

  if str_ends_with "$IMAGE_TO_RUN" ".gz"; then

    if $MODIFY_IMAGE; then
      abort "Cannot modify an image that is compressed with gzip."
    fi

    mkdir --parents -- "$UNPACKED_IMAGES_DIR"

    local -r IMAGE_NAME_ONLY="${IMAGE_TO_RUN##*/}"

    local -r IMAGE_NAME_ONLY_WITHOUT_GZ="${IMAGE_NAME_ONLY::-3}"

    local -r UNPACKED_IMAGE_TO_RUN="$UNPACKED_IMAGES_DIR/$IMAGE_NAME_ONLY_WITHOUT_GZ"

    local GUNZIP_CMD
    printf -v GUNZIP_CMD \
           "gunzip --to-stdout -- %q >%q" \
           "$IMAGE_TO_RUN" \
           "$UNPACKED_IMAGE_TO_RUN"

    echo "Unpacking image..."
    echo "$GUNZIP_CMD"
    eval "$GUNZIP_CMD"
    echo

  else
    local -r UNPACKED_IMAGE_TO_RUN="$IMAGE_TO_RUN"
  fi


  CMD+="qemu-system-x86_64"

  # pc : Works best with older versions of Windows.
  # q35: Works best with Linux.
  CMD+=" -machine q35"

  if $IS_LINUX_GUEST; then

    # With 1 GiB of RAM, a Ubuntu MATE 18.04 guest runs very slowly.
    CMD+=" -m size=1536M"

    # The QEMU version that comes with Ubuntu MATE 18.04.3 has no '-display gdk' support.
    CMD+=" -display sdl"

  else

    # OpenWrt does not need so much RAM.
    CMD+=" -m size=128M"
    CMD+=" -nographic"

  fi

  if ! $MODIFY_IMAGE; then

    # Option -snapshot writes any changes to disk to temporary files. As a result, the image file is not modified.
    # Note that the user can still modify the image with Qemu console command "Ctrl-a s".
    # If we want to modify the image, we should probably save a copy beforehand, or maybe save
    # the modifications to some sort of overlay (if supported at all).
    # The OpenWrt documentation states that saving modifications to the image file is not supported
    # when emulating the ARM architecture, but I am not sure about that, because I did not find such
    # limitations in the Qemu documentation.
    CMD+=" -snapshot"
  fi

  local TMP


  if str_ends_with "$UNPACKED_IMAGE_TO_RUN" ".iso"; then
    MEDIA_CDROM_ARG="media=cdrom,"
  else
    MEDIA_CDROM_ARG=""
  fi

  printf -v TMP " -drive ${MEDIA_CDROM_ARG}file=%q"  "$UNPACKED_IMAGE_TO_RUN"
  CMD+=" $TMP"

  printf -v TMP " -name %q"  "$VM_NAME"
  CMD+=" $TMP"


  # About PCI addresses:
  #   I could not find documentation about the PCI addresses that QEMU uses.
  #   I looked around in "-machine q35", and the automatically-assigned PCI address
  #   for virtio-net-pci network cards are:
  #   $ ls -la /sys/class/net
  #     eth0 -> ../../devices/pci0000:00/0000:00:02.0/virtio0/net/eth0
  #     eth1 -> ../../devices/pci0000:00/0000:00:03.0/virtio1/net/eth1
  #     eth2 -> ../../devices/pci0000:00/0000:00:04.0/virtio2/net/eth2
  # Somebody said that PCI address 2 is always assigned to the graphics card,
  # but I have not confirmed that yet.
  # I am using a higher starting number just in case.
  # The PCI address probably determines the ethX number.
  declare -i -r FIRST_PCI_ADDR=6

  if false; then
    CMD+=" -net none"
  else

    # About virtual network cards:
    #
    # Some guides mention an older QEMU argument syntax which uses a "vlan=n" option, but such syntax generates
    # a deprecation warning in recent QEMU versions.
    #
    # Use "ip addr" or "ifconfig", and "brctl show" inside the VM to display network interfaces and bridges.
    #
    # When setting up a user-mode networking port forward like "hostfwd=tcp::60080-192.168.1.1:80", you can
    # allegedly omit the guest IP address (192.168.1.1), but then the port forwarding does not work well,
    # only the first packets seem to get through, at least with QEMU version 2.11.1(Debian 1:2.11+dfsg-1ubuntu7.23).
    #
    # The TCP forwarding only works if the net=xxx address range matches the IP that OpenWrt uses.
    # That IP can be fixed (static), like it usually is for first LAN interface (eth0), or retrieved over DHCP,
    # like it usually is for the WAN interface (eth1).
    #
    # Use a URL like this on the host to connect using the TCP forward:  http://localhost:60080
    # For SSH port forward, use a command like this on the host:  ssh  -p 60022  -o StrictHostKeyChecking=no  root@localhost

    local PORT_FORWARDS
    local GUEST_LAN_IP


    # Create virtual network card eth0 in the VM.
    #
    # In the case of OpenWrt:
    # - OpenWrt creates a bridge named "br-lan" and adds eth0 as a member. This becomes the router's LAN.
    #
    # - OpenWrt assigns a fixed IP address to this network card (actually to the br-lan bridge), that is, it does not use DHCP.
    #   It is normally 192.168.1.1 .
    #
    # In the case of Gluon/Neanderfunk:
    #
    # - The initial IP address, when in configuration mode, is 192.168.1.1, just like in OpenWrt.
    #   There is a bridge named 'br-setup' with IP address 192.168.1.1 and eth0 as its only member:
    #
    #   1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    #       link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    #       inet 127.0.0.1/8 scope host lo
    #          valid_lft forever preferred_lft forever
    #       inet6 ::1/128 scope host
    #          valid_lft forever preferred_lft forever
    #   2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master br-setup state UP qlen 1000
    #       link/ether 52:54:00:12:34:56 brd ff:ff:ff:ff:ff:ff
    #   3: eth1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN qlen 1000
    #       link/ether 52:54:00:12:34:57 brd ff:ff:ff:ff:ff:ff
    #   4: dummy0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN qlen 1000
    #       link/ether 16:a6:c7:08:07:87 brd ff:ff:ff:ff:ff:ff
    #   5: teql0: <NOARP> mtu 1500 qdisc noop state DOWN qlen 100
    #       link/void
    #   6: br-setup: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP qlen 1000
    #       link/ether 52:54:00:12:34:56 brd ff:ff:ff:ff:ff:ff
    #       inet 192.168.1.1/24 brd 192.168.1.255 scope global br-setup
    #          valid_lft forever preferred_lft forever
    #       inet6 fe80::5054:ff:fe12:3456/64 scope link
    #          valid_lft forever preferred_lft forever
    #
    #   This network setup changes after the user has configured the system, normally through the web interface.
    #
    # - After configuration, things look differently.
    #
    #   - Gluon [latest] creates a bridge named 'br-client' with the following members:
    #     - eth0
    #     - local-port
    #     - bat0
    #     The bridge itself has no IPv4 address, so eth0 has no IPv4 address.
    #     The IPv6 address is 2a03:2260:300e:1a00:5054:ff:fe12:3456.
    #     The 64-bit prefix,  2a03:2260:300e:1a00, comes from the site configuration, see 'prefix6'.
    #     I do not know yet where the suffix comes from.
    #
    #   - Gluon [latest official Neanderfunk] does not add eth0 to 'br-client', only local-port and bat0 are in this bridge.
    #     But note that newer Gluon versions do that (at least when the VPN is not connected yet).
    #
    #   - Bridge 'br-wan' has as sole member interface eth1.
    #
    #   - local-node@local-port, which seems some kind of virtual interface, becomes its IPv4 address
    #     from the site configuration, see SITE_PREFIXES_4.
    #     For Langenfeld, the configuration says 10.1.240.0/21, and the IP address is then 10.1.240.255 .
    #     The broadcast address is then                                                    10.1.247.255 .
    #
    #   1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    #       link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    #       inet 127.0.0.1/8 scope host lo
    #          valid_lft forever preferred_lft forever
    #       inet6 ::1/128 scope host
    #          valid_lft forever preferred_lft forever
    #   2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master br-client state UP qlen 1000
    #       link/ether 52:54:00:12:34:56 brd ff:ff:ff:ff:ff:ff
    #   3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master br-wan state UP qlen 1000
    #       link/ether 52:54:00:12:34:57 brd ff:ff:ff:ff:ff:ff
    #   4: dummy0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN qlen 1000
    #       link/ether ce:4f:14:57:44:02 brd ff:ff:ff:ff:ff:ff
    #   5: teql0: <NOARP> mtu 1500 qdisc noop state DOWN qlen 100
    #       link/void
    #   6: br-client: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP qlen 1000
    #       link/ether 52:54:00:12:34:56 brd ff:ff:ff:ff:ff:ff
    #       inet6 2a03:2260:300e:1a00:5054:ff:fe12:3456/64 scope global dynamic
    #          valid_lft 86309sec preferred_lft 14309sec
    #       inet6 fe80::5054:ff:fe12:3456/64 scope link
    #          valid_lft forever preferred_lft forever
    #   7: br-wan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP qlen 1000
    #       link/ether da:2d:59:c4:41:28 brd ff:ff:ff:ff:ff:ff
    #       inet 10.0.3.15/24 brd 10.0.3.255 scope global br-wan
    #          valid_lft forever preferred_lft forever
    #       inet6 fe80::d82d:59ff:fec4:4128/64 scope link
    #          valid_lft forever preferred_lft forever
    #   8: local-port@local-node: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UP qlen 1000
    #       link/ether 52:54:00:12:34:56 brd ff:ff:ff:ff:ff:ff
    #   9: local-node@local-port: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP qlen 1000
    #       link/ether 16:41:95:40:f7:dc brd ff:ff:ff:ff:ff:ff
    #       inet 10.1.240.255/21 brd 10.1.247.255 scope global local-node
    #          valid_lft forever preferred_lft forever
    #       inet6 2a03:2260:300e:1a00::ffff/128 scope global deprecated
    #          valid_lft forever preferred_lft 0sec
    #       inet6 fe80::1441:95ff:fe40:f7dc/64 scope link
    #          valid_lft forever preferred_lft forever
    #   10: bat0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UNKNOWN qlen 1000
    #       link/ether 52:54:00:12:34:56 brd ff:ff:ff:ff:ff:ff
    #       inet6 fe80::5054:ff:fe12:3456/64 scope link
    #          valid_lft forever preferred_lft forever
    #   11: primary0: <BROADCAST,NOARP,UP,LOWER_UP> mtu 1532 qdisc noqueue master bat0 state UNKNOWN qlen 1000
    #       link/ether da:2d:59:c4:41:2b brd ff:ff:ff:ff:ff:ff
    #       inet6 fe80::d82d:59ff:fec4:412b/64 scope link
    #          valid_lft forever preferred_lft forever
    #   12: mesh-vpn: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1312 qdisc fq_codel master bat0 state UNKNOWN qlen 1000
    #       link/ether da:2d:59:c4:41:2f brd ff:ff:ff:ff:ff:ff
    #       inet6 fe80::d82d:59ff:fec4:412f/64 scope link
    #          valid_lft forever preferred_lft forever

    # Note that QEMU's DHCP server is always active in user-mode networking, or at least I could not find a way to disable it.
    # By default, the first DHCP address handed out is x.x.x.15 . The host will be visible as x.x.x.2 . The virtual DNS server as x.x.x.3 .
    # The following fixed (static) address that OpenWrt and Gluon (before configuration) use does not conflict with those.
    GUEST_LAN_IP="192.168.1.1"

    PORT_FORWARDS=""

    # Port forward for the web interface.
    #
    # In the case of Gluon after configuration, you need more steps in order to access the built-in web interface:
    #   ip address add 192.168.1.1/24 dev eth0  # Note that eth0 may not be in br-client, depending on the Gluon version (and perhaps on the VPN connection status).
    #   ip address | grep 192  # Verify that the address is actually there, in case you issue the command too early upon booting.
    #                          # Beware that, when the VPN starts, the IP address will be removed from the interface (!),
    #                          # so you will have to add it again. It may be that the MAC address changes. More investigation
    #                          # is necessary. Packet capture that filters out continous Batman broadcasts (Ethernet type 0x4305):
    #                          #   tcpdump -i eth0 ether proto not 0x4305
    #   # The firewall does not need to be stopped.
    #   #
    #   # Do not start a request until the IP address above has been set. Otherwise, the port forward will not work anymore,
    #   # even if you set the IP address later, or restart the VM from within with 'reboot'. You will have to restart QEMU.
    #   # I am not sure what the problem is. It maybe in the Ubuntu host and not in QEMU. More investigation is needed.
    #   # If Internet access is enabled, sometimes the port forward works, and sometimes it does not. I have not found out
    #   # the reason yet. QEMU or the host get confused and traffic does not flow anymore. Restarting the network interface
    #   # inside Gluon, or restarting with 'reboot', do not help. You need to restart QEMU. And next time around, it may
    #   # work again without any problems (!).
    PORT_FORWARDS+=",hostfwd=tcp::60080-${GUEST_LAN_IP}:80"


    # Port forward for SSH.
    # In the case of Gluon after configuration, you need the same manual steps above as for the web interface.
    PORT_FORWARDS+=",hostfwd=tcp::60022-${GUEST_LAN_IP}:22"

    # About option "restrict=on":
    # At the moment, this virtual LAN is not connected to anything else but the explicit QEMU port forwards.

    CMD+=" -netdev user,id=GuestLan,restrict=on,ipv6=off,net=192.168.1.0/24${PORT_FORWARDS} -device virtio-net-pci,addr=$(( FIRST_PCI_ADDR + 0 )),netdev=GuestLan"


    # Create virtual network card eth1 in the VM.
    #
    # OpenWrt considers eth1 to be the WAN connection.
    #
    # Connect the virtual network card to the outside world with QEMU's "user mode network stack".
    # QEMU acts as a proxy for outbound TCP/UDP connections (using NAT). It also provides DHCP and DNS service to the emulated system.
    # Other protocols, like ICMP, do not work.

    PORT_FORWARDS=""

    # Normally, OpenWrt's SSH server and web interface are not accessible on the WAN interface,
    # so there is no point setting up port forwards for them.
    # But on Gluon, the SSH server is accessible on the WAN interface, but not the HTTP server.
    # The HTTP server is only accessible if you disable the firewall.
    if true; then
      # This is the IP address that Qemu's DHCP server is assigning to the first client.
      # If you want to change this address, see Qemu's 'dhcpstart' option.
      GUEST_LAN_IP="10.0.3.15"

      # Port forward for the web interface.
      # But keep in mind that OpenWrt's web interface is normally not accessible on the WAN interface.
      # SSH port forward on the host to access the web interface:
      #  ssh  -o StrictHostKeyChecking=no  -o CheckHostIP=no  -o PasswordAuthentication=no  -i "$HOME/.ssh/id_rsa_OpenWrtTest1_2020_05_26" -L60283:localhost:80  -N  -p 60023  root@localhost
      # Maybe add this option: -o UserKnownHostsFile=/dev/null
      PORT_FORWARDS+=",hostfwd=tcp::60083-${GUEST_LAN_IP}:80"

      # Port forward for SSH.
      # But keep in mind that OpenWrt's SSH server is normally not accessible on the WAN interface.
      PORT_FORWARDS+=",hostfwd=tcp::60023-${GUEST_LAN_IP}:22"
    fi

    ENABLE_INTERNET_ON_WAN=true

    if $ENABLE_INTERNET_ON_WAN; then
      local -r WAN_RESTRICT=""
    else
      local -r WAN_RESTRICT=",restrict=on"
    fi

    CMD+=" -netdev user,id=GuestWan${WAN_RESTRICT},ipv6=off,net=10.0.3.0/24${PORT_FORWARDS} -device virtio-net-pci,addr=$(( FIRST_PCI_ADDR + 1 )),netdev=GuestWan"


    # Create virtual network card eth2 in the VM for test purposes.
    #
    # OpenWrt seems to consider eth2 as another LAN interface.
    #
    # OpenWrt does not automatically start additional network interfaces. In order to do it manually:
    #   ifconfig eth2 up  &&  udhcpc -i eth2

    if false; then

      # This is the IP address that Qemu's DHCP server is assigning to the first client.
      # If you want to change this address, see Qemu's 'dhcpstart' option.
      # LAN_2_NET="10.0.4.0/24"
      # LAN_2_IP="10.0.4.15"
      LAN_2_NET="169.254.6.0/24"
      LAN_2_IP="169.254.6.15"

      PORT_FORWARDS=""

      # OpenWrt's SSH server and web interface are accessible on any further LAN interfaces.

      # Port forward for the web interface.
      # http and ssh seem to work after disabling the firewall inside OpenWrt like this: /etc/init.d/firewall stop
      PORT_FORWARDS+=",hostfwd=tcp::60086-${LAN_2_IP}:80"

      # Port forward for SSH.
      PORT_FORWARDS+=",hostfwd=tcp::60026-${LAN_2_IP}:22"

      #  This only works after disabling the firewall inside OpenWrt like this: /etc/init.d/firewall stop
      #  OpenWrt: socat -u  TCP4-LISTEN:1900,reuseaddr,fork  STDIO
      #  Host PC: printf "Test2" | socat -u STDIO  TCP4-connect:localhost:61900
      PORT_FORWARDS+=",hostfwd=tcp::61900-${LAN_2_IP}:1900"

      CMD+=" -netdev user,id=Lan2Net,restrict=on,ipv6=off,net=${LAN_2_NET}${PORT_FORWARDS} -device virtio-net-pci,addr=$(( FIRST_PCI_ADDR + 2 )),netdev=Lan2Net"
    fi
  fi


  # Option -no-shutdown makes QEMU wait (it does not exit) if the OpenWrt guest does a "poweroff",
  # but it does not affect a "reboot".
  #   quote_and_append_args  CMD  "-no-shutdown"

  # Option -no-reboot makes QEMU exit if the OpenWrt guest does a "reboot".
  # However, together -no-shutdown, option -no-reboot makes QEMU wait (it does not exit) if the OpenWrt guest does a "reboot".
  # This should actually be documented in the QEMU man page.
  #   quote_and_append_args  CMD  "-no-reboot"


  # About Qemu monitoring:
  # -mon [chardev=]name[,mode=readline|control][,default]
  #     Setup monitor on chardev name.
  #  About the QEMU monitor:
  #     http://en.wikibooks.org/wiki/QEMU/Monitor
  #  How to place the monitor in a separate telnet connection:
  #    https://stackoverflow.com/questions/49716931/how-to-run-qemu-with-nographic-and-monitor-but-still-be-able-to-send-ctrlc-to
  #    -monitor telnet
  #
  #  With this:
  #    -serial mon:stdio
  #  You get:
  #   - Ctrl + A X: exit qemu
  #   - Ctrl + C: gets passed to the guest
  #
  #  Standard:
  #  - Ctrl-A c
  #     Switch between console and monitor


  # Using KVM with the same CPU as the host accelerates the emulation significantly.
  # On Ubuntu, you can only use KVM if your user account is a member of the 'kvm' group:
  #  sudo adduser "$USER" kvm
  CMD+=" -enable-kvm -cpu host"


  # Run the command on a new console, for it is usually more convenient.
  if true; then

    printf -v CMD \
         "%q --console-title=%q --console-icon=computer -- %q" \
         "$HOME/rdiez/Tools/RunInNewConsole/run-in-new-console.sh" \
         "$CONSOLE_TITLE" \
         "$CMD"
  fi

  echo "$CMD"
  eval "$CMD"
}


# ------- Entry point -------

find_where_this_script_is

declare -r UNPACKED_IMAGES_DIR="$DIR_WHERE_THIS_SCRIPT_IS/StartOpenWrtVm-UnpackedImagesDir"

if (( $# != 0 )); then
  abort "Invalid number of command-line arguments. See this script's source code for more information."
fi


start_vm
