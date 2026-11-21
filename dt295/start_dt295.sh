#!/system/bin/sh
# start_dt295.sh -- run `dt295 serve` on a PIX-SMB400 (Android 8, root shell).
#
# The daemon runs in the Android namespace, outside Mirakurun's Alpine chroot:
# Android has /dev/bus/usb and /sys, while the chroot's /dev is a tmpfs without
# the USB nodes. Mirakurun runs `dt295 tune` inside the chroot, which reaches the
# socket at the same path through the chroot's bind mount of /data/local/tmp.
#
# Usage: start_dt295.sh [start|stop|status]     (default: start)
#
# Files, all in $DIR: dt295 (the armv7-unknown-linux-musleabihf build), dt295.conf
# (units in raw-TS mode, so no firmware), dt295.log (the previous run's is kept as
# dt295.log.1).

DIR=/data/local/tmp/dt295
CONF=$DIR/dt295.conf
LOG=$DIR/dt295.log
PIDFILE=$DIR/dt295.pid

# True only if the PID in the pidfile is alive and runs $DIR/dt295: PIDs are reused
# after a reboot. The executable's link, not /proc/<pid>/cmdline: on this kernel a
# read of the cmdline of a process that is exiting never returned (stop hung).
running() {
    p=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$p" ] && kill -0 "$p" 2>/dev/null &&
        case $(readlink "/proc/$p/exe" 2>/dev/null) in
        "$DIR/dt295"*) true ;;
        *) false ;;
        esac
}

case "${1:-start}" in
start)
    if running; then
        echo "dt295 serve: already running (pid $(cat "$PIDFILE"))"
        exit 0
    fi
    for f in "$DIR/dt295" "$CONF"; do
        if [ ! -e "$f" ]; then
            echo "dt295 serve: missing $f" >&2
            exit 1
        fi
    done
    [ -f "$LOG" ] && mv -f "$LOG" "$LOG.1"
    # setsid: dt295 stops on SIGHUP, which the end of an adb shell session sends.
    # nice -10, as Mirakurun and its tuner commands (b21dec) run: the raw-TS loop must
    # pump the unit every few ms, and at nice 0 a busy Mirakurun (EPG gathering, a
    # stream starting) delays it until the unit's ring overflows: TS lost (CC errors).
    setsid nice -n -10 "$DIR/dt295" serve -c "$CONF" >> "$LOG" 2>&1 < /dev/null &
    echo $! > "$PIDFILE"
    sleep 1
    if ! running; then
        echo "dt295 serve: exited at once; the end of $LOG:" >&2
        tail -5 "$LOG" >&2
        rm -f "$PIDFILE"
        exit 1
    fi
    echo "dt295 serve: started (pid $(cat "$PIDFILE")), log $LOG"
    ;;
stop)
    if running; then
        # SIGTERM: the daemon stops its streams and saves the state files first.
        kill "$(cat "$PIDFILE")"
        i=0
        while running && [ $i -lt 10 ]; do
            sleep 1
            i=$((i + 1))
        done
        if running; then
            echo "dt295 serve: still running after 10 s" >&2
            exit 1
        fi
        echo "dt295 serve: stopped"
    else
        echo "dt295 serve: not running"
    fi
    rm -f "$PIDFILE"
    ;;
status)
    if running; then
        echo "dt295 serve: running (pid $(cat "$PIDFILE"))"
    else
        echo "dt295 serve: not running"
        exit 1
    fi
    ;;
*)
    echo "usage: $0 [start|stop|status]" >&2
    exit 2
    ;;
esac
