# Sonar Scanner CLI

Docker-образ для статического анализа кода с помощью [SonarQube Scanner](https://docs.sonarsource.com/sonarqube-server/latest/analyzing-source-code/scanners/sonarscanner/).

Образ построен на базе `jenkins/inbound-agent` и предназначен для работы в двух сценариях:
- **Jenkins** -- как динамический агент (Docker Swarm / Kubernetes), с `sonar-scanner` в PATH
- **GitLab CI/CD** -- как образ для задач анализа, с переопределением entrypoint

## Docker Hub

```bash
docker pull astrizhachuk/jenkins-sonar-agent:latest
```

## Теги

| Тег | Базовый образ | SonarScanner | Java |
|-----|---------------|-------------|------|
| `latest`, `8.0.1.6346` | `jenkins/inbound-agent:latest-jdk21` | 8.0.1.6346 | 21 |

## Что внутри

### Базовый образ

`jenkins/inbound-agent:latest-jdk21` -- включает Jenkins Remoting, JDK 21, поддержку WebSocket-подключения к Jenkins.

### Дополнительные пакеты

- curl
- git
- git-lfs
- openssh-client
- unzip

### Переменные окружения

| Переменная | Значение | Описание |
|------------|----------|----------|
| `SONAR_SCANNER_VERSION` | `8.0.1.6346` | Версия SonarQube Scanner |
| `SONAR_SCANNER_HOME` | `/usr/lib/sonar-scanner` | Путь установки сканера |
| `TZ` | `Europe/Moscow` | Часовой пояс |

## Использование в Jenkins

### Требования

- Плагин [Swarm Agents Cloud](https://github.com/jenkinsci/swarm-agents-cloud-plugin) (или аналогичный cloud-плагин для Docker)
- Шаблон агента с label `sonar`
- Флаг `disableContainerArgs: true` в настройках шаблона

### Настройка шаблона (JCasC)

```yaml
jenkins:
  clouds:
    - swarmAgentsCloud:
        name: "swarm"
        templates:
          - name: "sonar"
            image: "192.168.48.6:5000/jenkins-sonar-agent:latest"
            label: "sonar"
            workingDir: "/var/jenkins_home"
            numExecutors: 1
            mode: EXCLUSIVE
            disableContainerArgs: true
            envVars:
              - name: "SONAR_SCANNER_OPTS"
                value: "-Xmx2g"
```

### Использование в Pipeline

С библиотекой [jenkins-lib](https://github.com/firstBitMarksistskaya/jenkins-lib):

```groovy
stage('SonarQube') {
    agent { label 'sonar' }
    steps {
        sonarScanner config
    }
}
```

Или напрямую:

```groovy
stage('SonarQube') {
    agent { label 'sonar' }
    steps {
        checkout scm
        withSonarQubeEnv('sonarqube') {
            sh 'sonar-scanner'
        }
    }
}
```

Параметры анализа задаются в файле `sonar-project.properties` в корне проекта.

## Использование в GitLab CI/CD

При использовании в GitLab CI/CD необходимо переопределить entrypoint, т.к. по умолчанию контейнер запускает Jenkins-агент:

```yaml
stages:
  - sonarqube

variables:
  MAJOR: "10.3.1"
  PATH_SRC: "src/"

merge_request:
  stage: sonarqube
  image:
    name: ${CI_REGISTRY}/devops/jenkins-sonar-agent:latest
    entrypoint: [""]
  variables:
    GIT_DEPTH: 0
  script:
    - keytool -cacerts -storepass changeit -noprompt -trustcacerts
        -importcert -alias yours.certs.local -file "$SONAR_SSL_CERTIFICATE"
    - export PROJECT_VERSION="${MAJOR}.$(grep -oPm1 '(?<=<VERSION>)[^<]+' ${PATH_SRC}VERSION)"
    - export SONAR_SCANNER_OPTS="-Xmx16g"
    - sonar-scanner
        -D"sonar.host.url=${SONAR_SERVER}"
        -D"sonar.projectVersion=${PROJECT_VERSION}"
        -D"sonar.token=${SONAR_TOKEN}"
        -D"sonar.pullrequest.key=${CI_MERGE_REQUEST_IID}"
        -D"sonar.pullrequest.branch=${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME}"
        -D"sonar.pullrequest.base=${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}"
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event" && $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "master"'
  tags:
    - docker

push:
  stage: sonarqube
  image:
    name: ${CI_REGISTRY}/devops/jenkins-sonar-agent:latest
    entrypoint: [""]
  variables:
    GIT_DEPTH: 0
  script:
    - keytool -cacerts -storepass changeit -noprompt -trustcacerts
        -importcert -alias yours.certs.local -file "$SONAR_SSL_CERTIFICATE"
    - export PROJECT_VERSION="${MAJOR}.$(grep -oPm1 '(?<=<VERSION>)[^<]+' ${PATH_SRC}VERSION)"
    - export SONAR_SCANNER_OPTS="-Xmx6g"
    - sonar-scanner
        -D"sonar.host.url=${SONAR_SERVER}"
        -D"sonar.projectVersion=${PROJECT_VERSION}"
        -D"sonar.branch.name=master"
        -D"sonar.token=${SONAR_TOKEN}"
  rules:
    - if: '$CI_COMMIT_TAG != null'
  tags:
    - docker
```

## Сборка

```bash
docker build -t jenkins-sonar-agent:latest .
```

## Лицензия

MIT
