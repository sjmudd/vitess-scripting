#!/bin/bash

# this script should be sourced from others not run on its own.

myname=$(basename $0)
myhostname=$(hostname -s)
vitess_conf=vitess.conf
vtgate_conf=vtgate.conf
vtctld_conf=vtctld.conf
vtworker_conf=vtworker.conf
my_cnf_generic=my.cnf.generic
zk_conf=zk.conf
make_mycnf=make_mycnf
topology_conf=topology.conf.sh

msg_info () {
	echo "$(date +'%b %d %H:%M:%S') $myhostname $myname[$$]: $@"
}

msg_verbose () {
	test -n "$verbose" && echo "$myhostname $myname[$$]: $@"
}

msg_fatal () {
	msg_info "FATAL: $*"
	exit 1
}

# create a directory if it is missing
sudo_mkdir_if_missing () {
	local dir
	for dir in "$@"; do
		test -d "$dir" || {
			msg_info "Creating missing directory: $dir"
			$sudo_exec mkdir -p $dir
		}
	done
}

# check the command actions are what we expect.
check_action () {
	local action="$1"
	local rc=1

	# check for valid actions
	case "$action" in
	start)		rc=0;;
	stop)		rc=0;;
	status)		rc=0;;
	restart)	rc=0;;
	esac

	return $rc
}

usage () {
	local name=$1
	local rc=${2:-1}

	cat <<-EOF
	$myname (C) 2017 booking.com

	Script to manage $name for Vitess.
	Usage: $myname [options] <start|stop|status|restart> <instance_id> [<instance_id>...]

	options:
	-h help message
	-v verbose logging
	EOF

	exit $rc
}

############################################################################
# vitess_conf retrieval functions                                   #

hostname_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $2 }' $vitess_conf
}

cell_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $3 }' $vitess_conf
}

keyspace_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $4 }' $vitess_conf
}

shard_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $5 }' $vitess_conf
}

web_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $6 }' $vitess_conf
}

mysql_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $7 }' $vitess_conf
}

grpc_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $8 }' $vitess_conf
}

vttablet_user_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $9 }' $vitess_conf
}

mysqld_user_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $10 }' $vitess_conf
}

# get the credentials name to use
get_credentials_name () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $11 }' $vitess_conf
}

get_backup_config () {
        local id="$1"

        awk -v id=$id '{ if ($1 == id) print $12 }' $vitess_conf
}

configure_heartbeat_from_id () {
        local id="$1"

        awk -v id=$id '{ if ($1 == id) print $13 }' $vitess_conf
}

alias_from_id () {
	local id="$1"

	echo "$(cell_from_id $id)-$(printf %010d $id)"
}

############################################################################
# vtgate_conf retrieval functions                                          #

vtgate_hostname_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $2 }' $vtgate_conf
}

vtgate_cell_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $3 }' $vtgate_conf
}

vtgate_web_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $4 }' $vtgate_conf
}

vtgate_grpc_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $5 }' $vtgate_conf
}

vtgate_mysql_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $6 }' $vtgate_conf
}

vtgate_tablet_types_to_wait_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $7 }' $vtgate_conf
}

vtgate_user_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $8 }' $vtgate_conf
}

############################################################################
# vtctld_conf retrieval functions                                          #

# id  hostname                             cell   port   grpc_port  user  #

vtctld_hostname_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $2 }' $vtctld_conf
}

vtctld_cell_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $3 }' $vtctld_conf
}

vtctld_web_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $4 }' $vtctld_conf
}

vtctld_grpc_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $5 }' $vtctld_conf
}

vtctld_user_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($1 == id) print $6 }' $vtctld_conf
}

# take the first value from the configuration
vtctld_first_id_from_cell () {
	local cell="$1"

	awk -v cell=$cell '{ if ($3 == cell) print $1 }' $vtctld_conf | head -1
}

copy_files () {
	local host=$1

	msg_verbose "Copying configuration and scripts to $host (home directory)"
        (
		[ -n "$verbose" ] && opt_v=v
		set -e
		rsync -a${opt_v} $mydir/common_routines.sh $zk_conf $vtgate_conf $vitess_conf $vtctld_conf $vtworker_conf $my_cnf_generic credentials.*.sh $host:
		rsync -a${opt_v} $make_mycnf $host:$VTROOT/vthook/
		rsync -a${opt_v} $0 $host:$myname
	) || msg_fatal "Copying files to $host"
}

check_status () {
	local pid
	local name="$1"
	local pidfile="$2"

	if [ ! -r $pidfile ]; then
		echo "ERROR: $myhostname: $name: not running (no pid file $pidfile)"
		return 1
	fi

	pid=$(cat $pidfile)
	if [ -z "$pid" ]; then
		echo "ERROR: $myhostname: $name: no pid in $pidfile"
		return 1
	fi
	ps -p $pid >/dev/null 2>&1
	if [ $? = 0 ]; then
		echo "OK: $myhostname: $name running [pid: $pid] under $(dirname $pidfile)"
		return 0
	else
		echo "ERROR: $myhostname: $name not running under $(dirname $pidfile)"
		return 1
	fi
}

stop_by_pidfile () {
	local name=$1
	local pidfile=$2

	if test -e $pidfile; then
		pid=`cat $pidfile`
		msg_info "Stopping $name [pid: $pid]..."
		$sudo_kill $pid ||\
			msg_info "WARNING: kill failed: please check if the configured username is correct"

		while ps -p $pid > /dev/null; do sleep 1; done
		msg_info "$name stopped"
	else
		msg_info "$name not running, no pid file at $pidfile"
		return 1 # so we know something didn't work.
	fi
}

# read the appropriate credentials file to get a config.
read_credential_config () {
	local id=$1
	local name=$(get_credentials_name $id)
	local credentials_file="credentials.$name.sh"

	if [ -r "$credentials_file" ]; then
		source $credentials_file ||\
			msg_fatal "Sourcing credentials_file: $credentials_file"
	else
		msg_fatal "Can not find credentails file: '$credentials_file' implied from id: $id -> name: $name"
	fi
}

# generate ZK_CONFIG used by other things
# ZK_CONFIG=1@host-2:28881:38881:21811,2@host-2:28882:38882:21812,3@host-2:28883:38883:21813
generate_zk_config () {
	test -r $zk_conf ||\
		msg_fatal "Missing $zk_conf"

	grep -v "^#" $zk_conf |\
	awk '{ print $1 "@" $2 ":" $3 }' |\
	tr '\n' ',' | sed -e 's/,$//'
}

HOSTNAME=$(hostname)

############################################################################
#                                                                          #
# The settings here should be moved to a different location from           #
# the shell functions as they are site depdendent                          #
#                                                                          #
############################################################################
test -r $topology_conf ||\
	msg_fatal "Missing $topology_conf"

source $topology_conf
ZK_CONFIG=$(generate_zk_config)

# need a big size due to big queries
GRPC_MAX_MESSAGE_SIZE=$((16*1024*1024))

############################################################################
#                                                                          #
# Export values used by vitess processed                                   #
#                                                                          #
############################################################################

# These settings need fixing later but they start here
export VTDATAROOT=/home/smudd/dev/vtdataroot
export VTROOT=/home/smudd/dev
export VTTOP=/home/smudd/dev/src/github.com/youtube/vitess
export VT_MYSQL_ROOT=/
export MYSQL_FLAVOR=MySQL56

export LD_LIBRARY_PATH=${VTROOT}/dist/grpc/usr/local/lib
export PATH=${VTROOT}/bin:${VTROOT}/.local/bin:${VTROOT}/dist/chromedriver:${VTROOT}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin

case "$MYSQL_FLAVOR" in
  "MySQL56")
    export EXTRA_MY_CNF=$VTROOT/config/mycnf/master_mysql56.cnf
    ;;
  "MariaDB")
    export EXTRA_MY_CNF=$VTROOT/config/mycnf/master_mariadb.cnf
    ;;
  *)
    echo "Please set MYSQL_FLAVOR to MySQL56 or MariaDB."
    exit 1
    ;;
esac
