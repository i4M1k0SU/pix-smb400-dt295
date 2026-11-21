# 90-dt295.sh -- start `dt295 serve` when the PIX-SMB400 boots.
#
# Sourced by Alpine's login shell before Mirakurun starts (linked from /etc/profile.d
# of Mirakurun's chroot). Return to Android's root so the daemon can access the host
# USB devices. start_dt295.sh does nothing if the daemon is already running.
if [ -d /proc/1/root/system/bin ]; then
    chroot /proc/1/root /system/bin/sh -c '
        export PATH=/system/bin:/system/xbin:/vendor/bin
        script=/data/local/tmp/dt295/start_dt295.sh
        if [ -f "$script" ]; then
            /system/bin/sh "$script" ||
                echo "90-dt295.sh: failed to start: $script" >&2
        fi
    ' >> /data/local/tmp/dt295/start_dt295.log 2>&1 || :
fi
