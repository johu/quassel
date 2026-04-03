FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG GIT_HEAD=""
ARG GIT_DESCRIBE=""

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    gettext \
    git \
    libboost-dev \
    libqt6sql6-psql \
    libqt6sql6-sqlite \
    libssl-dev \
    ninja-build \
    pkg-config \
    qt6-5compat-dev \
    qt6-base-dev \
    qt6-base-dev-tools \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY . .

ENV GIT_HEAD=${GIT_HEAD}
ENV GIT_DESCRIBE=${GIT_DESCRIBE}

RUN cmake -S . -B build -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/opt/quassel \
    -DWANT_CORE=ON \
    -DWANT_QTCLIENT=OFF \
    -DWANT_MONO=OFF \
    -DWITH_KDE=OFF \
    -DWITH_WEBENGINE=OFF \
    && cmake --build build \
    && cmake --install build \
    && runtime_root=/opt/runtime-root \
    && multiarch="$(gcc -print-multiarch)" \
    && mkdir -p "$runtime_root/opt/quassel" "$runtime_root/opt/quassel/plugins/sqldrivers" "$runtime_root/opt/quassel/plugins/tls" "$runtime_root/etc/ssl" \
    && cp -a /opt/quassel/bin /opt/quassel/lib "$runtime_root/opt/quassel/" \
    && cp -a "/usr/lib/${multiarch}/qt6/plugins/sqldrivers/." "$runtime_root/opt/quassel/plugins/sqldrivers/" \
    && cp -a "/usr/lib/${multiarch}/qt6/plugins/tls/." "$runtime_root/opt/quassel/plugins/tls/" \
    && if [ -f /etc/ssl/openssl.cnf ]; then \
        cp -a /etc/ssl/openssl.cnf "$runtime_root/etc/ssl/"; \
    elif [ -f /usr/lib/ssl/openssl.cnf ]; then \
        cp -a /usr/lib/ssl/openssl.cnf "$runtime_root/etc/ssl/openssl.cnf"; \
    fi \
    && if [ -d "/usr/lib/${multiarch}/ossl-modules" ]; then \
        mkdir -p "$runtime_root/usr/lib/${multiarch}/ossl-modules"; \
        cp -a "/usr/lib/${multiarch}/ossl-modules/." "$runtime_root/usr/lib/${multiarch}/ossl-modules/"; \
    fi \
    && interpreter="$(readelf -l /opt/quassel/bin/quasselcore | awk '/Requesting program interpreter/ { print $4 }' | tr -d '[]')" \
    && mkdir -p "$runtime_root$(dirname "$interpreter")" \
    && cp -L "$interpreter" "$runtime_root$interpreter" \
    && collect_libs() { \
        ldd "$1" | awk '/=> \// { print $3 } /^\// { print $1 }'; \
    } \
    && { \
        collect_libs /opt/quassel/bin/quasselcore; \
        for path in /opt/quassel/lib/*.so* "$runtime_root"/opt/quassel/plugins/sqldrivers/*.so "$runtime_root"/opt/quassel/plugins/tls/*.so; do \
            [ -e "$path" ] && collect_libs "$path"; \
        done; \
    } | sort -u | while read -r lib; do \
        dest="$runtime_root$(dirname "$lib")"; \
        mkdir -p "$dest"; \
        cp -L "$lib" "$dest/"; \
    done

FROM alpine:3.21 AS runtime

RUN apk add --no-cache \
    ca-certificates \
    postgresql16-client \
    tini \
    && mkdir -p /var/lib/quassel

COPY --from=builder /opt/runtime-root/ /
COPY docker/entrypoint.sh /usr/local/bin/quassel-entrypoint.sh

RUN chmod +x /usr/local/bin/quassel-entrypoint.sh

ENV PATH="/opt/quassel/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/quassel/lib:/lib:/usr/lib:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu" \
    OPENSSL_CONF="/etc/ssl/openssl.cnf" \
    QT_PLUGIN_PATH="/opt/quassel/plugins" \
    QUASSEL_CONFIGDIR=/var/lib/quassel \
    WAIT_FOR_POSTGRES=1

WORKDIR /var/lib/quassel

VOLUME ["/var/lib/quassel"]

EXPOSE 4242

ENTRYPOINT ["tini", "--", "/usr/local/bin/quassel-entrypoint.sh"]
CMD ["quasselcore"]
