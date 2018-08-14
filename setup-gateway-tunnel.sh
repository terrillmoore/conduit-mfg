#!/bin/sh

# safety check
if [ ! -e /etc/mlinux-version ]; then
   echo "Not running on mLinux" >&2
   exit 1
fi

function _error {
	echo "$@" 1>&2
	exit 1
}

# check that JUMPHOST and JUMPADMIN are set
if [ X"$JUMPHOST" = X ]; then
	_error "JUMPHOST not defined -- see instructions"
fi
# if [ X"$JUMPADMIN" = X ]; then
#	_error "JUMPADMIN not defined -- see instructions"
# fi
if [ X"$JUMPPORT" = X ]; then
	_error "JUMPPORT not defined -- see instructions"
fi
# if [ X"$MYPREFIX" = X ]; then
#	_error "MYPREFIX not defined -- see instructions"
# fi
if [ X"$JUMPUID" = X ]; then
	_error "JUMPUID not defined -- see instructions"
fi
if [ X"$KEEPALIVE" = X ]; then
	_error "KEEPALIVE not defined -- see instructions"
fi
if [ X"$MYNAME" = X ]; then
	_error "MYNAME not defined -- see instructions"
fi
if [ X"$MYPUBKEY" = X ]; then
	_error "MYPUBKEY not defined -- see instructions"
elif [ ! -f "$MYPUBKEY" ]; then
	_error "MYPUBKEY not readable: $MYPUBKEY"
fi

# get the date right
ntpdate -ub pool.ntp.org || _error "Couldn't set date/time"

function _mkdir { # $1: path. $2 mode $3 owner $4 group
	if [ ! -d "$1" ]; then
		mkdir -m $2 "$1" || _error "Can't create dir: $1"
		chown $3.$4 "$1" || _error "Can't set permissions: $1"
	fi
}
# no point in doing this without ssh set up
_mkdir /var/config/home 755 root root
_mkdir /var/config/home/root 700 root root
_mkdir /var/config/home/root/.ssh 700 root root

if [ ! -f /var/config/home/root/.ssh/authorized_keys ]; then
	if [ -f ~root/.ssh/authorized_keys ]; then
		cat ~root/.ssh/authorized_keys >/var/config/home/root/.ssh/authorized_keys
	else
		touch /var/config/home/root/.ssh/authorized_keys || _error "Can't create authorized_keys"
	fi
	chmod 700 /var/config/home/root/.ssh/authorized_keys || _error "Can't chmod authorized keys"
fi
cat "$MYPUBKEY" >> /var/config/home/root/.ssh/authorized_keys

# if no ~root/.ssh, link it
# if ~root/.ssh and not a link, rm and link it
# if ~root/.ssh and a link, simply relink it
if [ ! -d ~root/.ssh ]; then
	ln -fs /var/config/home/root/.ssh ~root || _error "Can't add symlink to ~root/.ssh"
elif [ ! -L ~root/.ssh ]; then
	# somewhat unpleasant and not atomic,but...
	mv ~root/.ssh ~root/.ssh.old || _error "Can't move ~root/.ssh"
	ln -s /var/config/home/root/.ssh ~root || _error "Can't replace to ~root/.ssh"
else
	# atomic update of link, maybe no change.
	ln -fs /var/config/home/root/.ssh ~root || _error "Can't update symlink to ~root/.ssh"
fi

# set up the parameters for the ssh setup
echo "Set up ssh tunnel"
cat << EOF > /etc/default/ssh_tunnel
DAEMON=/usr/bin/autossh
LOCAL_PORT=22
REMOTE_HOST="$JUMPHOST"
REMOTE_USER="$MYNAME"
REMOTE_PORT="$JUMPUID"
SSH_KEY="/etc/ssh/ssh_host_rsa_key.pub"
SSH_PORT=22
DAEMON_ARGS="-f -M ${KEEPALIVE} -o ServerAliveInterval=30 -o StrictHostKeyChecking=no -i /etc/ssh/ssh_host_rsa_key"
EOF

chmod 755 /etc/default/ssh_tunnel || _error "can't chmod defaults"
chown root.root /etc/default/ssh_tunnel || _error "can't chown defaults"

# update the ssh_tunnel script
cat << 'EOF' > /etc/init.d/ssh_tunnel
#!/bin/sh
#
#remote_server_connect.sh connect to remote server for ssh tunnel back

### BEGIN INIT INFO
# Provides:          open-remote-tunnel
# Required-Start:    $local_fs $network $syslog $dbus
# Required-Stop:     $local_fs $network $syslog $dbus
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       ssh to remote system for reverse tunnel and remote control
### END INIT INFO

PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
NAME=ssh_tunnel
DAEMON=/usr/bin/ssh
LOCAL_PORT=22
REMOTE_USER=
SSH_KEY=
REMOTE_HOST=
REMOTE_PORT=
DAEMON_ARGS=
PIDFILE=/var/run/${NAME}.pid

# source function library
. /etc/init.d/functions

if [ -r /etc/default/${NAME} ]; then
        . /etc/default/${NAME}
fi

[ -x ${DAEMON} ] || exit 0

if [ -z "${LOCAL_PORT}" -o -z "${REMOTE_HOST}" -o -z "${REMOTE_PORT}" -o -z "${REMOTE_USER}" ]; then
   exit 1
fi
DAEMON_ARGS="$DAEMON_ARGS -N -T -R ${REMOTE_PORT}:localhost:${LOCAL_PORT} ${REMOTE_USER}@${REMOTE_HOST}"
if [ -n "$SSH_KEY" ]; then
    DAEMON_ARGS="$DAEMON_ARGS -i ${SSH_KEY}"
fi
if [ -n "$SSH_PORT" ]; then
    DAEMON_ARGS="$DAEMON_ARGS -p ${SSH_PORT}"
fi

is_running() {
    pgrep -x $(basename ${DAEMON}) > /dev/null
}

start() {
    start-stop-daemon --start --quiet --exec ${DAEMON} -- ${DAEMON_ARGS}
}

stop() {
    start-stop-daemon --stop --quiet --exec ${DAEMON}
}

case "$1" in
    start)
	is_running || start
	;;
    stop)
	stop
	;;
    restart|reload)
	stop
	start
	;;
    status)
	is_running
	;;
    *)
	echo "Usage: $0 {start|stop|status|restart}"
esac
#=========================================
EOF

chmod 755 /etc/init.d/ssh_tunnel		|| _error "can't chmod ssh_tunnel"
chown root.root /etc/init.d/ssh_tunnel		|| _error "can't chown ssh_tunnel"
/etc/init.d/ssh_tunnel restart 			|| _error "can't restart ssh_tunnel"

echo "OK"
exit 0
