FROM ruby:2.6.7-alpine3.13

ARG CINC_VERSION="4.22.0"
ARG GEM_SOURCE=https://packagecloud.io/cinc-project/stable
ARG RUNUSER=default
ARG RUNGROUP=default

# install dependencies (some temporarily)
# install cinc-auditor
# clone the CMS profile
# create user
# clean up
RUN apk add --update --no-cache --virtual .build-deps \
      build-base gcc musl-dev openssl-dev \
      libxml2-dev libffi-dev libstdc++ git \
    && apk add --no-cache bash mysql-client \
    && gem install --no-document --source ${GEM_SOURCE} \
      --version ${CINC_VERSION} cinc-auditor-bin \
    && mkdir -p /home/${RUNUSER}/profiles \
    && cd /home/${RUNUSER}/profiles \
    && git clone https://github.com/CMSgov/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay.git \
    && addgroup -g 1000 ${RUNUSER} && adduser -u 1000 -G ${RUNUSER} -s /bin/sh -D ${RUNUSER} \
    && chown -R ${RUNUSER}:${RUNGROUP} /home/${RUNUSER} \
    && apk del --no-cache .build-deps \
    && rm -rf /tmp/* \
    && rm -rf /var/cache/apk/* \
    && rm -rf /var/tmp/*

COPY --chown=${RUNUSER}:${RUNGROUP} inputs.yml.erb /home/${RUNUSER}/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay/
COPY --chown=${RUNUSER}:${RUNGROUP} scriptRunner.sh /home/${RUNUSER}/profiles

WORKDIR /home/${RUNUSER}
USER ${RUNUSER}
