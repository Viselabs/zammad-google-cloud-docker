#!/bin/bash
#set -ex

if [ -z "$1" ] || [ ! -d "$1" ]; then
  echo "You have to enter the name of a module."
  echo ""
  echo "Examples:"
  echo "$ build.sh REPOSITORY VERSION"
  echo "$ build.sh ayxon-dynamics/centos-zammad 5.0.1"
  echo "$ build.sh ayxon-dynamics/centos-zammad"
  exit 1
fi

TAG="latest"
if [ -n "$2" ]; then
  TAG=$2
fi

docker buildx build --build-arg BUILD_DATE="$(date --rfc-3339=seconds)" -t "$1" ./"$1"
docker tag "$1" "$1":latest
docker tag "$1" eu.gcr.io/$(gcloud config get-value project)/"$1":latest

if [ -n "$2" ]; then
  docker tag "$1" "$1":"$TAG"
  docker tag "$1" eu.gcr.io/$(gcloud config get-value project)/"$1":"$TAG"
fi
