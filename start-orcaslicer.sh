#!/bin/bash
#
# Launch OrcaSlicer, rendering OpenGL on a GPU when one is available.
#
# Xtigervnc has no GPU, so by default every frame of the 3D view is drawn on
# the CPU by Mesa's llvmpipe. When a DRI device (e.g. an AMD Radeon iGPU) is
# passed into the container, VirtualGL redirects OpenGL rendering to it and
# copies the finished frames into the VNC display.
#
# ORCASLICER_GPU   auto (default) | on | off
# VGL_DISPLAY      override the DRI card VirtualGL renders on, e.g. /dev/dri/card1

orca=(/orcaslicer/squashfs-root/AppRun --datadir /configs/)

# Print the first /dev/dri/cardN backed by a render-capable GPU.
find_gpu() {
  local card name
  for card in /dev/dri/card*; do
    [ -e "$card" ] || continue
    name=${card##*/}
    if compgen -G "/sys/class/drm/${name}/device/drm/renderD*" >/dev/null &&
      [ -r "$card" ] && [ -w "$card" ]; then
      echo "$card"
      return 0
    fi
  done
  return 1
}

# llvmpipe starts one thread per host CPU, which thrashes under a Kubernetes
# CPU limit. Size it to the container's CPU quota instead.
cpu_quota() {
  local quota period
  read -r quota period 2>/dev/null </sys/fs/cgroup/cpu.max || return 1
  [ "$quota" != "max" ] || return 1
  echo $(((quota + period - 1) / period))
}

mode=${ORCASLICER_GPU:-auto}
if [ "$mode" != "off" ]; then
  gpu=${VGL_DISPLAY:-$(find_gpu)}
  if [ -n "$gpu" ]; then
    echo "Rendering OpenGL on ${gpu} via VirtualGL"
    exec /opt/VirtualGL/bin/vglrun -d "$gpu" "${orca[@]}"
  fi
  if [ "$mode" = "on" ]; then
    echo "ORCASLICER_GPU=on but no usable /dev/dri/card* device was found" >&2
    exit 1
  fi
fi

if [ -z "${LP_NUM_THREADS:-}" ] && threads=$(cpu_quota); then
  export LP_NUM_THREADS=$threads
fi
echo "Rendering OpenGL on the CPU (llvmpipe, ${LP_NUM_THREADS:-all} threads)"
exec "${orca[@]}"
