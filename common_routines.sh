#!/bin/sh
#
# This script should be sourced from others not run on its own.
# - it contains the common routines used by the vitess_scripting
#   repo.
#

myname=$(basename $0)
myhostname=$(hostname -s)
vitess_conf=vitess.conf
vtgate_conf=vtgate.conf
vtctld_conf=vtctld.conf
vtworker_conf=vtworker.conf
env_conf=env.conf
my_cnf_generic=my.cnf.generic
zk_conf=zk.conf
make_mycnf=make_mycnf
topology_conf=topology.conf.sh
init_db=init_db.sql

# Convert $mydir into a full path if relative and change to $mydir
# so we can find the required scripts if we need to copy them.
if ! echo "$mydir" | grep -q "^/"; then
	mydir="$PWD/$mydir"
fi
cd $mydir

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
mkdir_if_missing () {
	local dir
	for dir in "$@"; do
		test -d "$dir" || {
			msg_info "Creating missing directory: $dir"
			mkdir -p $dir
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

# return the VTROOT for $user@$hostname
vtroot_from_host_and_user () {
        local hostname=$1
        local user=$2

        awk -v hostname=$hostname -v user=$user '{ if ($1 == hostname && $2 == user) print $3 }' $env_conf
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

# Copy various configuration files to the remote host to $VTDEPLOY
# as $user using sudo if needed. Assume the user is different and
# don't bother optimising yet for the case where remote and local
# users are the same. [ The rsync invocation is harder to optionally
# add-in that way. ]
copy_files () {
	local host=$1
	local user=$2

	# validate input...
	[ -z "$host" ] && \
		msg_fatal "copy_files: host is undefined"
	[ -z "$user" ] && \
		msg_fatal "copy_files: user is undefined"

	# For the files that vitess needs to read we have to use rsync with sudo
	# as direct rsync to the "vitess" user won't work due to temporary ssh
	# keys (or I can't figure out how to set this up).

	msg_verbose "Copying files to $user@$host:$VTDEPLOY (and other directories)..."
        (
		[ -n "$verbose" ] && opt_v=v
		set -e

		# It's quicker to copy all files to one place and move some of them than use rsync several times.
		rsync --rsync-path="sudo -u $user rsync" \
			-a${opt_v} \
			common_routines.sh \
			$zk_conf \
			$vtgate_conf \
			$vitess_conf \
			$vtctld_conf \
			$vtworker_conf \
			$topology_conf \
			$my_cnf_generic \
			$env_conf \
			$init_db \
			credentials.*.sh \
			$0 \
			$make_mycnf \
			$init_db \
			$host:$VTDEPLOY

		msg_verbose "Moving $make_mycnf $init_db to appropriate locations..."
		ssh $host "sudo -u $user cp -p $VTDEPLOY/$make_mycnf $VTROOT/vthook/; sudo -u $user cp -p $VTDEPLOY/$init_db $VTROOT/config/"
	) || msg_fatal "Copying files to $user@$host:$VTDEPLOY (and other places)"
}

check_status () {
	local pid
	local name="$1"
	local pidfile="$2"
	local user="$3"   # DO NOT provide this parameter. It's to catch older behaviour which is no longer supported.

	[ -n "$user" ] && \
		msg_fatal "check_status: Don't provide a username as we're running under the right user"

	if ! test -r $pidfile; then
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
		echo "OK: $myhostname: $name running as user '$USER' [pid: $pid] under $(dirname $pidfile)"
		return 0
	else
		echo "ERROR: $myhostname: $name not running under $(dirname $pidfile)"
		return 1
	fi
}

# Stop the process inside the given pidfile. Assume the user is the one doing the stop.
stop_by_pidfile () {
	local name=$1
	local pidfile=$2

	[ -z "$name" ] && \
		msg_fatal "stop_by_pidfile: name is not defined"
	[ -z "$pidfile" ] && \
		msg_fatal "stop_by_pidfile: pidfile is not defined"

	if test -e $pidfile; then
		pid=`cat $pidfile`
		msg_info "Stopping $name [pid: $pid]..."
		kill $pid ||\
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


# Given the hostname / process and config id determine the right environment
# settings.
set_environment_from_parameters () {
	local hostname=$1
	local process=$2
	local id=$3
	local user
	local vtroot

	[ -z "$hostname" ] && \
			msg_fatal "set_environment_from_parameters: hostname is empty"
	[ -z "$process" ] && \
			msg_fatal "set_environment_from_parameters: process is empty"
	[ -z "$id" ] && \
			msg_fatal "set_environment_from_parameters: id is empty"

	# lookup in the right place the username and then from that set the VT.... settings
	case $process in
	mysqld)
		user=$(mysqld_user_from_id $id)
		vtroot=$(vtroot_from_host_and_user $hostname $user)
		if [ -z "$vtroot" ]; then
			msg_fatal "VTROOT for $user@$hostname not defined. Please check config in $env_conf"
		fi
		;;
	vttablet)
		user=$(vttablet_user_from_id $id)
		vtroot=$(vtroot_from_host_and_user $hostname $user)
		if [ -z "$vtroot" ]; then
			msg_fatal "VTROOT for $user@$hostname not defined. Please check config in $env_conf"
		fi
		;;
	vtctld)
		user=$(vtctld_user_from_id $id)
		vtroot=$(vtroot_from_host_and_user $hostname $user)
		if [ -z "$vtroot" ]; then
			msg_fatal "VTROOT for $user@$hostname not defined. Please check config in $env_conf"
		fi
		;;
	vtgate)
		user=$(vtgate_user_from_id $id)
		vtroot=$(vtroot_from_host_and_user $hostname $user)
		if [ -z "$vtroot" ]; then
			msg_fatal "VTROOT for $user@$hostname not defined. Please check config in $env_conf"
		fi
		;;
	*)	msg_fatal "Still don't know how to setup the environment on $hostname/$process. Fix me!"
	esac

	setup_environment $vtroot
}

# setup the environment based on VTROOT being the value provided.
setup_environment () {
	local vtroot=$1

	# used to copy files over
	VTDEPLOY=$vtroot/scripting_deploy

	# These settings need fixing later but they start here
	export VTROOT=${vtroot}
	export VTDATAROOT=$VTROOT/vtdataroot
	export VTTOP=${VTROOT}/src/github.com/youtube/vitess
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
}

HOSTNAME=$(hostname)

############################################################################
#                                                                          #
# The settings here should be moved to a different location from           #
# the shell functions as they are site dependent                           #
#                                                                          #
############################################################################
test -r $topology_conf ||\
	msg_fatal "Missing $topology_conf"

source $topology_conf
ZK_CONFIG=$(generate_zk_config)

# need a big size due to big queries
GRPC_MAX_MESSAGE_SIZE=$((16*1024*1024))
