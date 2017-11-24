This repo holds routines for vitess to start / stop mysqld and vtgate.

There is a manager script for each script intended to manage a binary
and that script can stop, start, restart or check the status of one
or ore proceses.

Several configuration files exist to manage each specific vitess
process.  If the instance is remote then the scripts will be copied
using ssh to the remote location and run remotely thus avoiding me
having to copy stuff about manually. (later we can do this better)

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
  - vtctld:    done
  - zookeeper: pending
* build the my.cnf file via vthooks
  - partially done. Needs to be more complete
* script to see and check ALL running processes
  - partially done
* handling of mysqld when it's run "outside of the vitess setup"
  - partially done
* making logging and output standard for all processes and noisy
  enought but not too noisy

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
