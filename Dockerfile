FROM amazon/aws-cli:latest

ARG VERSION="4.22.0"
ARG GEM_SOURCE=https://packagecloud.io/cinc-project/stable
# build-base openssh-client
# openssh already installed
# Unavailable: ruby-dev ruby-etc ruby-webrick

RUN yum -y install https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm && \
    yum -y install gcc-c++ openssl make git unzip ruby ruby-devel mysql-community-client libxml2-devel libffi-devel && \
    # Use patched version which fixes support for aarch64
    # https://github.com/knu/ruby-unf_ext/commit/8a6a735b51ef903200fc541112e35b7cea781856
    gem install --no-document --clear-sources --source ${GEM_SOURCE} --version 0.0.7.2 unf_ext && \
    gem install --no-document --source ${GEM_SOURCE} --version ${VERSION} inspec && \
    gem install --no-document --source ${GEM_SOURCE} --version ${VERSION} cinc-auditor-bin

gem install --no-document --source https://packagecloud.io/cinc-project/stable --version 4.22.0 inspec
# # install curl, git, unzip, gpg, gpg-agent, and mysql-client
# RUN set -ex && cd ~ \
#     && apt-get update \
#     && apt-get -qq -y install --no-install-recommends git gpg gpg-agent curl unzip mysql-client \
#     && apt-get clean \
#     && rm -vrf /var/lib/apt/lists/*

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

# # apt-get all the things
# # Notes:
# # - Add all apt sources first
# # - groff and less required by AWS CLI
# ARG CACHE_APT
# RUN set -ex && cd ~ \
#     && apt-get update \
#     && : Install apt packages \
#     && apt-get -qq -y install --no-install-recommends apt-transport-https less groff lsb-release \
#     && : Cleanup \
#     && apt-get clean \
#     && rm -vrf /var/lib/apt/lists/*

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
