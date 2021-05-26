FROM amazon/aws-cli:2.2.2

ARG VERSION="4.22.0"
ARG GEM_SOURCE=https://packagecloud.io/cinc-project/stable

RUN amazon-linux-extras enable ruby2.6

RUN yum -y upgrade && \
    yum -y install https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm && \
    yum -y install gcc-c++ make git mysql-community-client && \
    yum -y install ruby-devel rubygems-devel rubygem-bundler

RUN gem install --no-document --source ${GEM_SOURCE} --version ${VERSION} cinc-auditor-bin

#clean up
RUN yum clean all && \
    rm -rf /var/cache/yum

# create a non-root user for security
RUN useradd -rm -d /home/default -u 1234 default
USER default
WORKDIR /home/default

# clone CMS profile
RUN mkdir profiles \
    && cd profiles \
    && git clone https://github.com/CMSgov/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay.git \
    && cd cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay

COPY --chown=default:default inputs.yml.erb profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay/
COPY --chown=default:default scriptRunner.sh ./profiles/
