# Chef Inspec tool as a docker image
FROM chef/inspec:stable

# install curl, git, unzip, gpg, and gpg-agent
RUN set -ex && cd ~ \
    && apt-get update \
    && apt-get -qq -y install --no-install-recommends git gpg gpg-agent curl unzip \
    && apt-get clean \
    && rm -vrf /var/lib/apt/lists/*

# install awscliv2, disable default pager (less)
ENV AWS_PAGER=""
ARG AWSCLI_VERSION=2.1.27
COPY sigs/awscliv2_pgp.key /tmp/awscliv2_pgp.key
RUN gpg --import /tmp/awscliv2_pgp.key
RUN set -ex && cd ~ \
    && curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" -o awscliv2.zip \
    && curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip.sig" -o awscliv2.sig \
    && gpg --verify awscliv2.sig awscliv2.zip \
    && unzip awscliv2.zip \
    && ./aws/install --update \
    && aws --version \
    && rm -r awscliv2.zip awscliv2.sig aws

# apt-get all the things
# Notes:
# - Add all apt sources first
# - groff and less required by AWS CLI
ARG CACHE_APT
RUN set -ex && cd ~ \
    && apt-get update \
    && : Install apt packages \
    && apt-get -qq -y install --no-install-recommends apt-transport-https less groff lsb-release \
    && : Cleanup \
    && apt-get clean \
    && rm -vrf /var/lib/apt/lists/*

# create a non-root user for security
RUN useradd -rm -d /home/default -u 1234 default
USER default
WORKDIR /home/default

# clone CMS profile
RUN mkdir profiles \
    && cd profiles \
    && git clone https://github.com/CMSgov/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay.git \
    && cd cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay

COPY --chown=default:default inputs.yml profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay/
COPY --chown=default:default scriptRunner.sh ./profiles/

# execute CMS CIS profile
ENTRYPOINT ["./profiles/scriptRunner.sh"]

CMD ["--chef-license=accept-silent"]
