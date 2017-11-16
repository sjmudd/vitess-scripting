This repo holds routines for vitess to start / stop mysqld and vtgate.

VERY MUCH WORK IN PROGRESS

The same scripts only start and stop and are in separate scripts.
these use the same script to start/ stop / check status and restart
the processes.

I've added a config file with the location and config of each instance
and that is used to manage it. If the instance is remote then the
scripts will be copied to the remote location and run remotely thus
avoiding me having to copy stuff about manually. (later we can do
this better)

Directory locations are broken in the sense they assume I built the
vitess repo which is under ~simon/dev. That's not really correct
of course for anyone else so the build/install directories need to
be changed and the ownership of files and who runs the vitess stuff
needs to be cleaned up.

Things to fix:
* directory layout
* file ownership
  - now there's a config file and the use of sudo will make it change to the required user.
  - I need to change the user used but can do that later.
* process used to run vitess
* make this work for all processes:
  - mysqld:    done
  - vttablet:  done
  - vtgate:    done
  - vtctld:    pending
  - zookeeper: pending
* build the my.cnf file via vthooks
  - (but not sure how to get the specific instance info into the hook receiver)
* script to see and check ALL running processes
* handling of mysqld when it's run "outside of the vitess setup"

Example of using the stuff atm (output needs tidying up)

```
$ ./mysqld-manager status 300
OK: host-12: mysqld running [pid 6795] under /home/simon/dev/vtdataroot/vt_0000000300
$ ./mysqld-manager stop 300
Stopping MySQL for tablet cell1-0000000300...
$ ./mysqld-manager status 300
ERROR: host-12: no pid file /home/simon/dev/vtdataroot/vt_0000000300/mysql.pid
$ ./mysqld-manager start 300
Starting MySQL for tablet cell1-0000000300...
Resuming from existing vttablet dir:
    /home/simon/dev/vtdataroot/vt_0000000300
W1115 10:05:17.277111   28039 mysqld.go:221] mysqld_safe not found in any of //{sbin,bin}: trying to launch mysqld instead
$ ./mysqld-manager.sh status 300
OK: host-12: mysqld running [pid 28046] under /home/simon/dev/vtdataroot/vt_0000000300
```
