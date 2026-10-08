#!/bin/bash
set -e

# Fix ownership only where it is wrong. A recursive chown of every file in
# /prints and /configs on each start is slow on large or network volumes.
find /configs/ /home/orcaslicer/ /prints/ \
  \( ! -user orcaslicer -o ! -group orcaslicer \) \
  -exec chown -h orcaslicer:orcaslicer {} + 2>/dev/null || true
chown orcaslicer:orcaslicer /dev/stdout 2>/dev/null || true

# Give the orcaslicer user access to any GPU device nodes passed in. Their
# group IDs come from the host (usually "video" and "render"), so match by ID.
for dev in /dev/dri/card* /dev/dri/renderD*; do
  [ -e "$dev" ] || continue
  gid=$(stat -c %g "$dev")
  [ "$gid" != 0 ] || continue
  group=$(getent group "$gid" | cut -d: -f1)
  if [ -z "$group" ]; then
    group="hostgpu${gid}"
    groupadd -g "$gid" "$group"
  fi
  usermod -aG "$group" orcaslicer
done

exec gosu orcaslicer supervisord
