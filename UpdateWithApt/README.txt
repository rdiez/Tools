
update-with-apt.sh

Updates the Ubuntu/Debian system, like the "Software Updater" GUI tool does, but from the command line.

This is not trivial to do. The GUI updater uses a few APT tricks, and I had to invest
quite a lot of time to do the same with a script. This effort should not have been necessary,
for the system (or APT) should provide something equivalent.

If a "snap" tool is found, it also upgrades all Snap packages.

I normally recommend closing all applications before upgrading the system, whether with this script
or with other means. You can never be certain that running applications are robust enough
to avoid corruption if an upgrade is performed in the background.

Possible command variations:
  update-with-apt.sh shutdown
  update-with-apt.sh reboot
  update-with-apt.sh dry-run
