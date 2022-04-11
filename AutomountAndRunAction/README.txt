
Automount And Run Action
------------------------

Whenever a new disk is attached, like a USB drive, automount it.
If the disk has a configuration file with the right settings, run some action on it, like creating a backup.

At the end, automatically unmount the disk. Notify the user per e-mail of the start and end of the automatic action.

The configuration files and scripts to implement this kind of feature rely on a udev rule and a systemd service.
This is just a small framework, you have to implement the actual action yourself.

Start by reading the instructions in the .rules file.
