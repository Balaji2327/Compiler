FROM debian:bullseye AS production

# Install curl, ca-certificates, and jq to fetch the compilers image layers
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates jq && \
    rm -rf /var/lib/apt/lists/*

# Pull and extract the judge0/compilers:1.4.0 layers directly, resetting ownership to root (0:0)
RUN token=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:judge0/compilers:pull" | jq -r .token) && \
    manifest=$(curl -sL -H "Authorization: Bearer $token" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://registry-1.docker.io/v2/judge0/compilers/manifests/1.4.0") && \
    for digest in $(echo "$manifest" | jq -r '.layers[].digest'); do \
      echo "Extracting layer $digest..." && \
      curl -sL -H "Authorization: Bearer $token" "https://registry-1.docker.io/v2/judge0/compilers/blobs/$digest" | tar --no-same-owner -xf - -C /; \
    done


ENV JUDGE0_HOMEPAGE "https://judge0.com"
LABEL homepage=$JUDGE0_HOMEPAGE

ENV JUDGE0_SOURCE_CODE "https://github.com/judge0/judge0"
LABEL source_code=$JUDGE0_SOURCE_CODE

ENV JUDGE0_MAINTAINER "Herman Zvonimir Došilović <hermanz.dosilovic@gmail.com>"
LABEL maintainer=$JUDGE0_MAINTAINER

ENV PATH "/usr/local/ruby-2.7.0/bin:/opt/.gem/bin:$PATH"
ENV GEM_HOME "/opt/.gem/"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      cron \
      libpq-dev \
      sudo && \
    rm -rf /var/lib/apt/lists/* && \
    echo "gem: --no-document" > /root/.gemrc && \
    gem install bundler:2.1.4 && \
    npm install -g --unsafe-perm aglio@2.3.0

EXPOSE 2358

WORKDIR /api

COPY Gemfile* ./
RUN RAILS_ENV=production bundle

COPY cron /etc/cron.d
RUN cat /etc/cron.d/* | crontab -

COPY . .

ENTRYPOINT ["/api/docker-entrypoint.sh"]
CMD ["/api/scripts/server"]

RUN useradd -u 1000 -m -r judge0 && \
    echo "judge0 ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers && \
    chown judge0: /api/tmp/

USER judge0

ENV JUDGE0_VERSION "1.13.1"
LABEL version=$JUDGE0_VERSION


FROM production AS development

CMD ["sleep", "infinity"]
