<div align="center">

<h1>nfs-server-docker</h1>

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://github.com/yrmuq/nfs-server-docker/blob/main/LICENSE)
[![Image](https://img.shields.io/badge/ghcr.io-image-2496ED?logo=docker&logoColor=white)](https://github.com/yrmuq/nfs-server-docker/pkgs/container/nfs-server-docker)

</div>

---

> [!NOTE]
> This image is in active development. Behavior and the `NFS_EXPORTS` format can change between builds.

---

An NFSv4.2 server in one container. It loads the host `nfs` and `nfsd` modules, then serves the export list from `NFS_EXPORTS`, so a separate init container and a Compose config are unnecessary. The image is Alpine with `nfs-utils` and keeps the server on TCP port `2049`.

---

## Features

- NFSv4.2 only. Clients use TCP port `2049`. NFS v2 and v3 stay off, so `rpcbind` is not required.
- The server container loads the host `nfs` and `nfsd` modules.
- The export list comes from `NFS_EXPORTS`. A mounted `/etc/exports` is used when that variable is empty.
- Published images cover `x86_64` and `arm64`.

---

## Installation & Usage

### Architecture & Format Support

| Architecture | Status |
| --- | :---: |
| `x86_64` | ✅ |
| `arm64` | ✅ |

Stable releases are `X.Y.0`. A merge of `dev` into `main` raises `Y` and sets `Z` to `0`. Versions with `Z > 0` are automatic dependency-update prereleases, not stable releases. No stable release has been published yet. Published versions are listed on the [releases page](https://github.com/yrmuq/nfs-server-docker/releases).

`latest` is moved only for a stable release. `ghcr.io/yrmuq/nfs-server-docker:dev` tracks `dev` and is not a stable image. Until the first stable release, use that tag or build the checkout:

```bash
docker build -t ghcr.io/yrmuq/nfs-server-docker:local .
```

### Docker Compose

`privileged` is required. The container loads `nfsd` and mounts it on `/proc/fs/nfsd`. `network_mode: host` places that server on the host address, so there is no `homelab` network and no published port. One kernel NFS server can run on the host.

```yaml
services:

  nfs_server:
    container_name: nfs_server
    image: ghcr.io/yrmuq/nfs-server-docker:latest
    privileged: true
    network_mode: host
    volumes:
      - /lib/modules:/lib/modules:ro
      - ${SHARE}:/storage
    environment:
      TZ: ${TZ}
      NFS_EXPORTS: |
        /storage ${ALLOWED_IP}(rw,async,insecure,all_squash,no_subtree_check,anonuid=1000,anongid=1000,fsid=0)
    logging:
      driver: json-file
      options:
        max-size: "55m"
        max-file: "1"
    restart: unless-stopped
```

`.env`:

```dotenv
TZ=UTC
SHARE=/mnt/share
ALLOWED_IP=192.168.1.10
```

`TZ` sets the container clock. `SHARE` is the host directory to export. The container sees it as `/storage`. `ALLOWED_IP` is the client allowed to mount it. `all_squash` writes every file as uid `1000` and gid `1000`. `fsid=0` makes `/storage` the path clients mount as `SERVER:/`. `insecure` allows a client whose source port is not privileged. A second host directory is a separate mount and needs its own export line with another `fsid`. Add `crossmnt` on the first line so a client can walk into that directory.

```bash
docker compose pull
docker compose up -d
```

The same commands update a container that is already running. Replacing the container does not change the host directory mounted into it.

| Container Path | Purpose |
| --- | --- |
| `/lib/modules` | Host kernel modules, read-only, so `modprobe` can load `nfs` and `nfsd`. |
| `/storage` | Exported directory. The example bind-mounts `SHARE` here. |

### Usage

The export path must exist inside the container. Mount the share with NFSv4.2:

```bash
mount -t nfs4 -o vers=4.2 SERVER:/ /mnt
```

---

## License & Attribution

The files in this repository are under `GPL-3.0-or-later`. See [LICENSE](https://github.com/yrmuq/nfs-server-docker/blob/main/LICENSE). The image installs `nfs-utils` from Alpine; that package is `GPL-2.0-only` and is not vendored here.

| Component | Upstream | License | Integration Details |
| --- | --- | --- | --- |
| `nfs-utils` | [steved/nfs-utils](https://git.linux-nfs.org/?p=steved/nfs-utils.git) | `GPL-2.0-only` | `rpc.nfsd`, `rpc.mountd`, and `exportfs` installed from Alpine. |
| `kmod` | [kmod-project/kmod](https://github.com/kmod-project/kmod) | `GPL-2.0-or-later` | `modprobe` in the image. |
| Alpine | [alpinelinux/docker-alpine](https://github.com/alpinelinux/docker-alpine) | `MIT` | Base image. |
