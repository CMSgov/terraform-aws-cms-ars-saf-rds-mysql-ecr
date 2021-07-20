#!/bin/sh
set -euox pipefail

# install our dependencies
apk add --update --no-cache --virtual .build-deps \
      build-base gcc musl-dev openssl-dev curl \
      libxml2-dev libffi-dev libstdc++ git
apk add --update --no-cache --virtual .run-deps bash mysql-client jq

# install cinc-auditor
gem install --no-document --source "${GEM_SOURCE}" \
      --version "${CINC_VERSION}" cinc-auditor-bin

# install glibc for awscliv2
curl -sL https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub
curl -sLO "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk"
curl -sLO "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk"
apk add --update --no-cache --virtual .glibc \
      "glibc-${GLIBC_VERSION}.apk" \
      "glibc-bin-${GLIBC_VERSION}.apk"

# Install awscliv2
curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip awscliv2.zip
./aws/install

# install mysql profile and add our user
addgroup -g 1000 "${RUNUSER}" && adduser -u 1000 -G "${RUNUSER}" -s /bin/sh -D "${RUNUSER}"
mkdir -p "/home/${RUNUSER}/profiles"
(cd "/home/${RUNUSER}/profiles" && \
  git clone https://github.com/CMSgov/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay.git)
chown -R "${RUNUSER}":"${RUNGROUP}" "/home/${RUNUSER}"

# clean up
apk del --no-cache .build-deps
rm -rf /var/cache/apk/*
rm -rf /var/tmp/*
rm -rf "./*-${GLIBC_VERSION}.apk"
rm -rf \
      awscliv2.zip \
      aws \
      /usr/local/aws-cli/v2/*/dist/aws_completer \
      /usr/local/aws-cli/v2/*/dist/awscli/data/ac.index \
      /usr/local/aws-cli/v2/*/dist/awscli/examples
