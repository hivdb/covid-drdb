FROM python:3.9
ENV LANG C.UTF-8
RUN pip install pipenv
WORKDIR /covid-drdb
COPY Pipfile Pipfile.lock ./
RUN pipenv install
RUN curl -fsSL https://github.com/github-release/github-release/releases/download/v0.10.0/linux-amd64-github-release.bz2 -o github-release.bz2 && \
    bzip2 -d github-release.bz2 && \
    mv github-release /usr/bin/github-release && \
    chmod +x /usr/bin/github-release
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get update && apt-get -y install nodejs dos2unix sqlite3 jq
RUN npm install -g @dbml/cli
RUN mkdir -p /local
