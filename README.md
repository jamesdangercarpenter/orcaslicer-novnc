# OrcaSlicer noVNC Docker Container

## Overview

This is a super basic noVNC build using supervisor to serve OrcaSlicer in your favorite web browser. This was primarily built for users using the [popular unraid NAS software](https://unraid.net), to allow them to quickly hop in a browser, slice, and upload their favorite 3D prints.

A lot of this was branched off of dmagyar's awesome [prusaslicer-vnc-docker](https://hub.docker.com/r/dmagyar/prusaslicer-vnc-docker/) project, but I found it to be a bit complex for my needs and thought this approach would simplify things a lot.

## How to use

**In unraid**

If you're using unraid, open your Docker page and under `Template repositories`, add `https://github.com/helfrichmichael/unraid-templates` and save it. You should then be able to Add Container for orcaslicer-novnc. For unraid, the template will default to 6080 for the noVNC web instance.

**Outside of unraid**

To run this image, you can run the following command: `docker run --detach --volume=orcaslicer-novnc-data:/configs/ --volume=orcaslicer-novnc-prints:/prints/ -p 8080:8080 -e SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt" 
--name=orcaslicer-novnc orcaslicer-novnc`

This will bind `/configs/` in the container to a local volume on my machine named `orcaslicer-novnc-data`. Additionally it will bind `/prints/` in the container to `orcaslicer-novnc-prints` locally on my machine, it will bind port `8080` to `8080`, and finally, it will provide an environment variable to keep OrcaSlicer happy by providing an `SSL_CERT_FILE`.

## GPU acceleration

Without a GPU, OrcaSlicer's 3D view is drawn on the CPU (Mesa llvmpipe), which is slow for large plates. If the container can see a GPU under `/dev/dri`, OrcaSlicer is started through [VirtualGL](https://virtualgl.org) so OpenGL renders on the GPU instead. AMD Radeon GPUs (including the Radeon 780M iGPU) work through Mesa's `radeonsi` driver; the host only needs the `amdgpu` kernel driver loaded.

With Docker, add `--device /dev/dri`.

On Kubernetes, the pod needs the host's `/dev/dri`. The simplest way is a privileged container with a `hostPath` volume:

```yaml
spec:
  containers:
    - name: orcaslicer
      image: enkitech/orcaslicer-novnc:latest
      securityContext:
        privileged: true
      volumeMounts:
        - name: dri
          mountPath: /dev/dri
  volumes:
    - name: dri
      hostPath:
        path: /dev/dri
```

A device plugin (for example [generic-device-plugin](https://github.com/squat/generic-device-plugin) or AMD's [k8s-device-plugin](https://github.com/ROCm/k8s-device-plugin)) avoids running privileged and schedules pods only onto nodes with a GPU.

The container adds its user to the device nodes' groups at startup, so no `supplementalGroups` are needed. The OrcaSlicer log (`kubectl logs`) prints which renderer is in use:

- `Rendering OpenGL on /dev/dri/card0 via VirtualGL`: GPU.
- `Rendering OpenGL on the CPU (llvmpipe, N threads)`: no GPU found. `N` follows the pod's CPU limit.

Environment variables:

- `ORCASLICER_GPU`: `auto` (default) uses a GPU if found, `on` fails without one, `off` always uses the CPU.
- `VGL_DISPLAY`: pick a specific card, e.g. `/dev/dri/card1`, on hosts with more than one.

## Links

[OrcaSlicer](https://github.com/SoftFever/OrcaSlicer)

[Supervisor](http://supervisord.org/)

[GitHub Source](https://github.com/helfrichmichael/orcaslicer-novnc)

[Docker](https://hub.docker.com/r/mikeah/orcaslicer-novnc)

<a href="https://www.buymeacoffee.com/helfrichmichael" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>
