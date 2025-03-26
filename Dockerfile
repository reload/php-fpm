ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-bookworm@sha256:9711445cf92fbdeb42c4396ce4ad405ead54f38ff876d1093ec0abad98c75a16 AS php8.1
FROM php:8.2-fpm-bookworm@sha256:c8109bd894c826bf3ed7c603c5bffc0c8d2f6d6506a759560241915a213cb911 AS php8.2
FROM php:8.3-fpm-bookworm@sha256:803554ae9ad107b762524f28bbdc4d3d3ce41d02d720aaa2717e0b6fcace781d AS php8.3
FROM php:8.4-fpm-bookworm@sha256:182b3466ea500120199794457bc7563dfc599f742f6833722dc7d3ca3f69a328 AS php8.4

## Helper images
FROM blackfire/blackfire:2@sha256:bc34d45dcd7c7e2ae5ef9a282f7c0145e03d6bf7907522b8f56fa4a090798587 AS blackfire
FROM composer:2@sha256:26bbf85fccb36247181de6f4a2beddac47d4b352c0c19249a3b4fa2abf1e38ad AS composer
FROM mlocati/php-extension-installer:2@sha256:61ec62196646d4299a959ebdf0f6753f71a7e9db0eebafe1e4f3bf0f323f50be AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"

HEALTHCHECK --interval=10s --start-period=90s CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
    apt-get -y update
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends git=1:2.* jq=1.* locales-all=2.* mariadb-client=1:10.* msmtp=1.* net-tools=2.* poppler-utils=22.* procps=2:4.* unzip=6.* graphicsmagick=1.* sudo=1.* tini=0.*
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    install-php-extensions ${php_enable_extensions}
    if [ "${php}" != "8.4" ]; then IPE_DONT_ENABLE=1 install-php-extensions blackfire; fi
    IPE_DONT_ENABLE=1 install-php-extensions xdebug
    adduser --uid=501 --gid=20 --disabled-password --gecos --quiet machost
    adduser --uid=1000 --disabled-password --gecos --quiet linuxhost
EOT

COPY --from=blackfire /usr/local/bin/blackfire /usr/bin
COPY --from=composer /usr/bin/composer /usr/bin

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
RUN curl https://endoflife.date/api/php/${php}.json| jq '{support,eol,lts}' > /etc/eol.json

ARG workdir=/var/www
WORKDIR "${workdir}"

ENV COMPOSER_CACHE_DIR="/tmp/composer-cache"
ENV GIT_CEILING_DIRECTORIES="${workdir}"
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/bin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
