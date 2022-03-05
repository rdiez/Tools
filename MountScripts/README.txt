
mount-sshfs.sh and mount-my-sshfs-server.sh
  Conveniently mount and unmount with SSHFS.

mount-gocryptfs.sh and mount-my-gocryptfs-vault.sh
  Conveniently mount and unmount a gocryptfs encrypted filesystem.
  This can be used for example to encrypt files on a USB stick or a similar portable drive.

mount-stacked.sh
  Mount one filesystem, and then another one on top of it.
  For example, mount first with SSHFS for basic file services, and then
  with gocryptfs for data encryption.


--- Deprecated script templates ---

mount-encfs.sh
  Conveniently mount and unmount an EncFS encrypted filesystem.
  Nowadays it is better to use gocryptfs instead.

mount-strato.sh
  An older script only kept for future reference. It can mount ( SSHFS or davfs2 )
  and then EncFS on top.
