
WaitForTcpPort.sh version 1.00
Copyright (c) 2022 R. Diez - Licensed under the GNU AGPLv3

This script waits until a listening TCP port is available on a remote host,
by repeatedly attempting to connect until a connection succeeds.

Syntax:
  WaitForTcpPort.sh  [options...]  <hostname>  <TCP port>

  The hostname can be an IP address.

  Instead of a TCP port number, you can specify a service name like 'ssh' or 'http', provided that your
  system supports it. The list of known TCP port names is usually in configuration file /etc/services .

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently 1.00)
 --license  prints license information

 --global-timeout=n      Set a time limit for the whole wait operation, in seconds.
                         The minimum value is 1 second.
                         By default, there is no global timeout, so this
                         script will keep retrying forever.

 --connection-timeout=n  Set a time limit for each connection attempt, in seconds.
                         The minimum value is 1 second.
                         By default, there is no connection timeout. The system will provide
                         a default which may be too long for your purposes.

 --retry-delay=n         How long the pause between connection attempts should be, in seconds.
                         The default is 2 seconds.
                         0 means no delay, which is often a bad idea.

The number of seconds in some options must be an integer number.

Usage example:
  $ ./WaitForTcpPort.sh  --global-timeout=60  --connection-timeout=5  example.com  80

Rationale:

  The only way to check whether a listening TCP port is reachable is to actually connect to it,
  so the server will see at least one short-lived connection which does not attempt to transfer any data.
  Normally, TCP servers do not mind, but such futile connections may show up on the server's error log.

  Specifying a connection timeout is highly recommended. Without it, you do not really know
  how long a connection attempt may take to fail. Depending on the system's configuration,
  and on the current network problems, it can take minutes.
  External tool 'timeout' is used to wrap each connection attempt,
  so it needs to be available on this system.

  The optional global timeout is implemented with the system's uptime, so it is not affected
  by eventual changes to the real-time clock.

  The global timeout may be longer than specified in practice, because this script will
  not shorten the connection timeout on the last attempt before hitting the global timeout.
  Therefore, if the connection timeout is 3 seconds, the pause between attempts is 1 second, and the
  global timeout is 5 seconds, then the global timeout will effectively be extended to 3 + 1 + 3 = 7 seconds.

  The global timeout may also be shorter than specified in practice, because this script will stop
  straightaway if the global timeout would trigger during or right after the pause between attempts.
  Therefore, if the connection timeout is 3 seconds, the pause between attempts is 1 second, and the
  global timeout is 4 seconds, then there will be only 1 connection attempt, and the global timeout
  will effectively be shortened to 3 seconds.

  The logic that handles the timeouts and the uptime has a resolution of 1 second,
  so do not expect very accurate timing. Therefore, when using a global timeout,
  there may be 1 more or 1 less connection attempt than expected.

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de
