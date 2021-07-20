FROM ruby:2.6.7-alpine3.13

ARG CINC_VERSION="4.22.0"
ARG GLIBC_VERSION="2.33-r0"

ARG GEM_SOURCE=https://packagecloud.io/cinc-project/stable
ARG RUNUSER=default
ARG RUNGROUP=default

COPY build.sh /tmp
COPY tests.sh /tmp

RUN /tmp/build.sh

COPY --chown=${RUNUSER}:${RUNGROUP} inputs.yml.erb /home/${RUNUSER}/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay/
COPY --chown=${RUNUSER}:${RUNGROUP} scriptRunner.sh /home/${RUNUSER}/profiles
COPY --chown=${RUNUSER}:${RUNGROUP} main /home/${RUNUSER}/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay/

RUN /tmp/tests.sh && rm -rf /tmp/*

WORKDIR /home/${RUNUSER}
USER ${RUNUSER}

ENTRYPOINT ["./profiles/scriptRunner.sh"]