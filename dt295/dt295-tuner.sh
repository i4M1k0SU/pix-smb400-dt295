#!/bin/sh
# dt295-tuner.sh -- Mirakurun tuner command for a PIX-DT295(W) / PIX-DT195(W) unit
# on the PIX-SMB400.
#
# Usage (tuners.yml):  /data/local/tmp/dt295/dt295-tuner.sh <serial> [<tuner>] <channel>
#
# <tuner>: 1 (without it), or 2 for the second tuner of a unit with two, which streams
# beside its first (one tuners.yml entry per tuner). A unit with one tuner has tuner 1 only.
# Mirakurun puts the channel in as one argument, always the last, so the number of
# arguments tells whether a tuner is given.
#
# Takes the channel names of the SMB400's own tuner (smb400-tuner.sh), so one
# channels.yml serves both tuners, and runs `dt295 tune` (Mirakurun runs it inside
# its Alpine chroot; `dt295 serve` runs outside, see start_dt295.sh):
#   GR:  13-62     UHF channel        -> --ter <Hz>
#   BS:  BSxx_y    transponder xx, TS -> --sat <IF Hz> --tsid <hex>, the TSID from
#                  bs_tsid.conf (the SMB400's table, "<channel> <decimal TSID>")
#   CS:  NDxx      transponder xx     -> --sat <IF Hz> (one TS per transponder)
# BS4K (ISDB-S3) is not something the PIX-DT295(W) / PIX-DT195(W) receive.
#
# The unit runs in raw-TS mode (raw-ts = true in dt295.conf): no firmware, every
# service of the TS, still scrambled. The SMB400's own descrambler b21dec (MULTI2
# keys from the box's ACAS chip, as smb400-tuner.sh does) clears it here, so
# Mirakurun gets a plain TS, the same as from the box's tuner. b21dec needs the
# Android linker and libraries, so it runs under chroot /proc/1/root.
#
# Mirakurun starts this command in a process group of its own and stops it by
# signalling the group, which reaches both ends of the pipe.

USAGE="usage: $0 <serial> [<tuner>] <channel>"
case $# in
2) SERIAL=$1 TUNER=1 CHANNEL=$2 ;;
3) SERIAL=$1 TUNER=$2 CHANNEL=$3 ;;
*) SERIAL= ;;
esac
DT295=${DT295:-/data/local/tmp/dt295/dt295}
CONF=${DT295_CONF:-/data/local/tmp/dt295/dt295.conf}
B21DEC=${B21DEC:-/data/local/tmp/b21dec}
BS_TSID_CONF=${BS_TSID_CONF:-/data/local/tmp/bs_tsid.conf}

fail() {
    echo "dt295-tuner.sh: $*" >&2
    exit 1
}

[ -n "$SERIAL" ] && [ -n "$CHANNEL" ] || fail "$USAGE"
case "$TUNER" in
1 | 2) ;;
*) fail "unknown tuner '$TUNER' (1, or 2 on a unit with two tuners)" ;;
esac

case "$CHANNEL" in
4[0-9][0-9][0-9][0-9])
    fail "BS4K channel '$CHANNEL': the PIX-DT295(W) / PIX-DT195(W) do not receive ISDB-S3"
    ;;
[0-9] | [0-9][0-9])
    CH=$((10#$CHANNEL))
    [ "$CH" -ge 13 ] && [ "$CH" -le 62 ] || fail "unknown GR channel '$CHANNEL' (UHF 13-62)"
    set -- --ter $((473142857 + (CH - 13) * 6000000))
    ;;
BS[0-9][0-9]_[0-9])
    TP=${CHANNEL#BS}
    TP=$((10#${TP%_*}))
    TSID=
    if [ -f "$BS_TSID_CONF" ]; then
        while read -r ch tsid _; do
            if [ "$ch" = "$CHANNEL" ]; then
                TSID=$tsid
                break
            fi
        done < "$BS_TSID_CONF"
    fi
    [ -n "$TSID" ] || fail "unknown BS channel '$CHANNEL' (not in $BS_TSID_CONF)"
    set -- --sat $(((1049480 + (TP - 1) / 2 * 38360) * 1000)) --tsid "$(printf '%x' "$TSID")"
    ;;
ND[0-9][0-9])
    ND=$((10#${CHANNEL#ND}))
    case $ND in
    2 | 4 | 6 | 8 | 10 | 12 | 14 | 16 | 18 | 20 | 22 | 24) ;;
    *) fail "unknown CS channel '$CHANNEL' (ND02-ND24, even)" ;;
    esac
    set -- --sat $(((1613000 + (ND - 2) / 2 * 40000) * 1000))
    ;;
*)
    fail "unknown channel format '$CHANNEL'"
    ;;
esac
set -- --tuner "$TUNER" "$@"

# In the background, so that a signal to this shell alone (timeout(1), a test by
# hand) also ends the pipe: the trap stops b21dec, and dt295 tune ends when its
# reader is gone. $! is b21dec (chroot execs it).
"$DT295" tune -c "$CONF" --serial "$SERIAL" "$@" | chroot /proc/1/root "$B21DEC" &
PIPE=$!
trap 'kill "$PIPE" 2>/dev/null; exit 0' TERM INT HUP
wait "$PIPE"
