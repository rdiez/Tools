
RemoteControlPrompt.sh

  Helps the user connect to a listening VNC viewer.
  See the script's source code for more information.


StartXvncSession.sh

  Remote Linux desktop with a TigerVNC or TightVNC Xvnc virtual desktop.


LinuxDesktopOverSshWithXephyr.sh

  Remote Linux desktop with X11 over SSH and Xephyr (not actually VNC).


vnc-addr-to-clipboard.sh

  This script finds out this computer's public IP address (using a public service)
  and places in the clipboard a connection address that your partner can use
  in order to start a reverse VNC connection to this computer.

  You can optionally define an address suffix in case you have set up
  a 55xx VNC port forward on the Internet router.

  Run the script with command-line option "--help" for more information.

  This script is just for convenience, as you can always manually find out
  your public IP address and build such a reverse VNC connection string yourself.
