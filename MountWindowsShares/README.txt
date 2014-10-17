
Script templates to help mount Windows network file shares:

- mount-windows-shares.sh uses the traditional 'mount' method.
  You need to enter your root password every time.
  You could use 'setuid' instead, but then you would have to
  think about possible security risks.

- mount-windows-shares-gvfs.sh uses the GVFS/FUSE method,
  so that you do not need to become root to mount the network shares.
  But you may have to install extra packages and/or adjust your
  system configuration beforehand.

See the scripts' source code for further information.
