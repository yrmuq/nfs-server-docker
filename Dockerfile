FROM alpine:3.24 AS nfs
RUN apk add --no-cache nfs-utils

FROM alpine:3.24
LABEL org.opencontainers.image.source="https://github.com/yrmuq/nfs-server-docker"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

RUN apk add --no-cache \
        kmod \
        libblkid \
        libmount \
        libuuid \
        libcap \
        libcom_err \
        device-mapper-libs \
        libevent \
        krb5-libs \
        keyutils-libs \
        sqlite-libs \
        libtirpc

COPY --from=nfs /usr/sbin/rpc.nfsd /usr/sbin/rpc.mountd /usr/sbin/exportfs /usr/sbin/
COPY --from=nfs /usr/lib/libnfsidmap* /usr/lib/
COPY --from=nfs /var/lib/nfs /var/lib/nfs
RUN ldd /usr/sbin/rpc.nfsd /usr/sbin/rpc.mountd /usr/sbin/exportfs >/dev/null \
    && : > /etc/exports

COPY --chmod=555 entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
