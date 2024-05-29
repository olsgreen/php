FROM surnet/alpine-wkhtmltopdf:3.19.0-0.12.6-full as wkhtmltopdf
FROM php:8.1-fpm-alpine

# Add general build dependencies
RUN apk --update add wget \
    curl \
    git \
    grep \
    build-base \
    libtool \
    make \
    autoconf \
    g++ \
    cyrus-sasl-dev \
    libgsasl-dev

# 
# Install wkhtmltopdf
#

# wkhtmltopdf install dependencies
    RUN apk add --no-cache \
    libstdc++ \
    libx11 \
    libxrender \
    libxext \
    libssl3 \
    ca-certificates \
    fontconfig \
    freetype \
    ttf-droid \
    ttf-freefont \
    ttf-liberation

# wkhtmltopdf copy bins from ext image
COPY --from=wkhtmltopdf /bin/wkhtmltopdf /bin/libwkhtmltox.so /usr/local/bin/

#
# PHP Extensions
#

# Install the required libs to complile the extensions
RUN apk add --no-cache \
    supervisor \
    libmcrypt-dev \
    libxml2-dev \
    imagemagick \
    imagemagick-dev \
    pcre-dev \
    libzip-dev \
    libpng-dev \
    libwebp \
    libheif \
    libjpeg-turbo \
    ghostscript \
    icu-dev \
    libc6-compat

# Install the extensions
RUN docker-php-ext-install mysqli pdo pdo_mysql xml soap zip gd intl bcmath
RUN pecl channel-update pecl.php.net \
    && pecl install redis \
    && pecl install imagick \
    && docker-php-ext-enable redis \
    && docker-php-ext-enable imagick \
    && docker-php-ext-install sockets

RUN rm /var/cache/apk/*

#
# PDF to text install & configuration
#

RUN mkdir /tmp/pdftools
RUN cd /tmp/pdftools

# Download & install pdftotext
RUN curl https://dl.xpdfreader.com/xpdf-tools-linux-4.05.tar.gz -o /tmp/pdftools/xpdf-tools-linux-4.05.tar.gz
RUN tar -xvf /tmp/pdftools/xpdf-tools-linux-4.05.tar.gz -C /tmp/pdftools
RUN ls /tmp/pdftools
RUN cp /tmp/pdftools/xpdf-tools-linux-4.05/bin64/pdftotext /usr/local/bin/

# Make the base app directory.
RUN mkdir -p /var/www

# 
# Install composer
#
COPY install-composer.sh /etc/install-composer.sh
RUN chmod +x /etc/install-composer.sh
RUN /etc/install-composer.sh
RUN composer --version

# 
# Supervisord
#

# Setup supervisord to run the PHP-FPM service
COPY supervisord-fpm.conf /etc/supervisord.conf

# Setup our custom FPM file to run the service as deploy.
COPY www.conf /usr/local/etc/php-fpm.d/www.conf

# Setup our custom config.
COPY fpm.ini /usr/local/etc/php/conf.d/fpm.ini

# Create a user
RUN addgroup -g 1000 deploy
RUN adduser -S -D -s /sbin/nologin -u 1000 -G deploy deploy

# Make supervisor the entrypoint of the container
ENTRYPOINT ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
