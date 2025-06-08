FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    coreutils

WORKDIR /autonoma

COPY scripts/*.sh /autonoma/

RUN chmod +x /autonoma/*.sh
