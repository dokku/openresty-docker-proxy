#!/bin/sh

### BEGIN INIT INFO
# Provides:	  openresty
# Required-Start:    $local_fs $remote_fs $network $syslog $named
# Required-Stop:     $local_fs $remote_fs $network $syslog $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts openresty
# Description:       starts openresty using start-stop-daemon
### END INIT INFO

if [ -n "$TRACE" ]; then
	set -x
fi

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/local/openresty/nginx/sbin/nginx
NAME=openresty
DESC="full-fledged web platform"

if [ -r /etc/default/openresty ]; then
        . /etc/default/openresty
fi

STOP_SCHEDULE="${STOP_SCHEDULE:-QUIT/5/TERM/5/KILL/5}"

test -x $DAEMON || exit 0

. /lib/init/vars.sh
. /lib/lsb/init-functions

PID=$(cat /usr/local/openresty/nginx/conf/nginx.conf | grep -Ev '^\s*#' | awk 'BEGIN { RS="[;{}]" } { if ($1 == "pid") print $2 }' | head -n1)
if [ -z "$PID" ]; then
	PID=/usr/local/openresty/nginx/logs/nginx.pid
fi

start_nginx() {
	# Start the daemon/service
	#
	# Returns:
	#   0 if daemon has been started
	#   1 if daemon was already running
	#   2 if daemon could not be started
	start-stop-daemon --start --quiet --pidfile $PID --exec $DAEMON --test > /dev/null \
		|| return 1
	start-stop-daemon --start --quiet --pidfile $PID --exec $DAEMON -- \
		$DAEMON_OPTS 2>/dev/null \
		|| return 2
}

test_config() {
	$DAEMON -q -t $DAEMON_OPTS >/dev/null 2>&1
}

stop_nginx() {
	# Stops the daemon/service
	#
	# Return
	#   0 if daemon has been stopped
	#   1 if daemon was already stopped
	#   2 if daemon could not be stopped
	#   other if a failure occurred
	start-stop-daemon --stop --quiet --retry=$STOP_SCHEDULE --pidfile $PID --name $NAME
	RETVAL="$?"
	sleep 1
	return "$RETVAL"
}

reload_nginx() {
	# Function that sends a SIGHUP to the daemon/service
	start-stop-daemon --stop --signal HUP --quiet --pidfile $PID --name $NAME
	RETVAL="$?"
	sleep 1
	return "$RETVAL"
}

rotate_logs() {
	# Rotate log files
	start-stop-daemon --stop --signal USR1 --quiet --pidfile $PID --name $NAME
	RETVAL="$?"
	sleep 1
	return "$RETVAL"
}

upgrade_nginx() {
	# Online upgrade nginx executable
	# http://nginx.org/en/docs/control.html
	#
	# Return
	#   0 if nginx has been successfully upgraded
	#   1 if nginx is not running
	#   2 if the pid files were not created on time
	#   3 if the old master could not be killed
	if start-stop-daemon --stop --signal USR2 --quiet --pidfile $PID --name $NAME; then
		# Wait for both old and new master to write their pid file
		while [ ! -s "${PID}.oldbin" ] || [ ! -s "${PID}" ]; do
			cnt=`expr $cnt + 1`
			if [ $cnt -gt 10 ]; then
				return 2
			fi
			sleep 1
		done
		# Everything is ready, gracefully stop the old master
		if start-stop-daemon --stop --signal QUIT --quiet --pidfile "${PID}.oldbin" --name $NAME; then
			return 0
		else
			return 3
		fi
	else
		return 1
	fi
}

case "$1" in
	start)
		log_daemon_msg "Starting $DESC" "$NAME"
		start_nginx
		case "$?" in
			0|1) log_end_msg 0 ;;
			2)   log_end_msg 1 ;;
		esac
		;;
	stop)
		log_daemon_msg "Stopping $DESC" "$NAME"
		stop_nginx
		case "$?" in
			0|1) log_end_msg 0 ;;
			2)   log_end_msg 1 ;;
		esac
		;;
	restart)
		log_daemon_msg "Restarting $DESC" "$NAME"

		# Check configuration before stopping nginx
		if ! test_config; then
			log_end_msg 1 # Configuration error
			exit $?
		fi

		stop_nginx
		case "$?" in
			0|1)
				start_nginx
				case "$?" in
					0) log_end_msg 0 ;;
					1) log_end_msg 1 ;; # Old process is still running
					*) log_end_msg 1 ;; # Failed to start
				esac
				;;
			*)
				# Failed to stop
				log_end_msg 1
				;;
		esac
		;;
	reload|force-reload)
		log_daemon_msg "Reloading $DESC configuration" "$NAME"

		# Check configuration before stopping nginx
		#
		# This is not entirely correct since the on-disk nginx binary
		# may differ from the in-memory one, but that's not common.
		# We prefer to check the configuration and return an error
		# to the administrator.
		if ! test_config; then
			log_end_msg 1 # Configuration error
			exit $?
		fi

		reload_nginx
		log_end_msg $?
		;;
	configtest|testconfig)
		log_daemon_msg "Testing $DESC configuration"
		test_config
		log_end_msg $?
		;;
	status)
		status_of_proc -p $PID "$DAEMON" "$NAME" && exit 0 || exit $?
		;;
	upgrade)
		log_daemon_msg "Upgrading binary" "$NAME"
		upgrade_nginx
		log_end_msg $?
		;;
	rotate)
		log_daemon_msg "Re-opening $DESC log files" "$NAME"
		rotate_logs
		log_end_msg $?
		;;
	*)
		echo "Usage: $NAME {start|stop|restart|reload|force-reload|status|configtest|rotate|upgrade}" >&2
		exit 3
		;;
esac
