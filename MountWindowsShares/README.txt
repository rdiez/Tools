
Script templates to help mount Windows network file shares:

- mount-windows-shares-sudo.sh uses the traditional 'sudo mount -t cifs' method.

  You normally need to enter your root password every time.
  You could use 'setuid' instead, but then you would have to
  think about possible security risks.

  Run with option "sudoers" in order to generate entries suitable for config
  file /etc/sudoers, so that you do not need to type your sudo password every time.
  Look at my nopassword-sudo.sh script in order to edit sudoers comfortably.

  Many Linux kernels used to have problems with SMB mounts. After a period of inactivity,
  CIFS connections were severed, and automatic reconnections often did not
  work properly. Run script keep-windows-shares-alive.sh periodically in order to
  access your shares at regular intervals and prevent this kind of disconnections.
  Note that this workaround should no longer be necessary.


- mount-windows-shares-gvfs.sh uses the GVfs/FUSE method,
  so that you do not need to become root to mount the network shares.
  But you may have to install extra packages and/or adjust your
  system configuration beforehand.

  Warning: I have had a number of problems mit GVfs in the past,
           so I am not actually using this script template anymore.


In order to use the scripts above you will have to amend them first. Find
function user_settings and enter at the end your credentials and the Windows shares
you want to connect to. This is easy to do, just copy and modify the examples above.
You shouldn't need to modify anything else.

Run the script with "unmount" as its first and only argument in order to
disconnect from your Windows shares.

Before mounting or unmounting a network share, these scripts check
whether it is currently mounted or not. If nothing else, these scripts
can serve as code examples on how to parse /proc/mounts and the GVfs/FUSE
mount point directory in a Bash script.

The 'sudo' script variant can automatically open a file explorer on
the just-mounted filesystem for convenience.

See the scripts' source code for further information. The comments at the beginning
contain more detailed information.
