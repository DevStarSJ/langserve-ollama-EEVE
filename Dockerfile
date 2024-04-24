###############################################
# Base Image
###############################################
FROM python:3.11-slim as python-base

ARG ENVIRONMENT=production

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    POETRY_VERSION=1.6.1  \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1 \
    PYSETUP_PATH="/code" \
    VENV_PATH="/code/.venv" \
    LC_ALL="ko_KR.UTF-8" \
    LNGUAGE="ko_KR.UTF-8" \
    LANG="ko_KR.UTF-8" \
    PYTHONIOENCODING="UTF-8" \
    ROUTE_PREFIX="/v2/billing" \
    PY_ENV=$ENVIRONMENT

# prepend poetry and venv to path
ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$PATH"

###############################################
# Builder Image
###############################################
FROM python-base as builder-base
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    curl \
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev 

# install poetry - respects $POETRY_VERSION & $POETRY_HOME
RUN curl -sSL https://install.python-poetry.org | python3 -

# test poetry installed
RUN poetry -V

# copy project requirement files here to ensure they will be cached.
WORKDIR $PYSETUP_PATH
COPY poetry.lock pyproject.toml ./

RUN poetry install

###############################################
# Production Image
###############################################
FROM python-base as production

# Timezone Setting
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends tzdata curl \
    && echo "Asia/Seoul" > /etc/timezone \
    && ln -fs /usr/share/zoneinfo/`cat /etc/timezone` /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR $PYSETUP_PATH
COPY . $PYSETUP_PATH

RUN pip install huggingface-hub
RUN curl -fsSL https://ollama.com/install.sh | sh

RUN ollama serve &
RUN huggingface-cli download heegyu/EEVE-Korean-Instruct-10.8B-v1.0-GGUF ggml-model-Q5_K_M.gguf --local-dir $PYSETUP_PATH/ollama-modelfile/EEVE-Korean-Instruct-10.8B-v1.0 --local-dir-use-symlinks False
# RUN ollama list
RUN ollama create EEVE-Korean-10.8B -f $PYSETUP_PATH/ollama-modelfile/EEVE-Korean-Instruct-10.8B-v1.0/Modelfile-v02

