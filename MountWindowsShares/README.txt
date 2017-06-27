
Script templates to help mount Windows network file shares:

- mount-windows-shares.sh uses the traditional 'mount' method.
  You need to enter your root password every time.
  You could use 'setuid' instead, but then you would have to
  think about possible security risks.

  Many Linux kernels have problems with SMB mounts. After a period of inactivity,
  CIFS connections are severed, and automatic reconnections often do not
  work properly. Run script keep-windows-shares-alive.sh periodically in order to
  access your shares at regular intervals and prevent this kind of disconnections.

- mount-windows-shares-gvfs.sh uses the GVFS/FUSE method,
  so that you do not need to become root to mount the network shares.
  But you may have to install extra packages and/or adjust your
  system configuration beforehand.

In order to use a script you will have to amend it first. Edit
function user_settings() and enter the Windows shares you want to connect to.

Run the script with "unmount" as its first and only argument in order to
disconnect from your Windows shares.

Before mounting or unmounting a network connection, these scripts check
whether it is currently mounted or not. If nothing else, these scripts
can serve as code examples on how to parse /proc/mounts and the GVFS/FUSE
mount point directory in a Bash script.

See the scripts' source code for further information.
