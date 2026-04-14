FROM jenkins/inbound-agent:latest-jdk21

LABEL maintainers="strizhhh@mail.ru, nixel2007@gmail.com"

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        git \
        openssh-client \
        unzip \
    # git-lfs
    && curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git-lfs \
    && rm -rf  \
        /var/lib/apt/lists/* \
        /var/cache/debconf

ENV TZ=Europe/Moscow \
    SONAR_SCANNER_VERSION="8.0.1.6346" \
    SONAR_SCANNER_HOME=/usr/lib/sonar-scanner
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN curl -o /tmp/sonarscanner.zip -L https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip \
    && unzip /tmp/sonarscanner.zip -d /usr/lib/ \
    && mv /usr/lib/sonar-scanner-${SONAR_SCANNER_VERSION} /usr/lib/sonar-scanner \
    && ln -s /usr/lib/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner \
    && rm /tmp/sonarscanner.zip

RUN mkdir -p /var/jenkins_home && chown jenkins:jenkins /var/jenkins_home

USER jenkins
