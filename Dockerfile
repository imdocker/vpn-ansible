FROM alpine:3.8
#latest

ENV OC_VERSION=7.08

RUN set -ex \
# 1. install pptpclient
    && echo '@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories \
    && apk --update --no-progress upgrade \
    && apk add --no-progress ca-certificates pptpclient@testing \
# 2. build and install openconnect (ref: https://github.com/04n0/docker-openconnect-client)
## 2.1 install runtime and build dependencies
    && apk add --no-progress --virtual .openconnect-run-deps \
               gnutls gnutls-utils iptables libev libintl \
               libnl3 libseccomp linux-pam lz4-libs openssl \
               libxml2 nmap-ncat socat openssh-client \
    && apk add --no-progress --virtual .openconnect-build-deps \
               curl file g++ gnutls-dev gpgme gzip libev-dev \
               libnl3-dev libseccomp-dev libxml2-dev linux-headers \
               linux-pam-dev lz4-dev make readline-dev tar \
               sed readline procps \
## 2.2 download vpnc-script
    && mkdir -p /etc/vpnc \
    && curl http://git.infradead.org/users/dwmw2/vpnc-scripts.git/blob_plain/HEAD:/vpnc-script -o /etc/vpnc/vpnc-script \
    && chmod 750 /etc/vpnc/vpnc-script \
## 2.3 create build dir, download, verify and decompress OC package to build dir
    && gpg --keyserver pgp.mit.edu --recv-key 0x63762cda67e2f359 \
    && mkdir -p /tmp/build/openconnect \
    && curl -SL "ftp://ftp.infradead.org/pub/openconnect/openconnect-$OC_VERSION.tar.gz" -o /tmp/openconnect.tar.gz \
    && curl -SL "ftp://ftp.infradead.org/pub/openconnect/openconnect-$OC_VERSION.tar.gz.asc" -o /tmp/openconnect.tar.gz.asc \
    && gpg --verify /tmp/openconnect.tar.gz.asc \
    && tar -xf /tmp/openconnect.tar.gz -C /tmp/build/openconnect --strip-components=1 \
## 2.4 build and install
    && cd /tmp/build/openconnect \
    && ./configure \
    && make \
    && make install \
    && cd / \
# 3. fix ip command location for the pptp client
    && ln -s "$(which ip)" /usr/sbin/ip \
# 4. cleanup
    && apk del .openconnect-build-deps \
    && rm -rf /var/cache/apk/* /tmp/* ~/.gnupg

 
ENV ANSIBLE_VERSION 2.5.0
 
ENV BUILD_PACKAGES \
  bash \
  curl \
  tar \
  openssh-client \
  sshpass \
  git \
  python \
  py-boto \
  py-dateutil \
  py-httplib2 \
  py-jinja2 \
  py-paramiko \
  py-pip \
  py-yaml \
  ca-certificates
 
# If installing ansible@testing
#RUN \
#	echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> #/etc/apk/repositories
 
RUN set -x && \
    \
    echo "==> Adding build-dependencies..."  && \
    apk --update add --virtual build-dependencies \
      gcc \
      musl-dev \
      libffi-dev \
      openssl-dev \
      python-dev && \
    \
    echo "==> Upgrading apk and system..."  && \
    apk update && apk upgrade && \
    \
    echo "==> Adding Python runtime..."  && \
    apk add --no-cache ${BUILD_PACKAGES} && \
    pip install --upgrade pip && \
    pip install python-keyczar docker-py && \
    \
    echo "==> Installing Ansible..."  && \
    pip install ansible==${ANSIBLE_VERSION} && \
    \
    echo "==> Cleaning up..."  && \
    apk del build-dependencies && \
    rm -rf /var/cache/apk/* && \
    \
    echo "==> Adding hosts for convenience..."  && \
    mkdir -p /etc/ansible /ansible && \
    echo "[local]" >> /etc/ansible/hosts && \
    echo "localhost" >> /etc/ansible/hosts
 
ENV ANSIBLE_GATHERING smart
ENV ANSIBLE_HOST_KEY_CHECKING false
ENV ANSIBLE_RETRY_FILES_ENABLED false
ENV ANSIBLE_ROLES_PATH /ansible/playbooks/roles
ENV ANSIBLE_SSH_PIPELINING True
ENV PYTHONPATH /ansible/lib
ENV PATH /ansible/bin:$PATH
ENV ANSIBLE_LIBRARY /ansible/library
 
WORKDIR /ansible/playbooks
 
#ENTRYPOINT ["ansible-playbook"]

#PTP vpn PTP client
COPY content /

ENTRYPOINT ["/entrypoint.sh"]

