#!/bin/bash

# this script should be sourced from others not run on its own.

myname=$(basename $0)
myhostname=$(hostname -s)
vitess_config_file=vitess.conf
vtgate_config_file=vtgate.conf
vtctld_config_file=vtctld.conf
vtworker_config_file=vtworker.conf
zk_config_file=zk.conf

msg_info () {
	echo "$myhostname $myname[$$]: $@"
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
	for dir in "$@"; do
		test -d "$dir" || {
			msg_info "Creating missing directory: $dir"
			$sudo_exec mkdir -p $dir
		}
	done
}

hostname_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $1 }' $vitess_config_file
}

vtgate_hostname_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $1 }' $vtgate_config_file
}

keyspace_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $4 }' $vitess_config_file
}

web_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $6 }' $vitess_config_file
}

# get the credentials name to use
get_credentials_name () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $10 }' $vitess_config_file
}

vtgate_web_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $5 }' $vtgate_config_file
}

vtgate_cell_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $2 }' $vtgate_config_file
}

mysql_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $7 }' $vitess_config_file
}

vtgate_mysql_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $6 }' $vtgate_config_file
}

vtgate_tablet_types_to_wait_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $7 }' $vtgate_config_file
}

grpc_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $8 }' $vitess_config_file
}

vtgate_grpc_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $4 }' $vtgate_config_file
}

cell_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $2 }' $vitess_config_file
}

alias_from_id () {
	local id="$1"

	echo "$(cell_from_id $id)-$(printf %010d $id)"
}

shard_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $5 }' $vitess_config_file
}

user_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $9 }' $vitess_config_file
}

# take the first vtctld from the configuration
vtctld_host_from_cell () {
	local cell="$1"

	awk -v cell=$cell '{ if ($2 == cell) print $1 }' $vtctld_config_file | head -1
}

# take the first vtctld from the configuration
vtctld_web_port_from_cell () {
	local cell="$1"

	awk -v cell=$cell '{ if ($2 == cell) print $4 }' $vtctld_config_file | head -1
}

# vtgate settings

vtgate_user_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $8 }' $vtgate_config_file
}

# vtctld settings

vtctld_hostname_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $1 }' $vtctld_config_file
}

vtctld_cell_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $2 }' $vtctld_config_file
}

vtctld_web_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $4 }' $vtctld_config_file
}

vtctld_grpc_port_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $5 }' $vtctld_config_file
}

vtctld_user_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $6 }' $vtctld_config_file
}

vtctld_cell_from_id () {
	local id="$1"

	awk -v id=$id '{ if ($3 == id) print $2 }' $vtctld_config_file
}

copy_files () {
	local host=$1

	msg_verbose "Copying configuration and scripts to $host (home directory)"
        (
                [ -n "$verbose" ] && opt_v=v
                set -e
                rsync -a${opt_v} $mydir/common_routines.sh $zk_config_file $vtgate_config_file $vitess_config_file $vtctld_config_file $vtworker_config_file credentials.*.sh $host:
                rsync -a${opt_v} $0 $host:$myname
        ) || msg_fatal "Copying files to $host"
}

check_status () {
	local pid
	local name="$1"
	local pidfile="$2"

	if [ ! -r $pidfile ]; then
		echo "ERROR: $myhostname: $name: not running (no pid file $pidfile)"
		return
	fi

	pid=$(cat $pidfile)
	if [ -z "$pid" ]; then
		echo "ERROR: $myhostname: $name: no pid in $pidfile"
		return
	fi
	ps -p $pid >/dev/null 2>&1
	if [ $? = 0 ]; then
		echo "OK: $myhostname: $name running [pid $pid] under $(dirname $pidfile)"
		return
	else
		echo "ERROR: $myhostname: $name not running $under $(dirname $pidfile)"
		return
	fi
}

stop_by_pidfile () {
	local name=$1
	local pidfile=$2

	if test -e $PIDFILE; then
		pid=`cat $PIDFILE`
		msg_info "Stopping $name [pid: $pid]..."
		$sudo_kill $pid

		while ps -p $pid > /dev/null; do sleep 1; done
		msg_info "$name stopped"
	else
		msg_info "No pid file at $myhostname:$PIDFILE so assuming $name not running"
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
	test -r $zk_config_file ||\
		msg_fatal "Missing $zk_config_file"

	grep -v "^#" $zk_config_file |\
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
TOPOLOGY_FLAGS="-topo_implementation zk2 -topo_global_server_address host-02:21811,host-02:21812,host-02:21813 -topo_global_root /vitess/global"
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
