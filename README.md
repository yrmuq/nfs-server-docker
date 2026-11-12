<div align="center">

<h1>nfs-server-docker</h1>

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://github.com/yrmuq/nfs-server-docker/blob/main/LICENSE)
[![Image](https://img.shields.io/badge/ghcr.io-image-2496ED?logo=docker&logoColor=white)](https://github.com/yrmuq/nfs-server-docker/pkgs/container/nfs-server-docker)

</div>

An NFSv4.2 server in one container. It loads the host `nfs` and `nfsd` modules, then serves the export list from `NFS_EXPORTS`, so a separate init container and a Compose config are unnecessary. The image is Alpine with `nfs-utils` and keeps the server on TCP port `2049`.

---

> [!NOTE]
> This image is in active development. Behavior and the `NFS_EXPORTS` format can change between builds.

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

`privileged` is required. The container loads `nfsd` and mounts it on `/proc/fs/nfsd`. One kernel NFS server can run on the host.

```yaml
services:

  nfs_server:
    container_name: nfs_server
    image: ghcr.io/yrmuq/nfs-server-docker:latest
    privileged: true
    ports:
      - ${NFS_SERVER}:2049
    volumes:
      - ${NFS_MODULES}:/lib/modules:ro
      - ${LOCATION}/docker/data/nfs:/storage
      - ${LOCATION}/docker:/storage/docker
      - ${HDD}/backups:/storage/backups
      - ${HDD}/media:/storage/media
    environment:
      - TZ=${TZ}
      - NFS_EXPORTS=${NFS_EXPORTS}
    logging:
      driver: json-file
      options:
        max-size: "55m"
        max-file: "1"
    restart: unless-stopped
    networks:
      - homelab

networks:
  homelab:
    external: true
```

`.env`:

```dotenv
TZ=UTC
LOCATION=/home/user
HDD=/mnt/hdd
NFS_SERVER=2049
NFS_MODULES=/lib/modules
NFS_EXPORTS="/storage 192.168.1.100(rw,async,insecure,all_squash,no_subtree_check,crossmnt,anonuid=1000,anongid=1000,fsid=0)\n/storage/docker 192.168.1.100(rw,async,insecure,all_squash,no_subtree_check,anonuid=1000,anongid=1000,fsid=1)\n/storage/backups 192.168.1.100(rw,async,insecure,all_squash,no_subtree_check,anonuid=1000,anongid=1000,fsid=2)\n/storage/media 192.168.1.100(rw,async,insecure,all_squash,no_subtree_check,anonuid=1000,anongid=1000,fsid=3)"
```

`TZ` sets the container clock. `NFS_SERVER` is the host port published to container port `2049`. `NFS_MODULES` is the host kernel module directory for the running kernel. `NFS_EXPORTS` is `/etc/exports` syntax. `\n` separates exports because the value is one line. `insecure` is required when the client source port is not privileged, which includes Docker NAT. `all_squash` writes files as uid `1000` and gid `1000`. `fsid=0` makes `/storage` the path clients mount as `SERVER:/`.

```bash
docker compose pull
docker compose up -d
```

The same commands update a container that is already running. Replacing the container does not change the host directories mounted into it.

| Container Path | Purpose |
| --- | --- |
| `/lib/modules` | Host kernel modules, read-only, so `modprobe` can load `nfs` and `nfsd`. |
| `/storage` | NFSv4 root, `fsid=0`. |
| `/storage/docker` | Docker data export. |
| `/storage/backups` | Backups export. |
| `/storage/media` | Media export. |

### Usage

Each export path must exist inside the container. Mount the share with NFSv4.2:

```bash
mount -t nfs4 -o vers=4.2 SERVER:/ /mnt
```

`SERVER:/docker`, `SERVER:/backups`, and `SERVER:/media` are the other three exports.

---

## License & Attribution

The files in this repository are under `GPL-3.0-or-later`. See [LICENSE](https://github.com/yrmuq/nfs-server-docker/blob/main/LICENSE). The image installs `nfs-utils` from Alpine; that package is `GPL-2.0-only` and is not vendored here.

| Component | Upstream | License | Integration Details |
| --- | --- | --- | --- |
| `nfs-utils` | [steved/nfs-utils](https://git.linux-nfs.org/?p=steved/nfs-utils.git) | `GPL-2.0-only` | `rpc.nfsd`, `rpc.mountd`, and `exportfs` installed from Alpine. |
| `kmod` | [kmod-project/kmod](https://github.com/kmod-project/kmod) | `GPL-2.0-or-later` | `modprobe` in the image. |
| Alpine | [alpinelinux/docker-alpine](https://github.com/alpinelinux/docker-alpine) | `MIT` | Base image. |
