FROM ruby:2.3.1
MAINTAINER Zammad.org <info@zammad.org>
ARG BUILD_DATE

ENV DEBIAN_FRONTEND noninteractive
ENV OFN_DIR /opt/app
ENV RAILS_ENV production
ENV GIT_URL https://github.com/openfoodfoundation/openfoodnetwork.git
ENV GIT_BRANCH master
ENV LANG en_US.UTF-8

ENV NODE_ENV production
ENV NPM_CONFIG_LOGLEVEL error
ENV NPM_CONFIG_PRODUCTION true
ENV NODE_VERSION 6.9.1

# Expose ports
EXPOSE 80 443

# fixing service start
RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4 && \
echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup && \
echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache && \
echo "#\0041/bin/bash" > /bin/start-rsyslog && \
echo "rm -f /var/run/rsyslogd.pid" >> /bin/start-rsyslog && \
echo "rsyslogd -n" >> /bin/start-rsyslog && \
chmod 755 /bin/start-rsyslog

RUN rm -rf /var/lib/apt/lists/* preseed.txt

RUN echo "postfix postfix/main_mailer_type string Internet site" > preseed.txt

RUN debconf-set-selections preseed.txt

RUN set -ex \
  && for key in \
    9554F04D7259F04124DE6B476D5A82AC7E37093B \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    0034A06D9D9B0064CE8ADF6BF1747F4AD2306D93 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
  ; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done

RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs


RUN apt-get update -y && apt-get dist-upgrade -y && apt-get install -y --no-install-recommends postgresql-client memcached apt-transport-https libterm-readline-perl-perl locales mc net-tools nginx postfix build-essential chrpath libssl-dev libxft-dev libfreetype6 libfreetype6-dev libfontconfig1 libfontconfig1-dev ca-certificates software-properties-common imagemagick mysql-client libodbc1

RUN wget http://sphinxsearch.com/files/sphinxsearch_2.2.11-release-1~jessie_amd64.deb && dpkg -i sphinxsearch*.deb

RUN gem install bundler
RUN bundle config git.allow_insecure true

RUN mkdir -p /opt/app/app/assets/webpack /opt/app/public/assets /opt/app/public/webpack
RUN useradd -m -s /bin/bash app \
  && mkdir /opt/app/client /opt/app/log /opt/app/tmp && chown -R app:app /opt/app

WORKDIR /opt/app


COPY sharetribe/Gemfile /opt/app
COPY sharetribe/Gemfile.lock /opt/app

RUN bundle install --deployment --without development,test,staging

COPY sharetribe/package.json /opt/app
COPY sharetribe/client/package.json /opt/app/client/
COPY sharetribe/client/customloaders/customfileloader /opt/app/client/customloaders/customfileloader

RUN npm install

COPY sharetribe/. /opt/app

# install zammad
COPY scripts/install-software.sh /tmp
COPY scripts/startup.sh /tmp
RUN chmod +x /tmp/*;/bin/bash -l -c /tmp/install-software.sh
# CMD ["/tmp/startup.sh"]

# docker init
COPY scripts/docker-entrypoint.sh /
RUN chown app:app -R /opt/app;chown app:app /docker-entrypoint.sh;chmod +x /docker-entrypoint.sh

COPY scripts/stribe.conf /stribe.conf.pkgr

RUN apt-get autoremove -y && \
    apt-get clean -y&& \
    rm -rf /var/lib/apt/lists/* /var/tmp/*

# USER app
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["app"]
