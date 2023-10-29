# rdiez's Tools

This repository contains some tools that I have written over the years. I hope that you find them useful too!

I have invested some extra time into making the tools robust and giving them reasonable help texts. Please send feedback to rdiezmail-tools at yahoo.de

The tools are:

- **[background.sh](Background/)**

    Runs the given command with a low CPU and disk priority, keeps a log file, and
    displays a visual notification or sends an e-mail when finished.

    I could not live without this script anymore.

- **[RunAndWaitForAllChildren.pl](RunAndWaitForAllChildren/)**

    Run the given command and wait for all its child processes to terminate with PR\_SET\_CHILD\_SUBREAPER (Linux only).

- **[FilterTerminalOutputForLogFile.pl](FilterTerminalOutputForLogFile/)**

    Optimise away the carriage return trick often used to update a progress
    indicator in place on the current console text line.

- **[rdchecksum.pl](RDChecksum/)**

    Creates, updates or verifies a list of file checksums (hashes),
    for data corruption or offline file change detection purposes.

    This tool can save a lot of time, because 1) it can update the checksums only for those files
    that have changed in the meantime (according to their 'last modified' timestamps),
    and 2) it can resume an interrupted checksum verification, instead of having to start from
    the first file again.

- **[StartDetached.sh](StartDetached/)**

    Starts a program detached from the console, with its stdout and stderr redirected to syslog.

    Useful when starting graphical applications that should not print to your shell session
    random warnings at inconvenient times, and which should stay running after closing
    the console window (do not automatically get SIGHUP).

- **[xsudo.sh](xsudo/)**

    A simple wrapper for pkexec as a substitute for gksudo.

- **[update-with-apt.sh](UpdateWithApt/)**

    Updates the Ubuntu/Debian system, like the "Software Updater" GUI tool does, but from the command line.

- **[CountdownTimer.pl](CountdownTimer/)**

    A countdown timer, like a kitchen timer for your perfect cup of tea.

- **[DesktopNotification.sh](DesktopNotification/)**

    A little script to display a simple desktop notification.
    I use it for example from KTimer to alert me when a timer has expired.

- **[open-file-explorer.sh](OpenFileExplorer/)**

    Opens a file explorer on the given file or directory.

- **File Read Test**

    The File Read Test tools read disk files or directories and stop on the first read error.
    There are two alternatives to choose from: a Java application (with a point-and-click
    user interface) and a perl script (to use from the command-line).

    This tool has its own website at [http://filereadtest.sourceforge.net](http://filereadtest.sourceforge.net)&nbsp;.

- **Quick Disk Test**

    Quick Disk Test fills a disk with test data and verifies that it can be read back without errors.

    This tool is only available as a Java application. Check out
    its website at [http://filereadtest.sourceforge.net](http://filereadtest.sourceforge.net)&nbsp;.

- **[copy-with-rsync.sh](CopyWithRsync/)** and **[move-with-rsync.sh](CopyWithRsync/)**

    If you often copy around large amounts of data, want to resume interrupted transfers, and can never remember rsync's flags,
    copy-with-rsync.sh should help.

    If you try to move files and subdirectores with 'mv' overwriting any existing ones,
    you may come across the infamous "directory not empty" error message.
    Script move-with-rsync.sh uses rsync to work-around this issue.

- **[Disk Images With Progress](DiskImagesWithProgress/)**

    This is not actually script, but an article about displaying a progress indication
    while creating or restoring disk images, or while wiping a disk.

- **[burn-cd.sh](BurnCd/)**

    You would normally use an application like Brasero to burn CD-ROMs (or DVD-ROMs, etc).
    But sometimes you need to automate the process, so that it is faster or more reliable.

    I found CD burning hard to automate. I hope that this script helps.

- **[mount-windows-shares-sudo.sh](MountWindowsShares/)**

    Script template to help mount Windows/Samba/SMB network file shares with the traditional Linux _sudo mount_ method.

    The script checks whether the filesystem is already mounted, and it can also automatically open
    a file explorer on the just-mounted filesystem for convenience. There is an option to generate
    a configuration line for _sudoers_ to prevent the sudo password prompt every time.

    There is also a variant for GVfs/FUSE, so  that you do not need _root_ privileges, but
    I am not using it because GVfs is problematic, see the comments in the script for more information.

- **[MountMyRamdiskIfNecessary.sh](MountRamDisk/)**

    This script creates and mounts a RAM disk (tmpfs) at a fixed location, if not already mounted.

    A RAM disk can dramatically speed-up certain operations, such as building software with many small files.

- **[Other Mount Scripts](MountScripts/)**

    Other script templates to mount SSHFS, EncFs, WebDAV, etc., and sometimes 2 filesystems stacked (like SSHFS + EncFS).

- **[Automount And Run Action](AutomountAndRunAction/)**

    Whenever a new disk is attached, like a USB drive, automount it.
    If the disk has a configuration file with the right settings, run some action on it, like creating a backup.

    At the end, automatically unmount the disk. Notify the user per e-mail of the start and end of the automatic action.

    The configuration files and scripts to implement this kind of feature rely on a udev rule and a systemd service.
    This is just a small framework, you have to implement the actual action yourself.

- **[diskusage.sh](DiskUsage/)**

    Small convenience wrapper around 'du'.

- **[takeownership.sh](TakeOwnership/)**

    Little convenience script to take ownership of a given file or directory (recursively).

- **[ResetWindowsFilePermissions.bat](ResetWindowsFilePermissions/)**

    Resets file permissions under a given directory on a Microsoft Windows system.

- **[NoPassword scripts](NoPassword/)**

    These scripts help you configure _sudo_ and _polkit_ to stop password prompting
    for the commands or privileged actions of your choice.

- **[Sandboxing Skype](SandboxingSkype/)**

    These scripts help you sandox Skype under Linux.

- **[Office Software Automation](OfficeSoftwareAutomation/)**

    - **PromptAndProcess.vbs (for Windows)**

        Sometimes you need to write a small script that lets a user select a file
        and do some operation on it, like convert it to another format.
        This script provides a full-blown example for a simple file copy operation.

    - **PromptForFile.vbs (for Windows/Cygwin)**

        Prompts the user for a file with Windows' standard "open file" dialog,
        and prints the selected filename to stdout. Useful for Cygwin bash scripts.

    - **ConvertWordToPDFWithBackground.vbs (for Windows)**

        Converts a Microsoft Word document to a PDF file, and then generates a second PDF file
        with extra content in the background (typically a letterhead or watermark) on all pages.

    - **add-letterhead.sh (for Linux)**

        Adds extra content in the background (typically a letterhead or watermark)
        to all pages of a PDF document.

    - **CopyToOldVersionsArchive.vbs (for Windows)**

        Creates an "Archived" subdirectory where the given file resides and copies
        the file there. The current date and time are appended to the archived filename.

    - **copy-to-old-versions-archive.sh (for Linux)**

        Creates an "Archived" subdirectory where the given file resides and copies
        the file there. The current date and time are appended to the archived filename.

- **[Foldable DIN A4 Name Tag for Seminars](FoldableDINA4NameTagforSeminars/)**

    With dotted lines that indicate where to fold the sheet to get a paper triangle
    with your name on it.

- **[Electrical Calculations Spreadsheet](ElectricalCalculationsSpreadsheet/)**

    A simple spreadsheet for Ohm's law and electrical power calculations.

- **[Device Electricity Cost Spreadsheet](DeviceElectricityCostSpreadsheet/)**

    A simple spreadsheet to calculate the electriticy cost of running a device.

- **[Percentage Calculator Spreadsheet](PercentageCalculatorSpreadsheet/)**

    I find this very simple spreadsheet convenient when calculating percentages.

- **[Car Maintenance Checklist](CarMaintenanceChecklist/)**

    A simple checklist to check your car: tyre pressure, engine oil level, and so on.

- **[Phonetic Alphabet](PhoneticAlphabet/)**

    The phonetic alphabet in English and German.

    Helpful if you have to spell complicated words or proper nouns over the phone

- **[Test Bar Codes for the Interleaved 2 of 5 Symbology](TestBarCodes/)**

    Some scanners have difficulty reading bar codes with the Interleaved 2 of 5 symbology.
    I have prepared a LibreOffice Writer document with some bar codes to test the
    scanner's number length and check digit configuration.

- **[VNC/RemoteControlPrompt.sh](VNC/)**

    Helps the user connect to a listening VNC viewer (reverse VNC connection).

    There are other helper scripts in this subdirectory for VNC and remote X11:

    - **vnc-addr-to-clipboard.sh**

        Convenience script to build a reverse VNC connection address.

    - **StartXvncSession.sh**

        Remote Linux desktop with a TigerVNC or TightVNC Xvnc virtual desktop

    - **LinuxDesktopOverSshWithXephyr.sh**

        Remote Linux desktop with X11 over SSH and Xephyr (not actually VNC).

- **[VirtualMachineManager/start-and-connect-to-vm.sh](VirtualMachineManager/)**

    Starts the given Linux libvirt virtual machine, if not already running,
    and opens a graphical console to it with virt-manager.

- **[VirtualMachineManager/set-vm-screen-resolution.sh](VirtualMachineManager/)**

    Resizes the virtual graphics card resolution.

- **[VirtualMachineManager/BackupVm.sh](VirtualMachineManager/)**

    Backs up a virtual machine.

- **[OpenVPN Configuration Guide and Scripts](OpenVPN/)**

    A guide and some scripts to configure OpenVPN in bridging/TAP mode on Ubuntu 18.04 and 20.04.

- **[timecmd.bat](TimeCmd/)**

    Prints the time it takes to run a Microsoft Windows command.

- **[repeat.bat](Repeat/)**

    Cheap clone of _watch_ for Microsoft Windows.

- **[print-arguments-wrapper.sh](PrintArgumentsWrapper/) and [program-argument-printer.pl](PrintArgumentsWrapper/)**

    When writing complex shell scripts, sometimes you wonder if a particular process is getting the right arguments and the
    right environment variables. Just prefix a command with the name of this script, and it will dump all arguments and
    environment variables to the console before starting the child process.

- **[RunAndReport.sh](RunAndReport/)** and **[GenerateHtmlReport.pl](RunAndReport/)**

    Generates a report table with all commands executed and their succedded/failed status.
    You can then drill down to the command log files.

- **[WaitForTcpPort.sh](WaitForTcpPort/)**

    Wait until a listening TCP port is available on a remote host.

- **[WaitForSignals.sh](WaitForSignals/)**

    Waits for Unix signals to arrive.
    This script is mainly useful during development or troubleshooting of Linux processes.

- **[pipe-to-clipboard.sh](PipeToClipboard/)**

    Helps you pipe the output of a shell command to the X clipboard.

    In case of a single text line, it automatically removes the end-of-line character.

- **[path-to-clipboard.sh](PipeToClipboard/)**

    Places the absolute path of the given filename in the X clipboard.

- **[pipe-to-emacs-server.sh](PipeToEmacs/)**

    Helps you pipe the output of a shell console command to a new emacs window.

- **[run-in-new-console.sh](RunInNewConsole/)**

    Runs the given shell command in a new console window.

- **[RotateDir.pl](RotateDir/)**

    If you keep running a process that generates a big directory tree every time (like building a compiler toolchain
    overnight), and you only want to keep the most recent file trees, this directory rotation tool will automatically prune
    the older ones for you.

- **[create-temp-dir.sh](CreateTempDir/)**

    Create a temporary working directory in a standard place, with a recognisable name pattern,
    and open it automatically for convenience.

- **[AnnotateWithTimestamps.pl](AnnotateWithTimestamps/)**

    Prints a text line for each byte read, with timestamp, time delta,
    byte value and ASCII character name.

    Useful when troubleshooting data timing issues.

- **[LogPauseDetector.pl](LogPauseDetector/)**

    When inspecting logs in real time with a command like `tail -F /var/log/syslog`,
    I have developed a habit of pressing the Enter key in order to separate the old
    text lines from the new ones the next event will generate.

    This script automates such a visual separation of log line groups. When a pause
    is detected, the pause duration is inserted surrounded by empty lines.

- **[PadFile.sh](PadFile/)**

    This tool copies a file and keeps adding the given padding byte at the end
    until the specified file size has been reached.

- **[GenerateRangeMappingTable.pl](GenerateRangeMappingTable/)**

    Generates a mapping table (a look-up table) between an integer range
    and another numeric range (integer or floating point).
    The mapping can be linear or exponential.

- **[ConvertBitmapToSourceCode.pl](ConvertBitmapToSourceCode/)**

    Converts a bitmap in Portable Pixmap format (PPM) format, monochrome or RGB565, into a C++ array. RGB565 is a very popular 16-bit color depth format among small hardware devices.

- **[decode-jtag-idcode.pl](DecodeJtagIdcode/)**

    Breaks a JTAG IDCODE up into fields as specified in IEEE standard 1149.1. Example output:

        % perl decode-jtag-idcode.pl 0x4BA00477
        Decoding of JTAG IDCODE 0x4BA00477 (1268778103, 0b01001011101000000000010001110111):
        Version:      0b0100  (0x4, 4)
        Part number:  0b1011101000000000  (0xBA00, 47616)
        Manufacturer: 0b01000111011  (0x23B, 571)  # Name: ARM Ltd.
        Leading bit:  1  # Always set to 1 according to the IEEE standard 1149.1

- **[FindUsbSerialPort.sh](FindUsbSerialPort/)**

    Finds the device file associated to a USB virtual serial port. You can search
    for any combination of USB Vendor ID, Product ID, Serial Number, etc.

- **[RunBundledScriptAfterDelay.sh](RunBundledScriptAfterDelay/)**

    Changes to the directory where this script resides, resolving any symbolic links
    used to start it, and runs another script after the given delay. Useful to
    start delayed tasks from KDE's braindead "autostart" feature. Otherwise,
    you'll have to write a little script with the right full path and an eventual
    _sleep_ statement every time.

- **[email-news-feeds.sh](EmailNewsFeeds/)**

    Helper script to automatically run tool 'rss2email' after every login, in order to get your news
    conveniently delivered to your mailbox.

- **[script-speed-test.sh](ScriptSpeedTest/)**

    Simple script template to measure how long it takes to run some test script code
    a given number of iterations.

- **[StressTest/synthetic-task.sh](StressTest/)**

    Helps you create simple, dummy computing tasks that run in a given number of child processes for a given number of iterations.
    Useful for load testing.

- **[StressTest/consume-memory.pl](StressTest/)**

    Helps you simulate a process that consumes the given amount of memory.

- **[StressTrash.sh](StressTrash/)**

    Stresses the system trash (recycle bin).

- **[build-xfce.sh](Xfce/)**

    Downloads and builds Xfce from source.

- **[unpack.sh](Unpack/)**

    Conveniently and safely unpacks an archive (zip, tarball, ISO image, etc) into a subdirectory.

- **[DownloadTarball.sh](DownloadTarball/)**

    Reliably downloads a tarball by checking its integrity before
    committing the downloaded file to the destination directory.

- **[DownloadAndBuildAutotools.sh](Autotools/)**

    Downloads, builds and installs any desired versions of the GNU autotools (autoconf + automake + libtool).

- **[SendRawEthernetFrame.py](SendRawEthernetFrame/)**

    Sends a raw Ethernet frame. Useful for testing purposes.

- **[BackupFiles](BackupFiles/)**

    Script templates to help backup files and test the backups.
    There are also scripts for updating file mirrors for online backup purposes.

- **[BackupWikiPages.sh](BackupWikiPages/)**

    Downloads a set of Wiki pages in several formats from a MediaWiki server.

- **[RecompressSelectively.sh](RecompressSelectively/)**

    Template script to selectively recompress archive files (like zip files) across subdirectories.

- **[CheckIfAnyFilesModifiedRecently.sh](CheckIfAnyFilesModifiedRecently/)**

    Helps implement an early warning if a directory has not been updated recently as it should.

- **[watchdog.sh](Watchdog/)**

    This script runs a user command if the given file has not been modified in the last x seconds.

- **[timestamp.sh](Timestamp/)**

    Determine the highest modification time of all given files or directories.
    This helps write makefiles that must check large directory structures.

- **[view-pod-as-html.sh](ViewPodAsHtml/)**

    Checks that the POD (Perl's Plain Old Documentation markup) syntax is OK,
    converts it to HTML and opens it with the standard Web browser.

- **[ReplaceTemplatePlaceholderWithFileContents.sh](ReplaceTemplatePlaceholders/)** and **[ReplaceTemplatePlaceholders.sh](ReplaceTemplatePlaceholders/)**

    These tools read a template text file and replace all occurrences
    of the given placeholder strings with the contents of another file
    or with the given command-line arguments.

- **[CheckVersion.sh](CheckVersion/)**

    Helps generate an error or warning message if a given version number
    is different/less than/etc. compared to a reference version number.

- **[TidyUrl.sh](TidyUrl/)**

    Downloads the given URL to a fixed filename under your home directory,
    and runs HTML _tidy_ against it for lint purposes.
    It can also lint CSS with _stylelint_.

- **[ptlint.pl - a Plain Text Linter](PlainTextLinter/)**

    A basic linter for plain text files.

- **[ImageTools](ImageTools/)**

    - **WebPictureGenerator.sh**

        Generates pictures for a web site from high-resolution photographs.
        Processing steps are cropping, scaling, watermarking, removing all EXIF information and
        adding copyright information as the only EXIF data.

    - **TransformImage.sh**

        Crops and/or resizes a JPEG image with ImageMagick or jpegtran.
        The resulting image is optimised in order to save disk space.

- **[Git Helper Scripts](Git/)**

    - **clean-git-repo.sh**

        Reverts the working directory to a pristine state, like after doing
        the first "git clone" (which is rather destructive).

    - **git-revert-file-permissions.sh**

        Git stores the 'execute' file permission in the repository, but permissions get sometimes lost
        when copying files around to/from Windows PCs or FAT/FAT32 disk partitions.
        This script restores all file permissions to their original values in the Git repository.

    - **git-stash-only-staged-changes.sh** and **git-stash-only-unstaged-changes.sh**

        git-stash-only-staged-changes.sh stashes only the changes in the stage/index. It is
        useful if you are in the middle of a big commit, and you just realised that
        you want to make a small, unrelated commit before the big one.

        git-stash-only-unstaged-changes.sh stashes only the changes in the working files
        that are not in the stage/index. Useful to test that your next commit compiles cleanly,
        or just to temporarily unclutter your workspace.

    - **pull.sh**

        Use instead of "git pull" in order to prevent creating unnecessary merge commits
        without having to remember git commands or options.

- **[zram Statistics](Zram/)**

    Displays some system memory statistics specifically aimed at [zram](http://en.wikipedia.org/wiki/Zram) swap partitions.

    Later note: This script probably does not work on recent Linux kernel versions.

- **[Fake Replacement for Debian Package _apt-xapian-index_](FakeReplacementForAptXapianIndex/)**

    It is well known (as of may 2014) that _update-apt-xapian-index_ consumes loads of
    memory and can easily render a computer with only 512 MiB of RAM unusable.

    This fake APT package helps get rid of the whole _apt-xapian-index_ package in Ubuntu
    or Debian systems without collateral dependency damage.

- **[_mlocate_ Conflicting Package](MlocateConflictingPackage/)**

    The _locate_ background indexer can grind your Linux PC to a halt every now and then for several minutes at a time.

    Install this package to prevent Debian packages _locate_, _mlocate_ and _plocate_ from ever being installed again.

- **[SnapUpgradeFirefoxChromium.sh](SnapUpgradeFirefoxChromium/)**

   This script helps manually upgrade the Snaps for both Firefox and Chromium upon seeing
   this annoying prompt under Ubuntu 22.04:

        Pending update of "firefox" snap
        Close the app to avoid disruptions (4 days left)

Most tools are licensed under the AGPLv3, see file [agpl-3.0.txt](agpl-3.0.txt) for details.

Use script [GenerateLinks.sh](GenerateLinks.sh) to place symbolic links to the most-used scripts
into a directory of your choice (which is normally your personal 'Tools' or 'Utils' directory in the PATH).
