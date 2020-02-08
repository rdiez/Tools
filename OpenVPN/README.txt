
-- How to configure OpenVPN so that single clients can access your internal network --

These instructions are for an Ubuntu 18.04 OpenVPN server and its bundled OpenVPN version 2.4.x .

There are many OpenVPN guides on the Internet, but I could not find anything that really helped me.
So I wrote yet another guide.

OpenVPN has been an unnecessarily painful experience. I hope it gets replaced with something sensible soon.

We will be bridging with a TAP interface. This way, we do not have to change
anything in the existing TCP/IP infrastructure on your local network.

- Start with certificate generation. Yes, I know, it is a pain.

  - The certificate generation files should be kept on a separate machine for security reasons.
    The OpenVPN server is visible on the Internet. If it gets slightly compromised,
    so that an attacker gains read access to the root certificate, it could easily forge certificates.

  - There are many good guides on the Internet, like this one:

      https://linuxconfig.org/openvpn-setup-on-ubuntu-18-04-bionic-beaver-linux

    These are the steps / commands:

    - Install the 'easy-rsa' and 'openvpn' packages.
      OpenVPN is only needed in order to generate a secret key.

    - make-cadir openvpn-certificates && cd openvpn-certificates

    - Manually edit KEY_CONFIG in file 'vars' because of a bug:
      export KEY_CONFIG="$EASY_RSA/openssl-1.0.0.cnf"

    - Edit variables KEY_COUNTRY etc. in the same 'vars' file.

    - The default expiration date is set to 10 years in the future.
      You may find that date inconvenient. Change variables CA_EXPIRE and KEY_EXPIRE accordingly.

    - source ./vars

    - Certificate and client configuration filenames should include a date, so that the user knows
      which one is the current one, and which files are old and can be deleted.

      Client certificate whitelisting uses the common name at the moment, so a new certificate should never have
      the same common name as an old, cancelled one. That is also a the reason why client certificate common names
      include the issue date.

    - ./clean-all && ./build-ca  "my-ca-$(date "+%F")"

    - ./build-key-server server

    - This will take some time, like over 1 minute:
      ./build-dh

    - openvpn --genkey --secret keys/ta.key

    - At this point, you need to setup the server, see the list below.

      The files you need to copy to /etc/openvpn/server/my-server-instance on the OpenVPN server are:

        ca.crt
        dh2048.pem
        server.crt
        server.key
        ta.key

      Note that ca.key is not copied over. That file is to be kept secret. The OpenVPN server does not need it.

    - Edit file openvpn-client.conf.template .
      You will need to adjust at least the 'remote' setting.

    - Edit the create-client.sh script according to your system. You need to edit at least CERTIFICATES_DIRNAME.
      Use the script to create the client certificates. A Windows client computer only actually needs the .ovpn file.
      However, separate files are more convenient when using a Linux computer with the NetworkManager. The files are
      shared secret ta.key, root certificate ca.crt, and client certificate files .crt and .key.

    - There is no need to ever revoke a certificate, just remove its common name from the allowed-clients.txt file
      on the OpenVPN server.


- Server installation steps:

  - Install these packages:
    openvpn  bridge-utils  libx500-dn-perl

  - When bridging with a TAP interface, the OpenVPN server system does not need to have IP forwarding enabled,
    at least if this system is not also acting as TCP/IP router between different network segments.

  - Create a persistent virtual network bridge on your OpenVPN server host, and configure its IP address etc. statically.
    There are many ways to create a bridge. If you choose Ubuntu's Netplan, see configuration file 99-OurNetplanConfig.yaml .
    The bridge will be associated with the main LAN interface.
    Later on, a script will dynamically create a TAP for the OpenVPN server and associate it to the bridge.

  - Add an unpriviledged user that will be checking the client certificate whitelist script:

    sudo adduser openvpn-unpriviledged-user --disabled-login  --shell /usr/sbin/nologin

  - We need to find a place in the filesystem where openvpn-unpriviledged-user can read
    the client certificate whitelist.

    The home directory for openvpn-unpriviledged-user would not work, because the default systemd configuration
    for the OpenVPN server has option "ProtectHome=true". So I just created a top-level directory like this:

      sudo mkdir /openvpn-client-whitelist

    Place the following files in this directory:
      allowed-clients.txt
      tls-verify-script.pl

    And make sure they are owned (or at least readable) by that user. The Perl script needs to be executable:
      cd /openvpn-client-whitelist
      sudo chown  openvpn-unpriviledged-user:openvpn-unpriviledged-user  .
      sudo chmod ug=rx,o-rwx  .
      sudo chown openvpn-unpriviledged-user:openvpn-unpriviledged-user  allowed-clients.txt  tls-verify-script.pl
      sudo chmod ug=r,o-rwx    allowed-clients.txt
      sudo chmod ug=rx,o-rwx  tls-verify-script.pl

  - Configure the openvpn-server systemd service.

    On Ubuntu, OpenVPN is installed as a systemd "instantiated service". Such services can be started
    for different configurations. The main configuration file is:
      /lib/systemd/system/openvpn-server@.service
    You do not need to modify that file, but looking at it will provide an insight about how
    this service is configured.

    First of all, create a small overriding service configuration file:

      sudo systemctl edit openvpn-server@my-server-instance.service

      That creates the following file:
        /etc/systemd/system/openvpn-server@my-server-instance.service.d/override.conf

      Then place the contents of the example override.conf in that file.

      Place the OpenVPN server configuration file here:
        /etc/openvpn/server/my-server-instance.conf

      You will need to edit my-server-instance.conf and adjust the port number, IP addresses and so on for your network.

      Create this directory and place the following files there:
        /etc/openvpn/server/my-server-instance

        Script tap-start-stop.sh  (needs to be executable)
        The certificate files like server.crt (see the section about the certificates)


  - The OpenVPN server service is managed like any other systemd instantiated service:
    sudo systemctl enable openvpn-server@my-server-instance.service
    sudo systemctl start openvpn-server@my-server-instance.service
    systemctl status openvpn-server@my-server-instance.service

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

  - For Windows, it is probably worth to include some extra information:

    - When you install OpenVPN, installing the TAP may take a long time, like several minutes.
      But it does work in the end, so you just have to be patient.

    - The Windows OpenVPN GUI client can conveniently import an .opvn file.
      The usual configuration and log file path on Windows is:  %USERPROFILE%\OpenVPN\config
      The settings dialog also shows where such files land on the hard disk.

  - For Linux, mention that the DHCP DNS options will not be automatically accepted.
    That means that only IP addresses will work, and no Windows hostnames.

    In order to automatically accept such DHCP options, you need to modify the OpenVPN .ovpn file
    to use a script. Install package 'openvpn-systemd-resolved' and search for a guide on the Internet.
    You need to use options 'up', 'down', and 'down-pre', and beware of permission issues,
    see options 'script-security', 'user' and 'group'. You may want to modify the script
    in order to disable IPv6 too, see further below for more information.

    It is also possible to manually configure a systemd OpenVPN client connection service. This way,
    disabling IPv6 can be done with separate scripts. Start such a connection like this:
      systemctl start openvpn-client@<configuration>

    Alternatively, you could install Ubuntu package 'network-manager-openvpn' and use
    the NetworkManager GUI, which can partially import an .ovpn file.
    Search for a guide on the Internet. For example:
      https://askubuntu.com/questions/187511/how-can-i-use-a-ovpn-file-with-network-manager

  - State that the OpenVPN software should be kept reasonably up to date.
    On Windows, the easiest way is probably with Chocolatey.

    I have not found an easy way for the server to reject clients older than a given version number.
    In my opinion, this is a security weakness in OpenVPN, because end users will inevitably
    neglect updating the client.

  - Mention that you cannot test the OpenVPN connection from within the OpenVPN server LAN.
    If you smartphone has mobile Internet, you can use its tethering / hot spot function.

  - Document the privacy concern that all client DNS queries will be routed to the OpenVPN server network,
    at least on Windows clients. On Linux, if the users chooses to accept the DHCP DNS options,
    then this concern applies too.

  - If the client is not already using IPv6, disable it on the TAP adapter before connecting.
    Otherwise, IPv6 will autoconfigure itself, and some things like google.com will
    suddenly switch to IPv6 and be routed over the VPN.

    Unfortunately, OpenVPN offers no easy way to prevent IPv6 from being used on the server TAP.

    On Windows, the TAP shows up as a standard network adapter, so you can disable IPv6 on it
    with the GUI.

    On Linux, you can script it like this:

      sudo openvpn  --mktun  --dev-type "tap"  --dev OpenVpnCliTap
      sudo sysctl --write net.ipv6.conf.OpenVpnCliTap.disable_ipv6=1
      sudo openvpn --config my-openvpn-client-config.ovpn
      After closing the connection:
      sudo openvpn  --rmtun  --dev-type "tap"  --dev OpenVpnCliTap

      Script connect-with-openvpn.sh automates those steps.

      Alternatively, you could use the NetworkManager GUI, see the section above about DHCP DNS options
      under Linux for more information.

  - Mention the possibility of an IP address range collision.
    For example, if both the local and the OpenVPN server LAN are using 192.168.1.x .

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
