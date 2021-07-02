FROM alpine

ARG BUILD_DATE
ARG BUILD_VERSION

LABEL org.opencontainers.image.authors="clemenko@gmail.com" \
      org.opencontainers.image.source="https://github.com/clemenko/wirescale" \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.title="clemenko/wireflask" \
      org.opencontainers.image.description="The repository contains a simple flask application and other stuff for keycloak and wireguard" \
      org.opencontainers.image.build="docker build -t clemenko/wireflask --build-arg BUILD_DATE=$(date +%D) --build-arg BUILD_VERSION=0.01 " \
      org.opencontainers.image.source=$BUILD_VERSION 

RUN apk -U upgrade && apk add --no-cache python3 curl py3-pip &&\
    pip3 install --no-cache-dir --upgrade pip &&\
    pip3 install --no-cache-dir flask Flask-OIDC &&\
    #apk --purge del apk-tools &&\
    rm -rf /var/cache/apk/*
    
WORKDIR /code
ADD . /code
EXPOSE 5000
CMD ["python3", "app.py"]
