#!/bin/sh

DART_VERSION=$1

apt-get -q update && apt-get install --no-install-recommends -y -q gnupg2 curl git ca-certificates apt-transport-https openssh-client && \
  curl https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
  curl https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list && \
  apt-get -q update

if [ $? -eq 0 ]
then
  if [ "$DART_VERSION" = "latest" ]
  then
    apt-get install dart
  else
    apt-get install dart=$DART_VERSION-1
  fi
fi
