#!/bin/sh
# Copyright (C) 2026 yrmuq
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

# shortcut: printf %b splits Compose single-line exports on \n; replace it if an export needs other backslash escapes

exports_text() {
    printf '%b\n' "$1" | sed '/^[[:space:]]*$/d'
}

stop() {
    /usr/sbin/rpc.nfsd 0 || true
    killall rpc.mountd || true
    umount /proc/fs/nfsd || true
    exit 0
}

# NFS_DRY_RUN prints the export list and exits. Tests and the image startup check use it.
if [ "${NFS_DRY_RUN:-}" = 1 ]; then
    text=$(exports_text "${NFS_EXPORTS:-}")
    if [ -z "$text" ]; then
        echo "NFS_EXPORTS is empty" >&2
        exit 1
    fi
    printf '%s\n' "$text"
    exit 0
fi

trap stop TERM INT

if ! modprobe nfs; then
    echo "modprobe nfs failed; mount the host /lib/modules and run privileged" >&2
    exit 1
fi
if ! modprobe nfsd; then
    echo "modprobe nfsd failed; mount the host /lib/modules and run privileged" >&2
    exit 1
fi

mount -t nfsd nfsd /proc/fs/nfsd

if [ -n "${NFS_EXPORTS:-}" ]; then
    text=$(exports_text "$NFS_EXPORTS")
    if [ -z "$text" ]; then
        echo "NFS_EXPORTS is empty" >&2
        exit 1
    fi
    printf '%s\n' "$text" > /etc/exports
fi

if [ ! -s /etc/exports ]; then
    echo "NFS_EXPORTS is empty and /etc/exports has no exports" >&2
    exit 1
fi

/usr/sbin/rpc.nfsd --tcp --no-udp --port 2049 --grace-time 10 --nfs-version 4.2 --no-nfs-version 3
/usr/sbin/exportfs -r
/usr/sbin/rpc.mountd --foreground --port 32767 --nfs-version 4.2 --no-nfs-version 2 --no-nfs-version 3 &
wait
