# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.2] - 2023-02-12

### Added

- [core] prometheus metrics for backup status

### Changed

- [borg] don't hardcode ssh port default (DEBBUG-993951)
- [core] allow for disabling reports by email

### Fixed

- [borg] fix borg example: set cache_directory to source section
- [dup] actually run duplicity `remove-older-than` (#11345)
- [dup] remove default duplicity option `--extra-clean` (#11335)
- [dup.helper] re-add a version of the do_dup_src function (#11332)
- [restic] restic handler doesn't initialize test variable (#11328)
- [sys] remove old LUKS header backup file prior to regenerating (#11333)
- [sys] don't cancel partition backup if hwinfo absent (#11333)
- [tests] fixes and improvements

## [1.2.1] - 2021-01-25

### Added

- [core] implement `reportwrap` configuration parameter

### Changed

- [core] raise error if mail isn't found in `$PATH` and `reportemail = yes`
- [core] unset `BACKUPNINJA_DEBUG` before exit

### Fixed

- [build] make build reproducible regardless of usrmerge (DEBBUG-915222)
- [core] silence exit code message unless `--debug` is used
- [core] backup halt should trigger email report if enabled
- [core] wrap report email body to 1000 characters by default (DEBBUG-871793)
- [core] improve error handling around `reporthost` feature
- [docs] add missing parameters to `backupninja.conf` manpage
- [sys] improve device selection for MBR backup (#11303)

## [1.2.0] - 2021-01-21

### Fixed

- [dup] Fix missing options from config file created with helper (DEBBUG-726119)

## [1.2.0-rc1] - 2021-01-14

### Added

- [tests] Add a testsuite
- [core] Add `--version` (`-V`) command-line option
- [borg] New config options: `cache_directory`, `sshoptions` (#11310),
  `ignore_missing` and `port`
- [restic] Introduce new handler for the restic backup program
- [sys] Add SystemD and EFI infos to sytem report (#11325)
- [all] Added new config setting `ionicelevel` (DEBBUG-409239)

### Changed

- [core] Implement non-zero exit codes for main process (#8279)
- [borg] Emit warning if borg returns exit code 1 instead of fail
- [dup] Allow `bandwidthlimit` with `desturl`
- [rsync] Change default ssh key file to RSA in `id_file` (#11315, DEBBUG-976650)
- [project] Adopt Keep a Changelog format and convert old ChangeLog to markdown
- [project] Moved project group from RiseupLabs to Liberate (#11314)

### Removed

- [core] Support for vservers support has been completely removed
- [rsync] Removed unused config parameter `ssh` (#4379)

### Fixed

- [core] Fix issue with zero-padded integers in when setting (#9397)
- [core] Fix incorrect warning related to day component in when setting
  (DEBBUG-974770)
- [borg] Fix connection test when empty remote directory exists
- [borg] Properly quote create_options setting (#11304)
- [borg] Raise fatal error if includes are missing
- [dup] Test ssh connection when test mode enabled
- [mysql] Fix helper writing incomplete config file (#11272)
- [rsync] Fix initial directory creation in `mirror` and remote `short` modes
- [sys] Fix LUKS version 2 header backup (#11316)
- [sys] Fix dumping non-existent partition tables (#11293, DEBBUG-956206)
- [sys] Fix error in rc.d info gathering on redhat/centos (##11294)
- [sys] Fix error in sysctl info gathering

## [1.1.0] - 2018-06-29

### backupninja changes

- Add validation check for when parameter. (#640) Thanks to ulrich
  <ulrich@habmalnefrage.de> for the patch.
- Quote output strings passed to logging functions (#11278).
- Ignore files in /etc/backup.d that lack suffix. Thanks to David Gasaway
  <dave@gasaway.org> for the patch.
- Add Vagrantfile to help with testing/release process.

### documentation changes

- Fix typos in README.md and manpages. Thank you, Lintian!
- Improve release process documentation.

### handler changes

#### borg

- Add initial support for the borgbackup program. Thanks to Ben
  <ben@wainei.net> and Thomas Preissler <thomas@preissler.co.uk> for
  contributing patches.

#### dup

- Fix symmetric encryption. (#11274) Thanks to Matthijs Wensveen
  <matthijs.wensveen@gmail.com> for the patch.
- Bail if archive dir doesn't exist. (#11286) Thanks to Hugh Nowlan
  <nosmo@nosmo.me> for the patch.

#### sys

- Use lsblk instead of sfdisk to get a list of block devices. (#11273)
  Thanks to Romain Dessort <romain@univers-libre.net> for the patch.
- Avoid looking for partitions on zram devices. Thanks to Glandos
  <bugs-0xacab@antipoul.fr> for the patch.
- Support extracting LUKS headers from partitions. Thanks to Lyz
  <lyz@riseup.net> for the patch.

## [1.0.2] - 2017-09-05

### handler changes

#### dsync

- Miscellaneous improvements to this experimental handler.

#### dup

- For local backups, check that the destination directory exists.  Thanks to
  ulrich for the preliminary patch. (#4049)
- Gracefully handle legacy spaces between -o and IdentityFile.
- Don't remove useful signature files with --extra-clean, on duplicity versions
  that have a sane handling of the cache.  Thanks to Alexander Mette
  <mail@amette.eu> for the patch!  (Closes: #6357)
- Fix buggy version comparison. (#6746)
- Support using a different passphrase for the signing key from the one used
  for the encryption key (Closes: DEBBUG-726072).  Thanks to Dominik George
      <nik@naturalnet.de> for the patch!
- Run duplicity in a C locales environment (Closes: DEBBUG-736280).  Thanks to
  Jonathan Dupart <jonathan@dupart.org> for the report, and the initial patch!
- Fix handling of Dropbox access token (Closes: #11260).

#### mysql

- Make "nodata" option compatible with compress=no.
- Fix non-qualified table name extraction. (Closes: #4373)
- Skip dumping information and performance\_schema databasase.  (Closes:
  #11148)

#### rdiff

- Add option to include rdiff-backup output in reports.  Thanks to David
  Gasaway <dave@gasaway.org> for the patch!

#### rsync

- Solve quoting issue with "su". (Closes: DEBBUG-683731, #4019)
- Update increment folder date to avoid ending up with contradictory
  information. (Closes: #3929)
- Force rsync handler run bash at the remote destination.  (Closes:
  #3003)
- Support running in test mode (Closes: #8196).  Thanks to shred for the
  initial patch.

#### sys

- Fix LUKS header backup to properly detect partitions.
- Provide the ability to backup the MBR for every device found, and to backup
  the BIOS (if the flashrom program is installed, and the mainboard is
  supported).
- Add suse to the list of supported OS (#7101).  Thanks to Christian
  Prause <cprause@suse.com> for the patch.
- Fix indentation. Thanks to Jools Wills <jools@oxfordinspire.co.uk> for the
  patch. (Closes: #6802)
- Exclude tmpfs filesystems from df output. (Closes: DEBBUG-745818)

#### tar

- Support test mode and xz compression.  Thanks to Pierre ROUDIER
  <contact@pierreroudier.net> for the patches.

### helper changes

#### rdiff

- Don't give misleading information regarding required fields.  (#4410)
- Support output\_as\_info.  Thanks to David Gasaway <dave@gasaway.org> for the
  patch!

#### sys

- Remove spurious quotes that broke the helper (Closes: #6803).  Thanks
  to Jools Wills <jools@oxfordinspire.co.uk> for the patch.

### backupninja changes

- Indentation fixes, thanks to exobuzz. (#6726)
- Ignore jobs whose filename ends with "~".  Thanks to Mark Janssen
  <mark@sig-io.nl> for the patch.

#### build system changes

- Pass the "foreign" option to AM\_INIT\_AUTOMAKE: README has been renamed to
  README.md.

### documentation changes

- Update INSTALL file to add some missing recommended programs.
- Document release process.
- Merge FAQ content from the Redmine wiki into the one shipped with
  backupninja.
- README.md: reorganize, reformat, and point to the examples configuration
  files.
- INSTALL.md: recommend using packages on Debian and derivatives.
- bandwidthlimit for the dup handler needs to be given in KB/s, and not (as
  wrongly advertised previously) in Kbit/s.  (Closes: #7603)

## [1.0.1] - 2012-06-29

### handler changes

#### rsync

- Issue warnings, not fatal errors, on non-fatal rsync errors.  (#3966)

## [1.0] - 2012-06-15

The "happy birthdays" release!

### handler changes

#### mysql

- Use --skip-events when backing up the performance_schema database.  (Closes:
  DEBBUG-673572)

#### rsync

- Generate excludes command-line snippet the same way as the duplicity handler
  does.
- Run rsync command-line through a shell, so that single-quotes around excludes
  are interpreted (Closes: DEBBUG-677410)

#### sys

- Don't execute /usr/bin/lspci or /sbin/modinfo when $hardware == "no"

### backupninja changes

- Make it clear what lockfile could not be acquired, if any.

## [1.0-rc1] - 2012-05-15

### handler changes

#### dup

- Make the .dup generated by ninjahelper more consistent with example.dup.
- Add support for RackSpace's CloudFiles.  Thanks to Yuval Kogman
  <nothingmuch@woobling.org> for the patch.
- Adapt for new duplicity SSH backend.  Support bandwidthlimit with new
  duplicity, using trickle.  (Closes: DEBBUG-657201)
- Report failure output at error loglevel so that it is emailed (Closes:
  DEBBUG-536858)

#### maildir

- Remove 'loadlimit' parameter - it is not used anywhere.

#### mysql

- Don't attempt to dump performance_schema database (#3741).

#### pgsql

- Don't produce empty uncompressed backups (#3820).

#### rdiff-backup

- Use fatal function to report failure of rdiff-backup jobs as such.

#### rysnc

- Fix numericids option (#3691).
- Mangle $rsync_options just afterwards (#3702, #3001).
- Fix metadata rotation.
- Allow disabling rotation or setting 2 days as minimum for backup increments
  in rsync short format (#2107).
- Abort on rsync error (#3692).
- Cleanup orphaned metadata (#3727).
- Use the backup start time and not the time the backup was finished.  (Closes:
  DEBBUG-654192).
- Use 'debug', 'fatal' and 'warning' functions instead of regular echo and exit
  (#3840, #3721).
- Quoting $starttime (#3868).
- Validate created date on long_rotation to avoid too many arguments at
  comparison (#3868).
- Quoting $exclude and $excludes and avoiding a for loop on $exclude to not
  expand wildcards in beforehand (#3882).
- Quote excludes (#3882).
- Changing remaining 'exit' to 'fatal' at rsync handler (#3721).
- Removing duplicated locking support (#3838).
- Documenting rotation parameters at example.rsync (#3891).
- Ensure that a non-zero rsync exit status is caught (#3892).

#### build system changes

- Workaround automake sanity check that would prevent us from installing lib/\*
  into lib/backupninja/. Where else are be supposed to install such files
  anyway?
- Have "make dist" ship handlers/\*.in instead of make results.
- Have "make dist" ship the FAQ.
- Install handlers as pkgdata_DATA, instead of their .in files.

### documentation changes

- Document what features available to .sh jobs (Redmine #1558).

## [0.9.10] - 2011-09-23

### backupninja changes

- Fix email reports, that were broken by the new locking support.

### handler changes

#### dup

- Cleanup: stop supporting duplicity < 0.6.01 (#2538).
- Fix incorrect duplicity version check for keepincroffulls.  Thanks to Olivier
  Berger <oberger@ouvaton.org> for the patch.  (Closes #3443)
  (Closes: DEBBUG-641120)

#### ldap

- Don't install LDAP handler, helper and example configuration file.  Don't
  mention LDAP support in documentation.  Official LDAP support will come back
  once this code has found itself a maintainer. Interested? Get in touch!

#### rsync

- Fixing $rsync_options output when rsync is local (Closes #3001)
  (Closes: DEBBUG-639545)

#### sh

- Allow 'when = XXX' with spaces (#2769).  Thanks to aihtdikh for the
  patch.

#### sys

- Remove useless and inconsistent executable bit on handler.

### helper changes

#### rdiff

- Fix infinite loop when version inconsistency is detected.  Thanks to Chris
  Lamb <lamby@debian.org> for the patch.  (Closes: DEBBUG-639547)

## [0.9.9] - 2011-05-15

### backupninja changes

- Use locking to avoid running concurrent instances of the same backup action.
  Thanks to Olivier Berger <oberger@ouvaton.org> for the patch.  (Closes:
  DEBBUG-511300)

### handler changes

#### all handlers:

- Stop using "local VAR" outside functions. (Closes: DEBBUG-530647)

#### dup

- Use --tempdir option rather than TMPDIR environment variable.  (Closes
  Roundup bug #598)
- Remove support for duplicity < 0.4.4. Even etch-backports has a newer one.
- Now support remove-all-inc-but-n-full command for duplicity >= 0.9.10 to
  allow removal of increments for older full backups.  Thanks to Olivier Berger
  <oberger@ouvaton.org> for the patch.  (Closes #2492) (Closes:
  DEBBUG-603478)

#### ldap

- Fix reliance on bash for pipefail.

#### mysql

- Fix reliance on bash for pipefail.  Thanks to Sergio Talens-Oliag
  <sto@debian.org> for the patch.  (Closes: DEBBUG-602374)

#### postgresql

- Support various pg_dump formats in addition to pg_dumpall.  Thanks to Jacob
  Anawalt <jlanawalt@gmail.com> for the patch.  (Closes Roundup bug #2534)
- Fix reliance on bash for pipefail.

#### rdiff

- Support reading include/exclude patterns from files using the "include
  @/etc/backup_includes" syntax (Closes Roundup bug #2370). Thanks to ale for
  the patch.

#### rsync

- Fix long rotation.
- Make units clearer (Closes #2737)
- Do arithmetic using bash rather than bc (Closes: DEBBUG-603173)

#### sys

- Fix hwinfo (Closes: DEBBUG-625501)
- Fix gathering of information about loaded modules: cut is in /usr/bin
  actually.

#### tar

- Install by default. (Closes #2907)

### helper changes

#### dup

- Fix separate signing key usecase. Thanks to Ian Beckwith for the patch.
- Make units clearer (Closes #2737)

#### rdiff

- Generate 4096 bits RSA keys.

#### tar

- Install by default. (Closes #2907)

### documentation changes

- Recommend using 4096 bits RSA keys everywhere.

## [0.9.8.1] - 2010-10-31

### backupninja changes

- Do not error out when no job is configured. Thanks to Jordi Mallach
  <jordi@debian.org> for the patch (Closes: DEBBUG-597684)

### handler changes

#### sys

- Route around broken vgcfgbackup not able to handle multiple VG arguments

## [0.9.8] - 2010-09-12

### backupninja changes

- Added GZIP_OPTS option, defaulting to --rsyncable, so that this option can be
  disabled on systems that don't support it. This also allows to use another
  compression program, such as pbzip2 on SMP machines (Closes Roundup bug
  #2405)

### handler changes

#### sys

- Only run mdadm if RAID devices actually exist (Closes: DEBBUG-572450)

#### dup

- Now default to use --full-if-older-than; see the new "increments" option to
  opt-out or tweak the default (30D) delay between full backups. Thanks a lot
  to Olivier Berger (Closes: DEBBUG-535996)
- Use duplicity's --extra-clean option to get rid of unnecessary old cache
  files when cleaning up. This is enabled when using duplicity 0.6.01 or newer,
  that depends on local caching (Closes: DEBBUG-572721)
- Ignore anything but digits and "." when comparing versions (Closes: DEBBUG-578987)
- Put archive directory (cache) into /var/cache/backupninja/duplicity rather
  than the default /root/.cache/duplicity, unless the user has specified it
  (Closes: 580213)
- Better example.dup documentation. Thanks, Alster!
- Added ftp_password option to securely transmit the FTP password from
  backupninja to duplicity.

#### mysql

- Don't lock tables in the information_schema database (Closes: DEBBUG-587011)
- Fix code logic to make dbusername/dbpassword actually usable (Closes Redmine
  bug #2264)

#### rsync

- Fix lockfile checks. This prevents multiple instances of the same rsync job
  to run in parallel.
- Avoid passing the remote user twice to rsync-over-ssh.

### doc changes

#### manpage

- Fix typo in manpage (Closes: DEBBUG-583778)

#### ldap

- Add ssl option description, fix tls option description (Closes Roundup bug
  #2407)

## [0.9.7] - 2010-01-27

### backupninja changes

- fix bug in reportspace, thanks Dan Garthwaite
- do not assume English locale when using date (Closes: DEBBUG-465837)
- add 'when = manual' option, that can be used in the global config file or in
  a given backup action file. Thanks Tuomas Jormola for the preliminary patch
  (Closes: DEBBUG-511299)
- new reportinfo option: when set, messages sent by handlers with "info" are
  included in the report e-mail (closes DEBBUG-563734)
- reportspace: skip non-directories and places that don't exist on the local
  filesystem (Closes: DEBBUG-536049)
- set BACKUPNINJA_DEBUG when invoked with -d (Closes: DEBBUG-537266)

### lib changes

#### easydialog

- Allow form fields input to grow up to 100 chars (Closes: DEBBUG-562249)

### handler changes

#### ldap

- Use gzip's --rsyncable option.
- Use bash pipefail option when needed so that failed dumps are reported as
  such.

#### maildir

- fix location of deleted_on file
- add missing destid_file options to ssh connections
- added sshoptions variable for arbitrary ssh options
- updated example file to include destid_file, destport and sshoptions
- use any subdirectories not just "a" to "z". Thanks Chris Nolan! (#606)

#### mysql

- Options passed to mysqldump are now customizable with the new sqldumpoptions
  configuration variable. Thanks to Chris Lamb for his preliminary patch
  (Closes: DEBBUG-502966)
- Hide 'mysqladmin ping' output, to prevent confusing the user in case mysqld
  is running but the authentication fails, which apparently does not prevent
  mysqldump to work.
- Fix the error message displayed when mysqld is not running: mysqladmin ping
  indeed returns 0 when authentication fails.
- Use gzip's --rsyncable option.
- Quote output filenames to support shell meta-characters in database names.
- Use bash pipefail option when needed so that failed dumps are reported as
  such.

#### pgsql

- Use gzip's --rsyncable option.
- Quote output filenames to support shell meta-characters in database names.
- Use bash pipefail option when needed so that failed dumps are reported as
  such.

#### rdiff

- Fix include/exclude paths with spaces (Closes: DEBBUG-398435)
- Fix confusing error if rdiff-backup cannot be found on remote server.
- Increased element number in include/exclude and vserver ninjahelper interface

#### sys

- New luksheaders option (default=disabled) to backup the Luks header of every
  Luks device.
- New lvm option (default=disabled) to backup LVM metadata for every detected
  volume group.
- Backup dmsetup info as well, for easier restoring of Luks headers.

#### dup

- Fixed bandwidthlimit syntax error. Thanks to Ian Beckwith for the patch.
- Send duplicity output to debug line by line instead of as a whole at one time
  (Closes: DEBBUG-536360)
- Report duplicity output as "info" so that it can be included in report e-mail
  when reportinfo is on (Closes: DEBBUG-563734)
- Fix include/exclude paths with spaces
- Support backups to Amazon S3 buckets, thanks to stefan for the patch.

### helper changes

#### dup

- Do not propose to exclude /home/\*/.gnupg twice anymore (Closes: DEBBUG-563044)

### autotools

- Added the stat command to the automagically replaced ones, hoping it will
  help supporting \*BSD some day.

## [0.9.6] - 2008-07-21

### backupninja changes

- fix bug in cstream definition, thanks Jamie McClelland
- Allow the entire backup run to be halted by an action, thanks to Matthew
  Palmer (Closes: DEBBUG-455836)
- Fixed tr construct reporting a warning (Closes: DEBBUG-452669)

### lib changes

#### vserver

- added vservers_running function

#### tools

- mktemp is now required to run backupninja, removed less secure fall-back if
  mktemp did not exist on the system

### handler changes

#### dup

- General cleanup
- Better support for new duplicity (>= 0.4.4) command line syntax: run
  remove-older-than when $keep is not set to yes (Closes: DEBBUG-458816), and run
  "duplicity cleanup" before any other duplicity command; both only trigger a
  warning on failure, since they should not stop backups from being done. Also
  migrated full/incremental backup switch to the new syntax.
- Support every duplicity-supported transport with new configuration option
  desturl (Closes: DEBBUG-483712, DEBBUG-346040, Trac#2).
- Actually allow to backup only VServers, by relaxing $include test.
- Set secure permissions on tmpdir when creating it.

#### ldap

- support HDB backend just as the BDB one, and make message clearer when no
  supported backend is found (Closes: DEBBUG-476910)

#### rdiff

- Fixed ignore_version default value missing
- Add patch from Matthew Palmer to rdiff handler to incorporate sshoptions into
  options via remote-schema not already specified (Closes: DEBBUG-424639)

#### wget

- New handler from rhatto designed to incrementally pull content from a website
  to a local folder, based on the rsync handler

#### maildir

- fixed bug where maildirs that start with a number were skipped
- make maildir helper look in every subdirectory of the source directory for
  maildirs, rather than just looking in the directories [a-zA-Z0-9], thanks for
  the patch from chris@cenolan.com (Trac#43).
- make deleted maildirs record the date they were deleted
- add destid_file configuration option to enable you to specify an alternate
  ssh public key authentication file (defaulting to /root/.ssh/id_rsa) pgsql,
  mysql, svn, sys:
- use new vservers_running function from lib/vserver (factorization++)

#### sys

- update for 2.6 kernels: use /proc/kallsyms instead of /proc/ksyms (Closes:
  Trac#39)
- support selection of VServers to run on, in the same way as in the dup
  handler, with the new vsnames configuration option ; (Closes: Trac#45)
- add support for capturing the package debconf selection states using
  debconf-get-selections
- fixed catifexec function to actually work, also now passes the arguments
  given to catifexec() to the called command (Thanks John Hallam!)
- Added more robust software RAID information capture by running mdadm -Q
  --detail /dev/md?\* because some people may have empty mdadm.conf files
  (Thanks to John Hallam).

#### trac

- stop failing on all the trac backups if just one fails, this means removing
  the temporary trac backup directories if they fail

#### makecd

- updated handler for new toolset (genisoimage and wodim)

## [0.9.5] - 2007-12-02

### backupninja changes

- Fixed checks on configuration files permissions, since the patch applied to
  fix DEBBUG-370396 broke this, especially for configuration files created with
  permissions 000 by an older ninjahelper version.
- Enhanced portability for other platforms
- Added quoting because it was needed to prevent shell expansion, broking the
  toint function sometimes (Closes: Trac#11)
- Fixed reportspace option (Closes: Trac#10)
- Fixed ldap handler not recognizing database suffix (Closes: Trac#28)

### handler changes

#### dup

- Support duplicity >= 0.4.3 invocation syntax (--ssh-command option is not
  supported anymore) (Closes: DEBBUG-447425)
- New tmpdir configuration option, very useful in case duplicity tends to fill
  up /tmp.

#### ldap

- Fixed shell command quoting issues, missing 'then' clauses, cleaned up
  compress=yes to be less redundant and not create empty uncompressed file
  (Closes: DEBBUG-394935)
- Fixed ninjahelper to properly set compress option, standardized on yes/no
  instead of on/off
- Fixed problem that caused combination of slapcat and compress to not work
  together (Closes: Trac#29)
- Applied patch from romain.tartiere@healthgrid.org to fix the SSL/TLS options
  to be correct, also set TLS to be the default over SSL (Closes: Trac#13)

#### maildir

- Added an examples file (Closes: Trac#23)
- Applied patch from Anarcat that fixes the cp/mkdir calls to not use GNU
  coreutils options, as well as some bashisms (Closes: Trac#24)
- Fix test mode (Closes: Trac#25)

#### mysql

- Fixed case where odd combination of configuration options caused sqldump
  backups to get overwritten with an empty file (Closes: DEBBUG-402679)
- Added 'nodata' option to enable you to specify tables that you want to omit
  the data from a backup, but still backup the table structure. This is very
  useful in cases where tables contain large amounts of cache data. See the
  example.mysql for options, thanks Daniel Bonniot (Closes: DEBBUG-408829)
- Enhance code for selecting databases by asking MySQL not to give us the
  header (-N), to not draw pretty boxes around the output (-B), send the query
  via -e instead of a pipe and ensure MySQL listens to -B. Thanks to Matthew
  Palmer (Closes: DEBBUG-452039).

#### pgsql

- Support configuring PGSQLUSER for real, and document it a bit; this broken
  support actually prevented pgsql handler to work for VServers (Closes:
  DEBBUG-396578)

#### rdiff-backup

- Added cstream support to allow for bandwidth limiting
- Handle "keep = yes" to disable old backups removal (Closes: DEBBUG-424633)
- Add configuration option to allow you to disable the version check as in some
  instances this may be an ok scenario (Closes: DEBBUG-424632)
- Added local destination support to helper (Closes: Trac#4)
- Allow exclude-only configurations (Closes: Trac#21)

#### rub/rsync

- Fixed typo in rub handler that caused it to not work
- Changed to use lib/vserver code
- Fixed fsck error
- Fixed integer comparison (Closes: Trac#3)
- Renamed handler to 'rsync', replaces outdated rub handler
- updated examples/Makefile.am and handlers/Makefile.am to include rsnap/rsync
  (Closes: DEBBUG-440554)
- Added example.rsync configuration file

#### sys

- Fixed typo breaking things for VServers.
- Fix bug when vrootdir is on its own partition (Closes: DEBBUG-395928)
- Better sfdisk error and output handling: should now properly warn when it
  does not manage to backup a partition table, and shut up when it succeeds
  (Closes: DEBBUG-396632)
- Added option to not use sfdisk at all, useful for vserver/xen instances that
  produce warnings about no harddisks found (Closes: DEBBUG-404071)
- Fixed example in example.sys to detail the `__star__` in partitionsfile and
  note why its necessary (Closes: DEBBUG-409192)
- Force C locale for sfdisk to ensure english words are found in grep
- Make directory where output is placed configurable, and create the parent dir
  if it doesn't exist (Closes: Trac#1)

#### ninjareport

- Added first draft of method to aggregate reports from many servers into one
  email. Requires logtail, rsync, configuration of reporthost, reportdirectory
  and reportuser in backupninja.conf. Configure cron to run once a day, and
  individual backupninjas not to report by email their status, then enjoy one
  email report from all hosts, rather than multiple

#### other

- fixed 'make install' bug that failed if /etc/backup.d already existed
- changed spaces to tabs in Makefile.am
- updated redhat spec file (thanks Adam Monsen)

## [0.9.4] - 2006-10-06

### backupninja changes

- Fixed bug in toint(), and thus isnow(), which caused it to not work when run
  from cron.
- Recursively ignore subdirs in /etc/backup.d (Closes: DEBBUG-361102)
- Add admingroup option to configuration to allow a group that can read/write
  configurations (instead of only allowing root). Checks and complains about
  group-readable files only when the group differs from the one in the
  configuration file (default is root as before).  Thanks to Martin Krafft for
  the patch (Closes: DEBBUG-370396).
- When determining which backup actions to make, find now follows symlinks for
  $configdirectory
- Changed order of -s to mail for compatibility
- fixed permission stat call so it uses the --format supported by coreutils
  (Closes: DEBBUG-382747)
- Added disk space report option (thanks Adam Kosmin)

### handler changes

#### Added tar handler

- create tarballs

#### Added rsnap handler

- rotated rsync snapshops
- code from paulv@bikkel.org

#### Added rub handler

- alternative to rsnap
- code from rhatto@riseup.net

#### mysql

- Fixed improper use of $vuserhome (Closes: DEBBUG-351083)
- Fixed erroneous removal of tmpfile when it didn't exit
- Fixed inversed vsname emptiness check
- Fixed su quote usage to be more posixy
- Compress for sqldumps now happens in-line to save some disk space (Closes:
  DEBBUG-370778)
- Fixed --defaults-file now as --defaults-extra-file (thanks rhatto)

#### pgsql

- Fixed inversed vsname emptiness check
- Fixed su quote usage to be more posixy
- Fixed shell expansion, thanks Thomas Kotzian (Closes: DEBBUG-363297)
- postgres user UID is now the one from inside the vserver if necessary
- Compress now happens in-line to save some disk space (Closes: DEBBUG-370778)
- $PGSQLUSER is used instead of hardcoding user 'postgres' (although this is
  the default)

#### svn

- Fixed inversed vsname emptiness check

#### rdiff

- Symlink and globbing support in include/exclude/vsinclude. Clarification:
  globbing is fully supported again, whereas no attempt is done to dereference
  symlinks anymore, due to incompatibilities between various readlink versions
  in this field.
- Removed overzealous vsnames check
- Now works if testconnect=no and if $test is not defined.
- add $sshoptions config parameter in [dest] section of config so connections
  to ports other than 22 can be made by adding the following to the top of the
  handler config: options = --remote-schema 'ssh -p REMOTE-PORT -C %s
  rdiff-backup --server'

#### dup

- Symlink and globbing support in include/exclude/vsinclude. Clarification
  globbing is fully supported again, whereas no attempt is done to dereference
  symlinks anymore, due to incompatibilities between various readlink versions
  in this field.
- Removed over zealous vsnames check
- Does not pretend anymore that duplicity can work without any passphrase
- Support duplicity 0.4.2 (with Debian patches applied; upstream's 0.4.3 will
  integrate them); documented how to write sftp-compatible sshoptions (Closes:
  DEBBUG-388543)
- Now forbid to (try to) include /.

#### sys

- Many more system checks were added, (thanks to Petr Klíma)
- Added warning if no devices were found (thanks Ranier Zocholl)
- Enhanced debian package selections to include purged packages (thanks Tom
  Hoover)
- Removed warning about vserver not running (thanks anarcat)

#### ldap

- Compress now happens in-line to save some disk space (Closes: DEBBUG-370778)

#### makecd

- Added nicelevel option (thanks rhatto)

#### trac

- fixed problem when src was set to the trac repo directly (Closes: DEBBUG-382737)

### lib changes

#### vserver

- init_vservers: fixed DEBBUG-351083 (improper readlink syntax)
- found_vservers: escaped special grep repetition character +
- forced mktemp to use a template with a name to be more compatible with
  different versions of mktemp, thanks anarcat

### ninjahelper changes

- Recursively ignore subdirs in /etc/backup.d (Closes: DEBBUG-361102)
- Fix configdirectory error that forced you to use /etc/backup.d, thanks
  anarcat
- When determining which backup actions to list, find now follows symlinks for
  $configdirectory
- Stop checking helpers perms: both "make install" and distros packages install
  them with appropriate permissions, it's overzealous to check this at runtime,
  and is more complicated to do with current admingroup option.

#### dup.helper

- Fix: signing was enabled with symmetric encryption.

#### other

- changed cron permissions to 644
- changed /etc/backup.d permissions to 0770 (for admingroup)
- minor documentation fixes
- improved RPM build process allowing 'make rpm-package' and 'make
  srpm-package' targets, also fixes permissions on man directories, cleans up
  RPM-related files during distclean, and adds default EDITOR for "autogen.sh
  -f" if none is set. (thanks Robert Napier)

## [0.9.3] - 2006-02-01

### backupninja changes

#### backupninja.conf

- added (commented out) the various default paths to programs such as
  PGSQLDUMP, so that users can figure out more easily they can customize them

#### code refactor

- now uses vservers lib to initialize vservers support

### handler changes

#### duplicity, mysql, pgsql, rdiff, svn, sys:

- start to use (at different degrees) new lib/vserver functionality

#### mysql

- fixed no user defaults file processing

#### duplicity

- fixed (again...) globbing in include and exclude options (DEBBUG-348022,
  follow-up to DEBBUG-338796)
- warn if vsnames or vsinclude is enabled while vservers support is disabled in
  backupninja.conf
- now works when multiple vservers names are given (separated by space) in
  vsnames config variable rdiff
- fixed globbing bug in include, exclude and vsinclude options
- it's now possible to choose exactly which vservers should be backed-up, as it
  already was with duplicity handler, with the "vsnames" configuration setting

### ninjahelper changes

#### rdiff.helper

- fixed errors in create remote dir
- code formatting cleanup (three spaces indent)
- fixed bug which caused only first include/exclude dir to have "include = "
- fixed globbing bug with exclude

#### ninjahelper

- now reports error if the helper script has a syntax error or bombs out.
- code formatting cleanup (three spaces indent)

### lib changes

#### vserver

- init_vservers: improved VROOTDIR detection
- init_vservers: test in a stricter way the real vservers availability
- init_vservers: canonicalize VROOTDIR (since duplicity et al.  don't follow
  symlinks)
- init_vservers: warn if vservers are enabled but no vserver is found
- new function: vservers_exist known bugs:

#### easydialog

- formDisplay does not return exit status.

#### other

- autotools fixes

## [0.9.2] - 2005-12-29

### backupninja changes

- fixed broken toint() which caused when "everyday" problems
- backupninja.conf.5 updated to include "when" and "vservers"

#### code refactor:

- moved to lib/ some code that has to be shared between backupninja and
  ninjahelper

### handler changes

#### trac

- mkdir subdirectory problem fixed

#### duplicity

- globbing support fixed in include and exclude options
- different signing and encrypting key support added
- fixed erroneous comments in example.dup about the way GnuPG-related options
  are used

#### mysql

- handler vserver bugs fixed and debug output enhanced

### ninjahelper(s) changes

- vserver-related functions added to lib/vservers.in
- added man/ninjahelper.1 man page

#### makecd

- was missing in Makefile.am/.in

#### rdiff-backup

- used to expand '\*' in default source directories
- the "Cancel" buttons used to have a weird behaviour
- updated to include Vserver selection

#### pgsql

- forbid the user to choose an empty database set
- "Cancel" button now does what it is meant to do

#### mysql

- enhanced for vserver support
- now able to select databases and dump directory

#### duplicity

- new handler added (with Vserver support)

## [0.9.1] - 2005-11-05

- rearranged source so that it is relocatable with autotools (thanks to Petr
  Klíma petr.klima@madeta-group.cz)
- fixed many bugs in rdiff helper
- rdiff handler does not require 'label' (for real this time?)
- added makecd ninjahelper (thanks to Stefani stefani@riseup.net)
- made ninjahelper create files with mode 600 rather than 000
- changed subversion handler to use svnadmin hotcopy instead of the unsupported
  hot-copy.py script, which was moved in Debian
- update rdiff ninjahelper: now detects and auto-install rdiff-backup on the
  remote machine if possible, also tests the remote backup directory and offers
  to create it if it doesn't exist

## [0.9] - 2005-10-19

*IMPORTANT CHANGE, UPGRADE AT ONCE*

- fixed insecure temporary file creation
- removed erroneous magic file marker in pgsql handler
- fixed incorrect find positional
- changed direct grep of /etc/passwd to getent passwd.
- rdiff helper has much better information on failed ssh attempt (patch from
  cmccallum@thecsl.org).
- rdiff handler now supports remote source and local dest.  (patch from
  cmccallum@thecsl.org).
- man pages are greatly improved.

## [0.8] - 2005-09-15

- added pgsql (PostgreSQL) handler, with vservers support.
- added vservers support to duplicity handler Note: the configuration is a bit
  different than the rdiff handler's one, but the default behavior is the same:
  have a look at example.dup.
- improved README
- documented .disabled method.
- corrected VROOTDIR default value.
- added ninjahelper to the install instructions.
- improved rdiff, dup and sys handlers' vservers support prevent
  vserver-debiantools' $VROOTDIR/ARCHIVES directory to be seen as a vserver
- changes to sys handler make use of configurable $VSERVERINFO instead of
  hard-coded vserver-info.  fixed dpkg existence test inside vserver.  fixed
  $nodpkg use.
- changes to pgsql handler now checks if the specified vserver is running.  now
  checks if $PGSQLDUMP/$PGSQLDUMPALL are available where needed.  now checks if
  "postgres" user exists on the host/vserver.
- changes to ninjahelper check_perms() does not die anymore on group/world
  readable helper scripts (now consistent with the "helper scripts must not be
  group or world writable!" error msg).
- xedit action now tries $EDITOR, then /etc/alternatives/editor, then nano, vim
  and vi, and aborts if none of these exists.
- added helper for pgsql handler.
- rdiff handler now does not require 'label'
- changes to mysql and svn handlers' vservers support these handlers now check
  if the source vserver is running
- added 'ignores' for mysql handler. (thanks Daniel.Bonniot@inria.fr)

## [0.7] - 2005-07-26

- added ninjahelper: a dialog based wizard for creating backupninja configs.
- considerably improved and changed the log file output.
- you can now disable actions with .disabled (this is new preferred method).
- added makecd handler and example.makecd for backing up to cd/dvd (thanks
  stef).
- fixed bug when specifying multiple 'when' options.

## [0.6] - 2005-06-16

- ldap handler has new options: backup method to use (ldapsearch or slapcat),
  restart, passwordfile and binddn. Default backup method is set to ldapsearch
  as this is safer
- *NOTE: to get the previous default behavior with the ldap handler,
  you must set "method = slapcat". The new default is ldapsearch.*
- implemented fix so that the main script will echo fatal errors rather than
  being silent about them, this means an error message every hour if there is a
  major configuration problem (not a handler problem)
- added vserver support to main script and to the handlers: mysql, svn, sys,
  rdiff
- changes to duplicity handler (thanks intrigeri!): "keep = yes" now disables
  file cleaning on desthost added "sign" option for backups signing added
  "encryptkey" option to specify the gpg key to use split config into [source],
  [gpg] and [dest] sections added "nicelevel" option added "testconnect" option
  added "sshoptions" option (will be passed to ssh/scp) added "bandwidthlimit"
  option
- example.dup example config file for duplicity handler
- added trac (http://trac.edgewall.com/) environment handler (thanks Charles
  Lepple!)
- added configfile option to mysql handler the default is
  /etc/mysql/debian.cnf. with this, sqldump doesn't need dbusername. (hotcopy
  still does).
- fixed bug in mysql handler which caused some passwords to not work.  (.my.cnf
  files now have double quotes around password)
- can now pass options to hwinfo and sfdisk in sys handler.

## [0.5] - 2005-04-12

- rdiff handler works when remote sshd has a banner
- rdiff handler supports local dest
- logfile is created if it doesn't exist
- added "when = hourly"
- added optional 'nicelevel' to rdiff handler
- fixed bug where actions were not run in numeric order.
- improved 'when' parsing.

## [0.4.4] - 2005-03-18

- results of handlers are now read line by line.
- changes to rdiff handler: added "options", and "keep" is not necessarily days
  now (ie, it will pass straight through to rdiff-backup if the keep has a unit
  on it, otherwise it adds the 'D').
- added dup handler (still pretty beta)
- added maildir handler (very specialized handler)
- added --run option (runs the specified action file)
- improved sys handler, now uses hwinfo
- added subversion hotbackup handler, svn.
- added PATH to cron.d file, which fixes file not found errors.

## [0.4.2] - 2005-01-06

- fixed bug which caused a report email to be sent even if no actions were run.
- fixed bug where multiple handler status messages were ignored
- added status in the subject line of report emails

## [0.4.1] - 2005-01-03

- added $usecolors and now more conservative about when colors are echoed.
- fixed major bug, 'when' actually works now.
- replaced debug function with debug, info, warning, error, fatal.
- added --now option to force all actions to be performed now.

## [0.4] - 2004-12-26

- added "when" option, so that all configs can specify when
        they are to be run.
- added reportsuccess and reportwarning config options
- added .sys handler (hardware, packages, partitions).

## [0.3.4] - 2004-12-08

- fixed numerical variable quoting compatibility with older wc
- fixed stderr redirect bug
- some comments in example.rdiff

## [0.3.3] - 2004-11-10

- '\*' (asterisk) works now in rdiff config files
- works now with gawk as well as mawk
- many bug fixes to ldap handler
- paths to helper scripts can be configured in global config
- does not require /usr/bin/stat

## [0.3.2] - 2004-09-29

- handler scripts are no longer executable (to comply with debian policy)
- handler error and warning messages are sent with the notify email

## [0.3.1] - 2004-09-05

- added ldap handler
- moved sh support to a handler script
- add test mode, where no action is taken.
- added --help
- force only root can read /etc/backup.d/\*
- fixed missing equals symbols in example.rdiff
- changed backupninja executable to be /usr/sbin rather than /usr/bin

## [0.3] - 2004-10-20

- *IMPORTANT* all config files are now ini style, not apache style
- rewrote all scripts in bash for portability
- added drop-in backupninja lib directory (/usr/share/backupninja)
- all scripts are now run as root

## [0.2] - 2004-10-14

- move distribution folder ./cron.d to ./etc/cron.d
- fixed bug: removed printr of excludes (!)
- added support for changing the user/group in rdiff sources.
- added support for .mysql config files.

## [0.1] - 2004-10-08

- initial release
