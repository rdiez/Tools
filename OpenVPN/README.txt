
-- How to configure OpenVPN so that single clients can access your internal network --

This guide is mainly for the Ubuntu 22.04 with its bundled OpenVPN version 2.5.5 .
However, most information is generic and applies to other Linux distributions too.

There are many OpenVPN guides on the Internet, but I could not find anything for a small,
simple network that really helped me. So I wrote yet another guide.

OpenVPN has been an unnecessarily painful experience. I hope it gets replaced with something sensible soon.

An older version of this guide used a virtual TAP interface to bridge the LAN
at Ethernet level (OSI Layer 2).
Advantages were:
- The remote device really looked like it was in the same LAN.
  Broadcasts packets and non-TCP/IP protocols worked as well.
- You almost did not have to change the local network configuration.
  You only needed to exclude an arbitrary address range from the local DHCP pool for remote VPN clients.
Disadvantages were:
- Some performance loss (which is not easy to quantify) due to chatty broadcast traffic.
- The standard Android and iPhone clients did not work.

This version of the guide uses a virtual TUN adapter with Proxy ARP and relies on TCP/IP routing (OSI Layer 3).
Advantages are:
- All standard clients work.
- Increased performance (which is not easy to quantify), as broadcasts are blocked.
- By using Proxy ARP, the VPN clients get an IP address in the same local subnet,
  which means little network routing changes (which can be complicated).
Disadvantages are:
- You may have to change a little more in the local network configuration.
  You still need to exclude an address range from the local DHCP pool for remote VPN clients,
  but the range cannot be completely arbitrary, as you have to follow IP subnetting rules.
- Non-TCP/IP protocols and broadcast-based protocols do not work anymore.
  This includes comfortable name resolution with mDNS/Avahi/Bonjour, and broadcast ping.


The steps are:

- Start with certificate generation. Yes, I know, it is a pain.

  The certificate generation files should be kept on a separate machine for security reasons.
  The OpenVPN server is visible on the Internet. If it gets slightly compromised,
  so that an attacker gains read access to the root certificate, the attacker could easily forge certificates.

  The following steps apply to 'easy-rsa' version >= 3.0.7 which comes with 22.04 :

  There are many good guides on the Internet, like this one:

    https://wiki.archlinux.org/title/Easy-RSA

  In such guides you will probably find more options and more advanced security advice than on this short document.

  These are the steps:

    - Install the 'easy-rsa' and 'openvpn' packages on a different PC (not on the OpenVPN server PC).
      Instead of using the 'easy-rsa' package, you could use the latest easy-rsa version from:
        https://github.com/OpenVPN/easy-rsa
      The OpenVPN installation is only needed in order to generate a secret key.

    - Run these commands:
      make-cadir "openvpn-certificates"
      cd         "openvpn-certificates"

    - Edit the 'vars' file:

        - The default expiration date is set to 10 years in the future.
          You may find that date inconvenient. Therefore, uncomment the lines with variables
          EASYRSA_CA_EXPIRE and EASYRSA_CERT_EXPIRE, and adjust their values accordingly.

        - Upgrade from the default RSA and Diffie Hellman cryptography to Elliptic Curve.
          Uncomment the lines with these variables and set their values as follows:
            set_var EASYRSA_ALGO ec
            set_var EASYRSA_CURVE secp521r1
            set_var EASYRSA_DIGEST "sha512"

    - Run this command:
      ./easyrsa init-pki

    - Run this command:
        ./easyrsa build-ca nopass
      Without option 'nopass' you will be prompted for a password to protect the CA. You will then have to enter
      the password every time you use the CA.
      If you are prompted about the "Common Name", you can press Enter to use the default "Easy-RSA CA".

    - Generate a key pair for your OpenVPN server:

      ./easyrsa build-server-full server nopass

      Instead of 'server', you can use a different server name, but then you
      will have adjust the OpenVPN configuration file accordingly.

    - Create the HMAC key. HMAC is an optional measure to increase security.

      openvpn --genkey --secret ta.key

      Version 3.0.8, which comes with Ubuntu 22.04, issues a deprecation warning.
      The new command syntax is:
        openvpn --genkey secret ta.key

    - Later on, when you set up the OpenVPN server, you need to copy the following files
      to /etc/openvpn/server/my-server-instance :

      ta.key
      pki/ca.crt
      pki/issued/server.crt
      pki/private/server.key

      Note that ca.key is not copied over. That file is to be kept secret. The OpenVPN server
      does not really need it.

    The server certificates are complete. The following steps allow you to generate the client keys:

    - Edit file openvpn-client.conf.template under the CertificateConfig subdirectory next to this text file.
      You will need to adjust at least the 'remote' setting, probably 'port' too.

    - Edit the create-client.sh script according to your system. You need to edit at least CERTIFICATES_DIRNAME.

    - About client certificate naming:

      - The create-client.sh script supplied with these instructions always appends the current date
        to the given name. Reasons are:

        - Certificate and client configuration filenames should include a date, in order for the user to know
          which one is valid, and which files are old and can be deleted.

        - Client certificate whitelisting uses the common name at the moment, so a new certificate should never have
          the same common name as an old, cancelled one. That is another reason why client certificate common names
          include the issue date.

      - You may want to use numbers instead of person names. Reasons are:

        - You probably want to create a batch of certificates in advance, and have them ready for instant usage.

        - If the file gets stolen, you probably do not want the attacker to know the associated user.

    - Use script create-client.sh to create the client certificate and the .ovpn file with the client connection configuration.
      Most OpenVPN clients only need the resulting .ovpn file, which embeds all keys and certificates.
      If a user needs to manually configure a non-standard client, the following separate files may be necessary:
      - shared secret ta.key
      - root certificate ca.crt
      - client certificate files .crt and .key

    - There is no need to ever revoke a client certificate, just remove its common name
      from the allowed-clients.txt file on the OpenVPN server.


- Server installation steps:

  - Install these packages:
    openvpn
    libx500-dn-perl  # Needed by script tls-verify-script.pl

  - The operating system on which the OpenVPN server is installed needs to have IP forwarding enabled.
    Consult your system documenation to that effect.
    On Ubuntu/Debian, create a file named /etc/sysctl.d/90-my-systcl-config.conf with this line:
      net.ipv4.ip_forward = 1

    Without IP forwarding, VPN clients can only reach the VPN endpoint (the IP address of the OpenVPN server
    in the VPN address range), and other IP addresses on the server PC (like the LAN IP address of the OpenVPN server).
    However, clients will not be able to talk to each other (as configuration directive 'client-to-client' is not enabled),
    or to reach other IP addresses in the server's LAN.

  - Most other guides I have seen on the Internet state that you need to enable Proxy ARP
    on the network interface. You can check its enabled/disable status like this:
      cat /proc/sys/net/ipv4/conf/enp1s0/proxy_arp
    Replace 'enp1s0' above with the corresponding network interface on your system.

    However, I did not need to enable Proxy ARP on my server. The 'arp' commands which add
    the MAC addresses worked even though option proxy_arp was disabled not only on all interfaces,
    but also globally in /proc/sys/net/ipv4/conf/all/proxy_arp .

  - Determine a range of IP addresses in your LAN to reserve for remote VPN clients.
    This range cannot be completely arbitrary, as you have to follow IP subnetting rules.
    Use a tool like 'subnetcalc' to prevent errors. Example command: subnetcalc 192.168.1.80/29
    Exclude the chosen range from the local DHCP server, in order to prevent address collisions,
    because the OpenVPN server will act as the DHCP server for OpenVPN clients.

    Example range:
    - LAN subnet: 192.168.1.x (/24)
    - VPN subnet: 192.168.1.80-87 (/29, therefore with 8 addresses, subnet mask 255.255.255.248)
      That is a subset of the LAN IP address range. The breakdown is:
      - VPN subnet ID / network address: 192.168.1.80
      - VPN server address:              192.168.1.81    (VPN endpoint)
      - VPN client addresses:            192.168.1.82-86 (5 IP addresses)
      - VPN broadcast address:           192.168.1.87
    - Range to exclude in your LAN DHCP server: 192.168.1.80-87 (the whole VPN subnet)

  - Add an unpriviledged user account which will be running the script to check new clients
    against the allowed clients whitelist:

    sudo  adduser  --disabled-login  --shell /usr/sbin/nologin  --gecos ""  openvpn-unpriviledged-user

  - We need to find a place in the filesystem where openvpn-unpriviledged-user can read
    the client certificate whitelist.

    The home directory for openvpn-unpriviledged-user would not work, because the default systemd configuration
    for the OpenVPN server has option "ProtectHome=true". So create a top-level directory like this
    (or choose any other place for it appropriate to your system):

      sudo mkdir /openvpn-allowed-clients

    Place the following files in this directory:
      allowed-clients.txt
      tls-verify-script.pl

    Make sure those files are readable by openvpn-unpriviledged-user (but not writable).
    The Perl script needs to be executable by that user too.
    The following commands set tight permissions for those files:
      cd /openvpn-allowed-clients
      sudo chown root:openvpn-unpriviledged-user  ./  allowed-clients.txt  tls-verify-script.pl
      sudo chmod u=rwx,g=rx,o= ./
      sudo chmod u=rw,g=r,o=   allowed-clients.txt
      sudo chmod u=rwx,g=rx,o= tls-verify-script.pl

    You can test script tls-verify-script.pl now like this:

      sudo --user=openvpn-unpriviledged-user /bin/bash
      cd /openvpn-allowed-clients
      ./tls-verify-script.pl allowed-clients.txt 0 CN=test

      You should see an error message like this:
        Client with common name "test" was not found in the allowed clients list.
      Anything else is an indication of a problem that needs to be fixed.


  - Configure the openvpn-server systemd service.

    On Ubuntu, OpenVPN is installed as a systemd "instantiated service". Such services can be started
    for different configurations. The main configuration file is:
      /lib/systemd/system/openvpn-server@.service
    You do not need to modify that file, but looking at it will provide an insight about how
    this service is configured.

    First of all, create a small overriding service configuration file like this:

      sudo systemctl edit openvpn-server@my-server-instance.service

    Then copy and paste there the contents of the example override.conf provided with these instructions.

    After you are done, "systemctl edit" should have created the following file with those contents:
      /etc/systemd/system/openvpn-server@my-server-instance.service.d/override.conf

    Copy the example my-server-instance.conf to this location:
      /etc/openvpn/server/my-server-instance.conf

    Just in case, tighten the file's access permissions,
    so that only root can modify it:
      sudo chown root:root /etc/openvpn/server/my-server-instance.conf
      sudo chmod u=rw,go=r /etc/openvpn/server/my-server-instance.conf

    You will need to edit my-server-instance.conf and adjust the port number, IP addresses and so on for your network.

    Create a directory like this:

      sudo mkdir /etc/openvpn/server/my-server-instance

    Only 'root' should be able to look inside that directory, because it contains security keys and certificates.
    Tighten access permissions to it with:
      sudo chown root:root /etc/openvpn/server/my-server-instance/
      sudo chmod go=       /etc/openvpn/server/my-server-instance/

    Copy certificate files server.crt etc. to that directory.
    The section about creating the certificates lists which files to copy.

    Copy script ConfigureProxyArpAddresses.sh to that directory too.
    The script needs to be executable:
      chmod u+x ConfigureProxyArpAddresses.sh
    Edit the script and amend variables NETWORK_INTERFACE and FIRST_CLIENT_IP_ADDRESS.
    The comments around those variables will indicate what else needs to be amended.
    You can test the script like this:
      sudo ./ConfigureProxyArpAddresses.sh add
      sudo ./ConfigureProxyArpAddresses.sh remove

    Tighten permissions on all files inside the directory like this:
      sudo chown root:root /etc/openvpn/server/my-server-instance/*
      sudo chmod go=       /etc/openvpn/server/my-server-instance/*

  - The OpenVPN server service is managed like any other systemd instantiated service:
    Enable and start it like this:
      sudo systemctl enable --now openvpn-server@my-server-instance.service

    Follow its log output with:
      journalctl --follow --unit=openvpn-server@my-server-instance.service

    At this point, you should inspect the service's log for any indication of trouble.

    Query its status with:
      systemctl status openvpn-server@my-server-instance.service

  - About spurious log errors:

    When you stop the OpenVPN server, you will probably see the following error in the system log:

      Linux can't del IP from iface OpenVpnSrvTun

    The OpenVPN server creates the TUN interface on start-up, and then it drops privileges
    for security reasons, so that it does not have enough privileges during shutdown
    to reconfigure the TUN interface. This is an interesting situation which I did not see
    mentioned in the official documentation.

    This error does not really matter, because the OpenVPN server manages to delete
    the TUN interface afterwards (even though it runs with low privileges).

    When acting as a VPN client on Linux, there are similar errors on shutdown:

      net_route_v4_del: 192.168.1.0/24 via 192.168.1.81 dev [NULL] table 0 metric -1
      sitnl_send: rtnl: generic error (-1): Operation not permitted
      ERROR: Linux route delete command failed
      Closing TUN/TAP interface
      net_addr_v4_del: 192.168.1.82 dev OpenVpnCliTun
      sitnl_send: rtnl: generic error (-1): Operation not permitted
      Linux can't del IP from iface OpenVpnCliTun

    I believe that the cause is the same: after dropping privileges,
    the client can no longer reconfigure the TUN interface.
    Nevertheless, the client does manage to delete the TUN interface too in the end,
    so such errors do not really matter either.

  - You should rotate the shared secret key every few years, but that is probably a big pain.
    It looks like you cannot have 2 such secret keys at the same time.
    In order to move to a new such secret key, it is probably easier to install a second OpenVPN server instance.

    Keep in mind that the certificates (root, server, clients) have an expiration date too.

  - If you want to see the currently-connected clients, look at this file:
    /run/openvpn-server/status-my-server-instance.log


- Write the end-user documentation:

  - Explain that the OpenVPN configuration file has a unique key that should be treated
    like a normal house key. If the file is lost or falls into the wrong hands, the user should report it.
    The user should delete old keys. The GUI settings shows where such config files are stored.

  - For Windows, it is probably worth to include some extra information about the "OpenVPN GUI":
    The Windows "OpenVPN GUI" client can conveniently import an .opvn file.
    The usual configuration and log file path on Windows is:  %USERPROFILE%\OpenVPN\config
    The settings dialog also shows where such files land on the hard disk.

  - For Linux, mention that the DHCP DNS server options may not be automatically accepted.
    If the LAN where the OpenVPN server is has its own DNS server to resolve
    private hostnames, such local name resolution may not work on the OpenVPN client.

    The official 'openvpn' client for Linux is known to ignore any DHCP DNS server options
    pushed from the OpenVPN server. There are workarounds which involve complicated scripting.

    Alternatively, you could use the popular 'NetworkManager', which can import .ovpn files.
    DNS should automatically work then. You may need to install Debian/Ubuntu packages
    'network-manager-openvpn' and 'network-manager-openvpn-gnome' (even if you are not
    using the GNOME Desktop) beforehand.

  - For Linux, mention that the NetworkManager VPN client routes all Internet traffic
    through the VPN by default, even if the connection file does not state that it should. Workaround:
      nmcli  connection  modify  <connection-name>  ipv4.never-default yes
    In the GUI, this option is called "Use this connection only for resources on its network",
    you can just enable (tick) it there.
    The trouble is, I had inexplicable global DNS problems when I tried this workaround.
    It turns out that this problem is well known, and many workarounds are available.
    This one worked for me:
      nmcli  connection  modify  <connection-name>  ipv4.dns-search "~"
    In the GUI, this option is called "Additional search domains",
    you can just enter the character '~' in that field.

  - State that the OpenVPN software should be kept reasonably up to date.
    On Windows, the easiest way is probably with Chocolatey.
    Otherwise, manually upgrading an OpenVPN client is usually not hard.

    I have not found an easy way for the server to reject clients older than a given version number.
    In my opinion, this is a security weakness in OpenVPN, because end users will inevitably
    neglect updating the client.

  - Mention that you cannot test the OpenVPN connection from within the OpenVPN server LAN.
    If you smartphone has mobile Internet, you can use its tethering / hot spot function.

  - State that the VPN connection uses the "split tunnel" mode, as opposed to "full tunnel" mode.
    "Split tunnel" means that only traffic to internal computers in the remote company network
    goes through the tunnel, everything else goes to the local network or directly to the Internet.

  - Document the privacy concern that all client DNS queries will be routed to the OpenVPN server network,
    at least on Windows clients. On Linux, if the client accepts the pushed DHCP DNS options,
    then this concern applies too. This means that the company can see all your DNS queries
    when the VPN is active.
    This is a limitation that should not happen in "split tunnel" mode.
    A split DNS configuration is theoretically possible, but not easy, and is not covered in this guide.

  - Mention the possibility of an IP address range collision.
    For example, if both the remote LAN (where the OpenVPN client is) and the OpenVPN server LAN
    are using the same IP address range 192.168.1.x .

  - Document the expected maximum upload and download speeds.

    The Internet upload speed on the server side will probably be the most important bottleneck.

    If speed is not sufficient, advise the users to consider taking remote control of a computer
    located inside the remote network. Reasons are:
    - Remote control protocols are optimised for low-speed connections.
    - The data the user is processing may not need to leave the remote network at all.
    The downside is increased electricy consumption if PCs are always left on for this purpouse.
    You may be able to use Wake-on-LAN to compensate.

  - Document expected downtimes or connection losses.
    For example, some servers update themselves daily at 3 am. And some Internet providers change
    the IPv4 address or the IPv6 address prefix every day.
