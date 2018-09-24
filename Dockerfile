FROM ubuntu:18.04

ARG KEEPALIVED_VERSION=2.0.7

RUN apt-get update \
 && apt-get install -y build-essential libssl-dev curl \
 && curl -o /tmp/keepalived.tar.gz -SL http://www.keepalived.org/software/keepalived-${KEEPALIVED_VERSION}.tar.gz \
 && cd /tmp \
 && tar -xzf keepalived.tar.gz \
 && cd /tmp/keepalived* \
 && ./configure \
 && make \
 && make install \
 && apt-get remove build-essential libssl-dev -y

RUN apt-get install -y jq dnsutils vim \
 && apt-get autoremove -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/apt

RUN mkdir -p /etc/keepalived/templates \
 && mkdir /etc/keepalived/config \
 && mkdir /etc/keepalived/scripts

VOLUME /etc/keepalived

RUN groupadd --gid 1000 keepalived_script \
 && useradd --no-create-home --uid 1000 --gid 1000 --shell /bin/bash keepalived_script

COPY startup.sh /usr/local/bin/startup.sh
COPY examples/scripts/* /etc/keepalived/scripts/

CMD ["/usr/local/bin/startup.sh"]

