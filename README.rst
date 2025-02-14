
dbbak
=====

This module contains `dbbak`, a simple shell script for managing
full/incremental backup of MySQL with innobackupex.

Currently, the script handles two main functionalities:

  - Full/incremental backup/rotation/purge/restore of a single MySQL
    instance using percona 'xtrabackup'.
  - Backup/purge/rotation of a single MySQL instance using LVM snapshots

LVM snapshot related commands/parameters are currently prefixed
with 'lvm' and also documented here under 'lvm' related sections
since the two mechanisms are somewhat different.

Database connection and backup store parameters are stored in the
file /etc/dbbak.cfg, with commands/usage as follows.

Installation
------------
    bash prerequisite.sh # install build-essential to use `make`

    make install # except Ubuntu 22.04 Jammy

    make install-generic # including Ubuntu 22.04 Jammy


full backup
-----------

Synopsis: 

    # dbbak full

To create a full backup, run `dbbak full`. This will trigger an
innobackupex full backup run of the configured MySQL instance to
DBBAK_BKDIR/full if no such backup already exists. If the directory
exists, a warning message is printed and the script exits with an
error; see 'backup rotation' for further details about managing
this situation.

Backup details will be logged to DBBAK_BKDIR/cur/full.log.

Setting DBBAK_NOLOCK to any value will imply that innobackupex
should use the '--no-lock' argument; the same setting also applies
to incremental backups.  If DBBAK_NOLOCK is configured, manual
effort should be taken that table structure modifications during
the backup run are properly verified; If this flag is enabled, dbbak
will attempt to detect .frm files modified during the backup run
to assist with this effort.  For details concerning the precise
implications of enabling this argument see the innobackupex and
MySQL documentation.

incremental backup
------------------

Synopsis:

    # dbbak incremental

To create an incremental backup based from the existing full backup
or the most recent subsequent incremental backup, run `dbbak incremental`.

The script will check for the presence of DBBAK_BKDIR/cur/full and
DBBAK_BKDIR/cur/incr.0 through DBBAK_BKDIR/cur/incr.999 in order
to determine the most recent backup to base the incremental on, and
proceed using innobackupex's incremental backup capabilities, storing
the backup in DBBAK_BKDIR/incr.N where N is the value of 1+ the
most recent incremental backup, or 0 in the event that only a full
backup is currently available.

If no full or incremental backups are available to use in construction
of the new incremental backup, the script will exit with an error. 

To note, currently, dbbak expects the base full backup to be available
before proceeding with an incremental backup and so will not attempt
to create incremental backups if only previous incrementals are
available in DBBAK_BKDIR. Although this is possible via innobackupex
directly, dbbak was created to explicitly manage a specific backup
policy storing base+incrementals stored in DBBAK_BKDIR and therefore
views such a situation as an administrative error which should be
corrected.

Backup details will be logged to DBBAK_BKDIR/cur/incr.N.log.

backup restoration
------------------

Synopsis:

    # dbbak restore

To restore a backup, use the `dbbak restore` command.

This will check that mysql is not running, completely wipe the
contents of the active database directory, and copy in/apply the
latest available full and incremental backups into place.

Since this is a potentially very dangerous command, a confirmation
is required for this action to proceed. 

Be sure to carefully verify output to ensure each step has properly run.

Support for choosing the backup to restore has not yet been implemented;
please review the function body of cmd_restore and innobackupex documentation
to determine appropriate steps in this case.

initializing a slave from backup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Restored backups have the files 'xtrabackup_binlog_info' and, if
backed up from a slave, the file 'xtrabackup_slave_info'. These files
contain the required information to use the restored data as a basis to
start master/slave replication. To enable, retrieve the binlog file name
and binlog position from the appropriate file, and execute a
mysql `change master` statement - for example:

    $ binlog=`awk '{print $1}' /var/lib/mysql/xtrabackup_binlog_info`
    $ binpos=`awk '{print $2}' /var/lib/mysql/xtrabackup_binlog_info`
    $ echo $binlog $binpos
    mysql-bin.12345 87654321
    $ mysql -u root
    mysql> CHANGE MASTER TO
    mysql> MASTER_HOST='192.168.1.10'
    mysql> MASTER_USER='replication',
    mysql> MASTER_PASSWORD='replication',
    mysql> MASTER_LOG_FILE='$binlog',
    mysql> MASTER_LOG_POS=$binpos;
    mysql> start slave;
    mysql> show slave status\G;

If restoring from a backup built from a master,
the `xtrabackup_binlog_info` file should be used. In the case of a
backup built from a replica, the `xtrabackup_binlog_info` file will
contain the log coordinates of the replica performing the backup,
and the file `xtrabackup_slave_info` will contain the log coordinates
of the replica's master server. The `xtrabackup_slave_info` values
and master host, user and password relevant to the master should
be used if the new replica should sync to the original master server,
and the `xtrabackup_binlog_info` and backup replica's host, user,
and password information should be used if the new replica should
be a second-stage replica syncing from the backup replica.

backup rotation
---------------

Synopsis:

    # dbbak rotate

To rotate all current full and incremental backups, run `dbbak
incremental`.

Since dbbak views the current full backup and its related incrementals
as a set, the rotation is performed on the entire collection of
existing backups, such that DBBAK_BKDIR/cur/full becomes
DBBAK_BKDIR/prev/full, and the associated incremental backups
DBBAK_BKDIR/cur/incr.N become DBBAK_BKDIR/prev/incr.N.prev, etc.
Logfiles are also rotated according to the same scheme.

The `dbbak` script only manages one rotation of the backup set;
that is to say that at any given time, there can only be the live
backup in 'cur' and the 'prev' copy. If further retention of database
backups is desired, this should be managed via a second-tier backup
scheme of the dbbak backup files.  In accordance with this expectation,
the `dbbak rotate` command will exit with an error if an existing
set of 'prev' files; the `dbbak purge` command discussed below can
be used in this situation to remove the existing previous backup
set and prepare for subsequent rotation.

purging of old backups
----------------------

Synopsis:

    # dbbak purge

To remove the previous backup set from the backup storage area, run
the command `dbbak purge`.

This command removes all 'prev' backups created via `dbbak rotate`,
and should be used to prepare the backup area for a subsequent
rotation of the active backup set.

cron driver
-----------

Synposys:

   # dbbak.cron daily
   # dbbak.cron weekly

Note: currently only implemented for xtrabackup related backups

The 'dbbak.cron' script provides a driver mechanism to run dbbak
to maintain weekly full and daily incremental backups, with
rotation/purge steps occuring prior to the weekly full run.

The script will attempt to prevent double scheduling by exiting
if the file $DBBAK_BKDIR/dbbak.cron.lock exists.

A companion file, dbbak.crontab, configures a basic schedule for
this script, executing the full run at 2AM on sundays and the
incremental run at 2AM on all other days.

status / monitoring
-------------------

Synopsys:

  # dbbak stat
  # dbbak trap

Note: currently only implemented for xtrabackup related backups:w

The 'dbbak stat' command will iterate over known logs in cur/prev
directories, and check the last 1000 lines of the most recently
modified file for a line matching the expression '^[0-9].*completed
OK', printing any matches.

In a successful run, this should normally match lines such as::

  180614 12:06:09 completed OK!

indicating that the xtrabackup run completed successfully.

The 'dbbak trap' command will use the values of DBBAK_MONITOR_SERVER
and of DBBAK_MONITOR_NAME as set in the configuration file to send
'dbbak stat' output to the configured DBBAK_MONITOR_SERVER using
zabbix_send.

To monitor backup status, a text trapper item of MySQL.backup-status shuld
be created in zabbix, with triggers data updates and for string
matching on 'OK' values. For example::

  {dbserver:MySQL.backup-status.nodata(46800)}=1
  {MySQL.backup-status.str(OK,#1)}=0

It is important to note that this scheme is not logically airtight
since if no backups are triggered, a previous successful logfile
will provide an updated OK status value to the monitoring system.
A more robust mechanism would process the status value locally and
ensure that the last 'completed OK' log message occurred within
some specified time window, reporting the interpreted status to the
server.

lvm snapshot backup
-------------------

Synopsys:

  # dbbak lvmsnap

To use LVM snapshot backups, the 'lvmsnap' command can be used.

This command will attempt to create a snapshot of the logical volume:

  ${DBBAK_LVM_SNAP_VG}/${DBBAK_LVM_SNAP_LV}

after obtaining a database write lock and syncing system buffers
to disk.

The snap will be named:

  ${DBBAK_LVM_SNAP_VG}/${DBBAK_LVM_SNAP_LV}-sN

where 'N' is the number of the first incrementally named snapshot
available according to this convention, allocating this snapshot
DBBAK_LVM_SNAP_SZ storage.

lvm snapshot status
-------------------

Synopsys:

  # dbbak lvmls

This command uses the LVM `lvs` command to display information about
currently available snapshot volumes.

lvm snapshot rotation/purge
---------------------------

Synopsys:

  # dbbak lvmpurge

The 'dbbak lvmpurge' command uses the DBBAK_LVM_SNAP_NS value to
determine the number of lvm snapshots to retain, removing other
snapshots and renaming the remaining snapshots to increment from '-s0'.

The removal is done from oldest to newest, such that the script
will ensure that the DBBAK_LVM_SNAP_NS newest snapshots are available,
and will be numbered from 0 to DBBAK_LVM_SNAP_NS-1 after a run is
complete.

misc
----

Other commands include:

  - ls: list backups.

Runs 'ls -dlart' for DBBAK_BKDIR/cur/* and DBBAK_BKDIR/prev/*. 

