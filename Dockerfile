FROM debian:bullseye-slim

#
# OpenSSL Configuration
#

ENV OPENSSL_VERSION 3.0.5
ENV OPENSSL_SHA256 aa7d8d9bef71ad6525c55ba11e5f4397889ce49c2c9349dcea6d3e4f0b024a7a

#
# Build OpenSSL
# https://github.com/arhea/docker-fips-library/blob/master/alpine/Dockerfile
#

RUN apt update \
    && cd /tmp \
    && apt install -y --no-install-recommends \
        wget \
        gcc \
        libc-dev \
        ca-certificates \
        perl \
        make \
        coreutils \
        gnupg \
    && wget --quiet --no-check-certificate https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz \
    && wget --quiet --no-check-certificate https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz.asc \
    && echo "$OPENSSL_SHA256 openssl-$OPENSSL_VERSION.tar.gz" | sha256sum -c - | grep OK \
    && tar -xzf openssl-$OPENSSL_VERSION.tar.gz \
    && cd openssl-$OPENSSL_VERSION \
    && ./Configure enable-fips \
    && make \
    && make install \
    && echo "/usr/local/lib64" > /etc/ld.so.conf.d/openssl.conf \
    && ldconfig

COPY openssl.cnf /usr/local/ssl/openssl.cnf

#
# Apache Configuration
#

ENV HTTPD_VERSION 2.4.54
ENV HTTPD_SHA256 c687b99c446c0ef345e7d86c21a8e15fc074b7d5152c4fe22b0463e2be346ffb
ENV HTTPD_PREFIX /usr/local/apache2
RUN mkdir -p "$HTTPD_PREFIX" \
	&& chown www-data:www-data "$HTTPD_PREFIX"
WORKDIR $HTTPD_PREFIX

#
# Build Apache
# https://github.com/docker-library/httpd/blob/master/2.4/Dockerfile
#

# install httpd runtime dependencies
# https://httpd.apache.org/docs/2.4/install.html#requirements
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# https://github.com/docker-library/httpd/issues/214
		ca-certificates \
		libaprutil1-ldap \
# https://github.com/docker-library/httpd/issues/209
		libldap-common \
	; \
	rm -rf /var/lib/apt/lists/*

# see https://httpd.apache.org/docs/2.4/install.html#requirements
RUN set -eux; \
	\
	# mod_http2 mod_lua mod_proxy_html mod_xml2enc
	# https://anonscm.debian.org/cgit/pkg-apache/apache2.git/tree/debian/control?id=adb6f181257af28ee67af15fc49d2699a0080d4c
	apt-get update; \
	apt-get install -y --no-install-recommends \
		bzip2 \
		dirmngr \
		dpkg-dev \
		gcc \
		gnupg \
		libapr1-dev \
		libaprutil1-dev \
		libbrotli-dev \
		libcurl4-openssl-dev \
		libjansson-dev \
		liblua5.2-dev \
		libnghttp2-dev \
		libpcre3-dev \
		libxml2-dev \
		make \
		wget \
		zlib1g-dev \
	; \
	\
	wget --quiet --no-check-certificate https://dlcdn.apache.org/httpd/httpd-$HTTPD_VERSION.tar.gz; \
	wget --quiet --no-check-certificate https://dlcdn.apache.org/httpd/httpd-$HTTPD_VERSION.tar.gz.asc; \
	echo "$HTTPD_SHA256 httpd-$HTTPD_VERSION.tar.gz" | sha256sum -c - | grep OK; \
	tar -xvf httpd-$HTTPD_VERSION.tar.gz; \
	cd httpd-$HTTPD_VERSION/; \
	\
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	CFLAGS="$(dpkg-buildflags --get CFLAGS)"; \
	CPPFLAGS="$(dpkg-buildflags --get CPPFLAGS)"; \
	LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"; \
	./configure \
		--build="$gnuArch" \
		--prefix="$HTTPD_PREFIX" \
		--enable-mods-shared=reallyall \
		--enable-mpms-shared=all \
# enable the same hardening flags as Debian
# - https://salsa.debian.org/apache-team/apache2/blob/87db7de4e59683fb03e97900f078d06ef2292748/debian/rules#L19-21
# - https://salsa.debian.org/apache-team/apache2/blob/87db7de4e59683fb03e97900f078d06ef2292748/debian/rules#L115
		--enable-pie \
		CFLAGS="-pipe $CFLAGS" \
		CPPFLAGS="$CPPFLAGS" \
		LDFLAGS="-Wl,--as-needed $LDFLAGS" \
	; \
	make -j "$(nproc)"; \
	make install;

COPY httpd.conf /usr/local/apache2/conf/httpd.conf
COPY server.crt /usr/local/apache2/conf/server.crt
COPY server.key /usr/local/apache2/conf/server.key
