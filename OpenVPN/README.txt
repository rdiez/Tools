
-- How to configure OpenVPN so that single clients can access your internal network --

This guide is mainly for the following Ubuntu versions:

- Ubuntu 18.04 with its bundled OpenVPN version 2.4.4
- Ubuntu 20.04 with its bundled OpenVPN version 2.4.7

However, most information is generic and applies to other Linux distributions too.

There are many OpenVPN guides on the Internet, but I could not find anything that really helped me.
So I wrote yet another guide.

OpenVPN has been an unnecessarily painful experience. I hope it gets replaced with something sensible soon.

We will be bridging with a TAP interface. This way, we do not have to change
anything in the existing TCP/IP infrastructure on your local network.

Later note: Instead of bridging, it is probably best to use routing (a TUN interface) together with
            the ARP proxy mode. This way, the VPN clients get an IP address in the same local subnet
            without any network routing changes.

- Start with certificate generation. Yes, I know, it is a pain.

  - The certificate generation files should be kept on a separate machine for security reasons.
    The OpenVPN server is visible on the Internet. If it gets slightly compromised,
    so that an attacker gains read access to the root certificate, the attacker could easily forge certificates.

  - Steps for Ubuntu 18.04 / easy-rsa version 2:

    There are many good guides on the Internet, like this one:

      https://linuxconfig.org/openvpn-setup-on-ubuntu-18-04-bionic-beaver-linux

    These are the steps:

      - Install the 'easy-rsa' and 'openvpn' packages.
        The OpenVPN installation is only needed in order to generate a secret key.

      - make-cadir openvpn-certificates && cd openvpn-certificates

      - Manually edit KEY_CONFIG in file 'vars' because of a bug:
        export KEY_CONFIG="$EASY_RSA/openssl-1.0.0.cnf"

      - Edit variables KEY_COUNTRY etc. in the same 'vars' file.

      - The default expiration date is set to 10 years in the future.
        You may find that date inconvenient. Change variables CA_EXPIRE and KEY_EXPIRE
        in the same 'vars' file accordingly.

      - Import the variables into your current shell with this command:
        source ./vars

      - Run these commands:
        ./clean-all && ./build-ca  "my-ca-$(date "+%F")"
        ./build-key-server server

      - This command will take some time, like over 1 minute:
        ./build-dh

      - openvpn --genkey --secret keys/ta.key

      - Later on, when you set up the OpenVPN server, you need to copy the following files
        to /etc/openvpn/server/my-server-instance :

          ca.crt
          dh2048.pem
          server.crt
          server.key
          ta.key

        Note that ca.key is not copied over. That file is to be kept secret. The OpenVPN server does not need it.

      The server certificates are complete. The following steps allow you to generate the client keys:

      - Edit file openvpn-client.conf.template under the ClientConfig subdirectory next to this text file.
        You will need to adjust at least the 'remote' setting, probably 'port' too.

      - Edit the create-client.sh script according to your system. You need to edit at least CERTIFICATES_DIRNAME,
        maybe EASY_RSA_VERSION too.

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

      - Use the create-client.sh script to create the client certificates.
        A Windows client computer only actually needs the resulting .ovpn file.
        A Linux client computer may need the separate key files:
        - shared secret ta.key
        - root certificate ca.crt
        - client certificate files .crt and .key

      - There is no need to ever revoke a certificate, just remove its common name from the allowed-clients.txt file
        on the OpenVPN server.


  - Steps for Ubuntu 20.04 / easy-rsa version 3:

    There are many good guides on the Internet, like this one:

      https://wiki.archlinux.org/title/Easy-RSA

    In such guides you will probably find more options and more advanced security advice than on this short document.

    These are the steps:

      - Install the 'easy-rsa' and 'openvpn' packages.
        Instead of using the 'easy-rsa' package, you could use the latest easy-rsa version from:
          https://github.com/OpenVPN/easy-rsa
        The OpenVPN installation is only needed in order to generate a secret key.

      - Run these commands:
        make-cadir openvpn-certificates
        cd openvpn-certificates

      - Edit the 'vars' file:

          - The default expiration date is set to 10 years in the future.
            You may find that date inconvenient.

            Uncomment the lines with variables EASYRSA_CA_EXPIRE and EASYRSA_CERT_EXPIRE,
            and adjust their values accordingly.

          - Upgrade from the default RSA cryptography to Elliptic Curve.
            Uncomment the lines with these variables and set their values as follows:
              set_var EASYRSA_ALGO ec
              set_var EASYRSA_CURVE secp521r1
              set_var EASYRSA_DIGEST "sha512"

      - Run this command:
        ./easyrsa init-pki

      - If you are using easy-rsa version 3.0.6 that comes with Ubuntu 20.04,
        there is a bug what will make 'build-ca' print an error message like this:
          Can't load /home/.../openvpn-certificates/pki/.rnd into RNG
        The bug is documented here:
          Can't load /usr/share/easy-rsa/pki/.rnd into RNG
          https://github.com/OpenVPN/easy-rsa/issues/261
        It was fixed in easy-rsa version 3.0.7.
        The work-around for version 3.0.6 is to create that file beforehand:
          dd if=/dev/urandom of="pki/.rnd" bs=256 count=1

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

      - Generate the Diffie Hellman key, even though OpenVPN will not actually use it,
        because we have configured Elliptic Curve instead.
        The following command will take some time, like over 1 minute:
          ./easyrsa gen-dh
        Without a valid Diffie Hellman file, OpenVPN will fail with the following error message:
          Options error: You must define DH file (--dh)
        This bug report explains why you need that file nevertheless:
          Have to specify "dh" file when using elliptic curve ecdh
          https://community.openvpn.net/openvpn/ticket/410

      - Later on, when you set up the OpenVPN server, you need to copy the following files
        to /etc/openvpn/server/my-server-instance :

        ta.key
        pki/ca.crt
        pki/issued/server.crt
        pki/private/server.key
        pki/dh.pem

        Note that ca.key is not copied over. That file is to be kept secret. The OpenVPN server does not need it.

      The server certificates are complete. The following steps allow you to generate the client keys:

      - Edit file openvpn-client.conf.template under the ClientConfig subdirectory next to this text file.
        You will need to adjust at least the 'remote' setting, probably 'port' too.

      - Edit the create-client.sh script according to your system. You need to edit at least CERTIFICATES_DIRNAME,
        maybe EASY_RSA_VERSION too.

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


      - Use the create-client.sh script to create the client certificates.
        A Windows client computer only actually needs the resulting .ovpn file.
        A Linux client computer may need the separate key files:
        - shared secret ta.key
        - root certificate ca.crt
        - client certificate files .crt and .key

      - There is no need to ever revoke a certificate, just remove its common name from the allowed-clients.txt file
        on the OpenVPN server.


- Server installation steps:

  - Install these packages:
    openvpn
    bridge-utils
    libx500-dn-perl  # Needed by script tls-verify-script.pl

  - We will be bridging the VPN connections to the network with a TAP interface. Therefore, the operating system on which the OpenVPN server
    is installed does not need to have IP forwarding enabled, unless something else requires it (for example, if that system is
    also acting as TCP/IP router between different network segments).

  - Create a persistent virtual network bridge on your OpenVPN server host, and configure its IP address etc. statically.
    There are many ways to create a bridge. If you choose Ubuntu's Netplan, see example configuration file 99-OurNetplanConfig.yaml .
    The bridge will be associated with the main LAN interface.
    Later on, a script will dynamically create a TAP for the OpenVPN server and associate it to the bridge.

  - Add an unpriviledged user that will be checking the client certificate whitelist script:

    sudo adduser openvpn-unpriviledged-user --disabled-login  --shell /usr/sbin/nologin

  - We need to find a place in the filesystem where openvpn-unpriviledged-user can read
    the client certificate whitelist.

    The home directory for openvpn-unpriviledged-user would not work, because the default systemd configuration
    for the OpenVPN server has option "ProtectHome=true". So I just created a top-level directory like this:

      sudo mkdir /openvpn-allowed-clients

    Place the following files in this directory:
      allowed-clients.txt
      tls-verify-script.pl

    And make sure they are readable by openvpn-unpriviledged-user.
    The Perl script needs to be executable by that user too.
    The following commands set tight permissions for those files:
      cd /openvpn-allowed-clients
      sudo chown root:openvpn-unpriviledged-user  .  allowed-clients.txt  tls-verify-script.pl
      sudo chmod u=rwx,g=rx,o-rwx .
      sudo chmod u=rw,g=r,o-rwx   allowed-clients.txt
      sudo chmod u=rwx,g=rx,o-rwx tls-verify-script.pl

    You can test scritp tls-verify-script.pl now:

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

    First of all, create a small overriding service configuration file:

      sudo systemctl edit openvpn-server@my-server-instance.service

    Then copy and paste the contents of the example override.conf into that file.

    After you are done, "systemctl edit" should have created the following file with those contents:
      /etc/systemd/system/openvpn-server@my-server-instance.service.d/override.conf

    Copy the example my-server-instance.conf to this location:
      /etc/openvpn/server/my-server-instance.conf

    You will need to edit my-server-instance.conf and adjust the port number, IP addresses and so on for your network.

    For Ubuntu 20.04 / easy-rsa version 3, change the 'dh' setting from dh2048.pem to dh.pem, because the filename is different.
    The configuration line should then look like this:
      dh   my-server-instance/dh.pem

    Create this directory:

      /etc/openvpn/server/my-server-instance

    Only 'root' should be able to look inside that directory, because it contains security keys and certificates.
    Tighten access permissions to it with:
      sudo chown root:root /etc/openvpn/server/my-server-instance
      sudo chmod go=-rwx   /etc/openvpn/server/my-server-instance

    Copy certificate files server.crt etc. to that directory.
    The section about creating the certificates lists which files to copy.

    Copy script tap-start-stop.sh to that directory.
        The script needs to be executable:
        chmod u+x tap-start-stop.sh

        Edit the script and amend variables BRIDGE and ETH_INTERFACE.
        If you used the example 99-OurNetplanConfig.yaml to create the network bridge, you will find the names there.

        You can test the script like this:
          brctl show  # Show display no OpenVpnSrvTap.
          sudo ./tap-start-stop.sh start
          brctl show  # The OpenVpnSrvTap should be associated to the network bridge.
          sudo ./tap-start-stop.sh stop
          brctl show  # Show display no OpenVpnSrvTap.

    Tighten permissions on all files inside the directory like this:
      sudo chown root:root /etc/openvpn/server/my-server-instance/*
      sudo chmod go=-rwx   /etc/openvpn/server/my-server-instance/*

  - The OpenVPN server service is managed like any other systemd instantiated service:

    sudo systemctl enable openvpn-server@my-server-instance.service

    # Follow its log output with:
    sudo journalctl --unit=openvpn-server@my-server-instance.service  --follow

    sudo systemctl start openvpn-server@my-server-instance.service

    # At this point, you should inspect the service's log for any indication of trouble.

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

    - When you install OpenVPN, installing the TAP network adapter may take a long time, like several minutes.
      But it does work in the end, so you just have to be patient.

    - Make sure that the TAP network adapter is installed. Otherwise, you will get the following error later on
      when attempting to connect:

        All tap-windows6 adapters on this system are currently in use or disabled

      The OpenVPN client should install the following virtual network adapters:

        Name                    Device Name
        -----------------------------------------------
        OpenVPN TAP-Windows6    TAP-Windows Adapter V9
        OpenVPN Wintun          Wintun Userspace Tunnel

      The method described in this guide only uses the TAP adapter.

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
    However, I had DNS problems with it on Ubuntu 20.04.

  - State that the OpenVPN software should be kept reasonably up to date.
    On Windows, the easiest way is probably with Chocolatey.
    But beware that the Chocolatey package as of March 2022 is no longer automatically installing
    the TAP network adapter, which disqualifies it for the method used in this guide.
    Otherwise, manually upgrading the official client is not hard.

    I have not found an easy way for the server to reject clients older than a given version number.
    In my opinion, this is a security weakness in OpenVPN, because end users will inevitably
    neglect updating the client.

  - Mention that you cannot test the OpenVPN connection from within the OpenVPN server LAN.
    If you smartphone has mobile Internet, you can use its tethering / hot spot function.

  - State that the VPN connection uses the "split tunnel" mode, as opposed to "full tunnel" mode.
    "Split tunnel" means that only traffic to internal computers in the remote company network
    goes through the tunnel, everything else goes to the local network or directly to the Internet.

  - Document the privacy concern that all client DNS queries will be routed to the OpenVPN server network,
    at least on Windows clients. On Linux, if the users chooses to accept the DHCP DNS options,
    then this concern applies too. This means that the company can see all your DNS queries
    when the VPN is active.
    This is a limitation that should not happen in "split tunnel" mode.
    A split DNS configuration is theoretically possible, but not easy, and is not covered in this guide.

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
      After closing the connection (sudo may not be necessary, see the script below):
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
