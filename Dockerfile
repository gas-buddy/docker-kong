FROM alpine:3.4

MAINTAINER Jean-Charles Sisk <jeancharles@gasbuddy.com>

ARG KONG_REPO=https://github.com/gas-buddy/kong.git
ARG KONG_BRANCH=0.9.7-2-gb

ENV OPENRESTY_VERSION 1.11.2.1
ENV OPENRESTY_PREFIX /opt/openresty
ENV OPENRESTY_BUILD_DEPS "make gcc musl-dev pcre-dev openssl-dev zlib-dev ncurses-dev readline-dev curl git unzip util-linux-dev dnsmasq perl"
ENV OPENRESTY_DEPS "libpcrecpp libpcre16 libpcre32 openssl libssl1.0 pcre libgcc libstdc++"
ENV LUAROCKS_VERSION 2.4.0

ENV TINI_VERSION 0.9.0

ENV PATH=${OPENRESTY_PREFIX}/bin:$PATH

RUN addgroup kong && adduser -SDHG kong kong

RUN apk add -U su-exec

RUN apk add --no-cache --virtual .tini-deps ca-certificates openssl gnupg wget perl && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 0527A9B7 && \
    wget -O tini "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static" && \
    wget -O tini.asc "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static.asc" && \
    gpg --verify-files tini.asc && \
    install -t /usr/local/bin/ tini && \
    rm -r tini tini.asc "$GNUPGHOME" && \
    apk del .tini-deps

RUN apk update \
  && apk add --virtual tmp-build-deps $OPENRESTY_BUILD_DEPS \
  && cd /tmp \
  && curl -sSL http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -xvz \
  && cd openresty-${OPENRESTY_VERSION} \
  && ./configure \
       --prefix=$OPENRESTY_PREFIX \
       --with-luajit \
       --with-pcre-jit \
       --with-ipv6 \
       --with-http_realip_module \
       --with-http_ssl_module \
       --with-http_stub_status_module \
       --without-http_ssi_module \
       --without-http_userid_module \
       --without-http_uwsgi_module \
       --without-http_scgi_module \
  && make \
  && make install \
  && ln -s $OPENRESTY_PREFIX/nginx/sbin/nginx /usr/local/bin/nginx \
  && apk add $OPENRESTY_DEPS \
  && rm -rf /tmp/openresty-*

RUN apk add ${OPENRESTY_DEPS} libuuid bash && \
    cd /tmp && \
    curl -sSL http://keplerproject.github.io/luarocks/releases/luarocks-${LUAROCKS_VERSION}.tar.gz | tar -xvz && \
    cd luarocks-* && \
    ./configure \
      --with-lua=${OPENRESTY_PREFIX}/luajit \
      --lua-suffix=jit-2.1.0-beta2 \
      --with-lua-include=${OPENRESTY_PREFIX}/luajit/include/luajit-2.1 && \
    make build && \
    make install && \
    rm -rf /tmp/luarocks-*

RUN cd / && \
    git clone -b ${KONG_BRANCH} --depth 1 ${KONG_REPO} && \
    cd kong && \
    luarocks make kong-*.rockspec && \
    cp /usr/local/lib/lua/5.1/libluabcrypt.so /usr/local/lib/ && \
    mkdir /usr/local/kong && chown kong /usr/local/kong && chgrp kong /usr/local/kong

RUN cd /tmp && \
    curl -sSL https://releases.hashicorp.com/serf/0.8.0/serf_0.8.0_linux_amd64.zip > serf.zip && \
    unzip serf.zip -d /usr/local/bin && \
    rm serf.zip

# Couldn't get it to keep perl and dnsmasq without messing up other stuff... Just reinstalling for now.
RUN apk del tmp-build-deps && \
    apk add perl dnsmasq ca-certificates

COPY entrypoint.sh /entrypoint.sh
COPY kong.conf /etc/kong/kong.conf

ENTRYPOINT ["sh", "/entrypoint.sh"]

CMD [ "kong-app" ]

