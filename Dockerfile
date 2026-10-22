ARG PHP_VERSION="8.3.36"
ARG ALPINE_VERSION="3.23"

FROM surnet/alpine-wkhtmltopdf:3.19.0-0.12.6-full AS wkhtmltopdf

FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION} AS php-builder

COPY install-composer.sh /etc/install-composer.sh
COPY install-xpdf-tools.sh /etc/install-xpdf-tools.sh

# Copy wkhtmltopdf into the builder so scanelf can discover its runtime deps too.
COPY --from=wkhtmltopdf /bin/wkhtmltopdf /bin/libwkhtmltox.so /usr/local/bin/

RUN set -eux; \
    apk add --no-cache \
        ca-certificates \
        curl \
        grep \
        pax-utils \
        tar \
        imagemagick-dev; \
    \
    apk add --no-cache --virtual .build-deps \
        build-base \
        autoconf \
        cmake \
        g++ \
        libtool \
        linux-headers \
        pcre-dev \
        libxml2-dev \
        libzip-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        libheif \
        freetype-dev \
        icu-dev \
        libxrender \
        openssl-dev; \
    \
    docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp; \
    docker-php-ext-install \
        mysqli \
        pdo \
        pdo_mysql \
        xml \
        soap \
        zip \
        gd \
        intl \
        bcmath \
        pcntl \
        exif \
        ftp \
        sockets; \
    \
    pecl channel-update pecl.php.net; \
    pecl install redis imagick; \
    docker-php-ext-enable redis imagick; \
    \
    chmod +x /etc/install-composer.sh /etc/install-xpdf-tools.sh; \
    /etc/install-composer.sh; \
    /etc/install-xpdf-tools.sh; \
    \
    php -m | grep -E 'imagick|redis|mysqli|pdo_mysql|gd|intl|soap|zip'; \
    composer --version; \
    rm -rf /tmp/pear ~/.pearrc /var/cache/apk/* /usr/src/php*

# Build a tiny helper file containing the exact Alpine runtime packages needed
# by the PHP binary, PHP extensions, Composer, XPDF tools, and wkhtmltopdf.
FROM php-builder AS runtime-deps

COPY --from=wkhtmltopdf /bin/wkhtmltopdf /bin/libwkhtmltox.so /usr/local/bin/

RUN set -eux; \
    apk add --no-cache pax-utils; \
    scanelf --needed --nobanner --recursive \
        /usr/local/bin \
        /usr/local/sbin \
        /usr/local/lib \
        /usr/local/lib/php/extensions \
    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
    | sort -u \
    | xargs -r apk info --installed \
    | sort -u \
    > /tmp/runtime-packages.txt; \
    cat /tmp/runtime-packages.txt


FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION}

COPY --from=runtime-deps /tmp/runtime-packages.txt /tmp/runtime-packages.txt

# wkhtmltopdf binaries
COPY --from=php-builder /usr/local/bin/wkhtmltopdf /usr/local/bin/libwkhtmltox.so /usr/local/bin/

# PHP extensions and config generated in the builder
COPY --from=php-builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=php-builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Composer and XPDF tools installed by your scripts
COPY --from=php-builder /usr/local/bin/ /usr/local/bin/

# Custom FPM config
COPY www.conf /usr/local/etc/php-fpm.d/www.conf
COPY fpm.ini /usr/local/etc/php/conf.d/fpm.ini

RUN set -eux; \
    apk add --no-cache \
        $(cat /tmp/runtime-packages.txt) \
        libheif \
        libwebp \
        imagemagick \
        imagemagick-libs \
        imagemagick-dev \
        ca-certificates \
        ghostscript \
        libssl3 \
        git; \
    \
    rm -f /tmp/runtime-packages.txt; \
    mkdir -p /var/www; \
    addgroup -g 1000 deploy; \
    adduser -S -D -s /sbin/nologin -u 1000 -G deploy deploy; \
    \
    php -m | grep -E 'imagick|redis|mysqli|pdo_mysql|gd|intl|soap|zip'; \
    composer --version; \
    wkhtmltopdf --version || true

USER deploy

LABEL PHP_VERSION="${PHP_VERSION}"