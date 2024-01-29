FROM rockylinux:9.3

LABEL maintainer="never615 <never615@gmail.com>"

ARG NODE_VERSION=20
ARG POSTGRES_VERSION=15
# define script variables
ARG ENV=prod
ARG PHP_VERSION=8.3
ARG TIME_ZONE=Asia/Shanghai

ENV REAL_IP_HEADER 1
ENV RUN_SCRIPTS 1

ENV php_vars /etc/php.d/docker-vars.ini

# modify root password
RUN echo 'root:admin123' | chpasswd

RUN ln -snf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime

RUN dnf upgrade --refresh -y &&\
  dnf install -y epel-release &&\
  dnf install -y zip rsyslog cronie crontabs supervisor &&\
  #dnf install -y wget composer mlocate &&\
  dnf clean all && \
  rm -rf /var/cache/dnf


# install php
RUN dnf install -y  http://rpms.remirepo.net/enterprise/remi-release-9.rpm && \
    dnf module -y install php:remi-$PHP_VERSION && \
    dnf -y install php-pecl-redis5 php-soap php-gd php-mysql php-mysqlnd php-pdo php-mcrypt \
        php-pgsql php-curl php-devel php-bcmath php-pecl-mongodb  \
        php-process php-pecl-zip php-gmp php-swoole php-sodium && \
    dnf clean all && \
    rm -rf /var/cache/dnf


#supervisord
ADD conf/supervisord.conf /etc/supervisord.conf
COPY conf/supervisord.d/ /etc/supervisord.d/

# Install ngixn
RUN dnf install -y nginx &&\
  # forward request and error logs to docker log collector
  ln -sf /dev/stdout /var/log/nginx/access.log &&\
  ln -sf /dev/stderr /var/log/nginx/error.log &&\
  mkdir -p /usr/share/nginx/run

# Copy our nginx config
RUN rm -Rf /etc/nginx/nginx.conf
ADD conf/nginx.conf /etc/nginx/nginx.conf

# nginx site conf
RUN rm -Rf /var/www/* &&\
  mkdir -p /var/www/html/
ADD conf/nginx-site.conf /etc/nginx/conf.d/default.conf

#Add your cron file
ADD conf/cron /etc/cron.d/crontabfile
RUN chmod 0644 /etc/cron.d/crontabfile


# Add Scripts
ADD scripts/start.sh /start.sh
RUN chmod 755 /start.sh

ADD scripts/horizon_exit.sh /horizon_exit.sh
RUN chmod 755 /horizon_exit.sh

# copy in code
ADD errors/ /var/www/errors

ADD conf/nginx-site.conf /etc/nginx/conf.d/default.conf

RUN setcap "cap_net_bind_service=+ep" /usr/bin/php


COPY php.ini ${php_vars}

## laravel-s 自动刷新需要的扩展
#RUN dnf install -y \
#   php83-php-pecl-inotify && \
#   dnf clean all && \
#   rm -rf /var/cache/dnf


EXPOSE 80

WORKDIR "/var/www/html"
CMD ["/start.sh"]
