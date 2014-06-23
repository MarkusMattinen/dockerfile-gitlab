# gitlab with nginx, etcd registration, confd and supervisord on trusty
FROM markusma/nginx-etcd:trusty
MAINTAINER Markus Mattinen <docker@gamma.fi>

RUN curl -sSL http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add - \
 && echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
 && add-apt-repository ppa:chris-lea/redis-server \
 && add-apt-repository ppa:git-core/ppa

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev openssh-server redis-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev python python-docutils logrotate msmtp-mta sudo openjdk-7-jre-headless git postgresql-9.2 libpq-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /tmp/subgit \
 && cd /tmp/subgit \
 && wget -q http://subgit.com/download/subgit_2.0.0_all.deb \
 && dpkg -i subgit_2.0.0_all.deb \
 && cd / \
 && rm -rf /tmp/subgit

RUN mkdir -p /tmp/ruby \
 && cd /tmp/ruby \
 && curl -sSL ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p481.tar.gz | tar xz \
 && cd ruby-2.0.0-p481 \
 && ./configure --disable-install-rdoc \
 && make -j4 \
 && make install \
 && cd / \
 && rm -rf /tmp/ruby

RUN gem install bundler --no-ri --no-rdoc

RUN addgroup --gid 999 git \
 && adduser --disabled-login --gecos 'GitLab' --uid 999 --gid 999 git

RUN cd /home/git \
 && su git -c "git clone https://github.com/gitlabhq/gitlab-shell.git -b v1.9.1"

RUN cd /home/git \
 && su git -c "git clone https://github.com/gitlabhq/gitlabhq.git -b 6-7-stable gitlab"

RUN cd /home/git/gitlab \
 && sed -i 's/"modernizr", *"2.6.2"/"modernizr-rails", "2.7.1"/g' Gemfile \
 && sed -i 's/modernizr (2.6.2)/modernizr-rails (2.7.1)/g' Gemfile.lock \
 && sed -i 's/modernizr (= 2.6.2)/modernizr-rails (= 2.7.1)/g' Gemfile.lock \
 && su git -c "bundle install -j`nproc` --deployment --without development test mysql aws"

RUN mkdir -p /var/run/sshd \
 && mkdir -p /home/git/gitlab-satellites /home/git/gitlab/tmp/pids /home/git/gitlab/tmp/sockets /home/git/gitlab/public/uploads \
 && su git -c "HOME=/home/git git config --global user.name 'GitLab'" \
 && su git -c "HOME=/home/git git config --global user.email 'gitlab@git.gamma.fi'" \
 && su git -c "HOME=/home/git git config --global core.autocrlf input"

ADD config/home/git /home/git

RUN chown -R git:git /home/git

ADD config/etc/redis.conf /etc/redis.conf
ADD config/etc/supervisor/conf.d /etc/supervisor/conf.d
ADD config/init /init
ADD config/check /check
ADD config/start_unicorn /start_unicorn
ADD config/start_sidekiq /start_sidekiq
ADD config/etc/confd/conf.d /etc/confd/conf.d
ADD config/etc/confd/templates /etc/confd/templates

EXPOSE 5000 22
VOLUME ["/home/git/.ssh","/home/git/repositories","/home/git/gitlab-satellites","/var/lib/redis"]
