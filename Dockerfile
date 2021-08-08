FROM debian:stretch

MAINTAINER Cosmin "cosmin.gorea@softescu.com"
#docker build -f Dockerfile_prod -t elcd8bprod:1.0.0 .


# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive
ENV NGINX_VERSION 1.13.12-1~stretch
ENV php_conf /etc/php/7.2/fpm/php.ini
ENV fpm_conf /etc/php/7.2/fpm/pool.d/www.conf
ENV COMPOSER_VERSION 1.6.5

# Install Basic Requirements
RUN apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -q -y gnupg2 dirmngr wget apt-transport-https lsb-release ca-certificates \
#   && apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 \
    && echo "deb http://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list \
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -q -y \
            apt-utils \
            curl \
	    vim \
            nano \
            zip \
            unzip \
            mysql-client \
            python-pip \
            python-setuptools \
            git \
            patch \
            nginx=${NGINX_VERSION} \
            php7.2-fpm \
            php7.2-cli \
            php7.2-dev \
            php7.2-common \
            php7.2-json \
            php7.2-opcache \
            php7.2-readline \
            php7.2-mbstring \
            php7.2-curl \
            php7.2-memcached \
            php7.2-imagick \
            php7.2-gd \
            php7.2-mysql \
            php7.2-zip \
            php7.2-pgsql \
            php7.2-intl \
            php7.2-xml \
            php7.2-redis \
            php-pear  \
            make  \
            libmcrypt-dev \
            libreadline-dev \
    && mkdir -p /run/php \
    && pip install wheel \
    && pip install supervisor supervisor-stdout \
    && echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d \
    && rm -rf /etc/nginx/conf.d/default.conf \
    && sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php_conf} \
    && sed -i -e "s/;error_log\s*=\s*php_errors.log/error_log = php_errors.log/g" ${php_conf} \
    && sed -i -e "s/memory_limit\s*=\s*.*/memory_limit = 256M/g" ${php_conf} \
    && sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 1024M/g" ${php_conf} \
    && sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 1024M/g" ${php_conf} \
    && sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php_conf} \
    && sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.2/fpm/php-fpm.conf \
    && sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_children = 5/pm.max_children = 4/g" ${fpm_conf} \
    && sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" ${fpm_conf} \
    && sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${fpm_conf} \
  #  && sed -i -e "s/www-data/nginx/g" ${fpm_conf} \
    && sed -i -e "s/^;clear_env = no$/clear_env = no/" ${fpm_conf} \
    && apt-get clean &&  rm -rf /var/lib/apt/lists/*

#Installation of mcrypt for php 7.2 is not supported via regulr repos.

RUN pecl install mcrypt-1.0.1
RUN bash -c "echo extension=/usr/lib/php/20170718/mcrypt.so > /etc/php/7.2/cli/conf.d/mcrypt.ini" 
RUN bash -c "echo extension=/usr/lib/php/20170718/mcrypt.so > /etc/php/7.2/fpm/conf.d/mcrypt.ini"



RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
  && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
  && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
  && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} && rm -rf /tmp/composer-setup.php

#Install metricbeat

#RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
#RUN apt-get install apt-transport-https
#RUN echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-6.x.list
RUN apt-get update
#RUN apt-get install metricbeat -y
#RUN metricbeat modules enable nginx
#RUN metricbeat modules enable system

RUN mkdir -p /var/www/html

#Install filebeat

#RUN apt-get install filebeat -y
#RUN filebeat modules enable nginx


# Supervisor config
ADD ./docker-utils/supervisord/supervisord.conf /etc/supervisord.conf

# Override nginx's default config and nginx.conf
ADD ./docker-utils/nginx/nginx_lw.conf /etc/nginx/nginx.conf 
ADD ./docker-utils/nginx/default_refine._elx3.conf /etc/nginx/conf.d/default.conf

# Copy the certificate for MySQL encryption
#COPY ./docker-utils/AzureMysqlCA/BaltimoreCyberTrustRoot.crt.pem /etc/azencrypt/

# Override default nginx welcome page
#COPY html /usr/share/nginx/html

#metricbeat config
#ADD ./docker-utils/elastic_beats/generic/metricbeat.yml /etc/metricbeat/metricbeat.yml
#RUN chmod 755 /etc/metricbeat/metricbeat.yml

#filebeatbeat config
#COPY ./docker-utils/elastic_beats/generic/filebeat.yml /etc/filebeat/filebeat.yml
#RUN chmod 755 /etc/filebeat/filebeat.yml


# Add Scripts
ADD ./docker-utils/scripts/start_elx3.sh /start.sh
RUN chmod +x start.sh
EXPOSE 81

CMD ["/start.sh"]
