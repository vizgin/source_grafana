FROM registry.access.redhat.com/ubi7/ubi

# PhantomJS

RUN curl --silent --location https://rpm.nodesource.com/setup_12.x | bash -
RUN yum install -y --nogpgcheck \
    initscripts \
    curl \
    tar \
    gcc \
    git \
    go \
    nodejs \
    bzip2 \
    bzip2-libs;

RUN yum install -y fontconfig curl &&\
    cd /tmp && curl -Ls https://github.com/dustinblackman/phantomized/releases/download/2.1.1/dockerized-phantomjs.tar.gz | tar xz &&\
    cp -fR lib/* /lib &&\
    cp -fR usr/lib/x86_64-linux-gnu /usr/lib &&\
    cp -fR usr/share /usr/share &&\
    cp -fR etc/fonts /etc &&\
    curl -L https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 | tar -jxf - &&\
    cp phantomjs-2.1.1-linux-x86_64/bin/phantomjs /usr/local/bin/phantomjs

RUN curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo
RUN rpm --import https://dl.yarnpkg.com/rpm/pubkey.gpg
RUN yum install -y yarn
WORKDIR /usr/src/app/

COPY package.json yarn.lock ./
COPY packages packages

RUN yarn install --pure-lockfile

COPY Gruntfile.js tsconfig.json .eslintrc .editorconfig .browserslistrc ./
COPY public public
COPY scripts scripts
COPY emails emails

ENV NODE_ENV production
RUN ./node_modules/.bin/grunt build --force

FROM registry.access.redhat.com/ubi7/ubi

LABEL maintainer="Grafana SRE"
EXPOSE 3000

ENV LD_LIBRARY_PATH="/opt/glibc-2.28/lib"
ENV PATH="/usr/share/grafana/bin:$PATH" \
    GF_PATHS_CONFIG="/etc/grafana/grafana.ini" \
    GF_PATHS_DATA="/var/lib/grafana" \
    GF_PATHS_HOME="/usr/share/grafana" \
    GF_PATHS_LOGS="/var/log/grafana" \
    GF_PATHS_PLUGINS="/var/lib/grafana/plugins" \
    GF_PATHS_PROVISIONING="/etc/grafana/provisioning"

WORKDIR $GF_PATHS_HOME

COPY conf conf

# We need font libs for phantomjs, and curl should be part of the image
RUN yum update && yum upgrade -y && yum install -y ca-certificates libfontconfig1 curl libc6

RUN mkdir -p "$GF_PATHS_HOME/.aws" && \
  mkdir -p "$GF_PATHS_PROVISIONING/datasources" \
             "$GF_PATHS_PROVISIONING/dashboards" \
             "$GF_PATHS_PROVISIONING/notifiers" \
             "$GF_PATHS_LOGS" \
             "$GF_PATHS_PLUGINS" \
             "$GF_PATHS_DATA" && \
    cp conf/sample.ini "$GF_PATHS_CONFIG" && \
    cp conf/ldap.toml /etc/grafana/ldap.toml

# PhantomJS

COPY run.sh /
COPY grafana-server ./bin/
COPY plugins/grafana-piechart-panel-069072c /var/lib/grafana/plugins/grafana-piechart-panel
COPY plugins/flant-grafana-statusmap-9a2e4a3 /var/lib/grafana/plugins/grafana-statusmap-panel
COPY plugins/farski-blendstat-grafana-d53bf7c /var/lib/grafana/plugins/grafana-blendstat-panel
COPY plugins/simPod-grafana-json-datasource-a041dbf /var/lib/grafana/plugins/grafana-json-over-http-ds
COPY plugins/Vertamedia-clickhouse-grafana-bcee398 /var/lib/grafana/plugins/grafana-clickhouse-source
RUN chmod 777 /var/lib/grafana

COPY --from=0 /tmp/lib /lib
COPY --from=0 /tmp/usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu
COPY --from=0 /tmp/usr/share /usr/share
COPY --from=0 /tmp/etc/fonts /etc/fonts
COPY --from=0 /usr/local/bin/phantomjs /usr/local/bin

COPY --from=0 /usr/src/app/public ./public
COPY --from=0 /usr/src/app/tools ./tools
COPY tools/phantomjs/render.js ./tools/phantomjs/render.js

ENTRYPOINT [ "/run.sh" ]
