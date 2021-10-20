#!/bin/bash
#set -ex

if [ -z "$1" ] || [ ! -d "$1" ]; then
  echo "You have to enter the name of a module."
  echo ""
  echo "Examples:"
  echo "$ deploy.sh MODULE VERSION"
  echo "$ deploy.sh zammad 5.0.1 staging-1"
  echo "$ deploy.sh zammad 5.0.1"
  echo "$ deploy.sh zammad"
  exit 1
fi

TAG="latest"
if [ -n "$2" ]; then
  TAG=$2
fi

docker push eu.gcr.io/$(gcloud config get-value project)/"$1"

if [ -n "$2" ]; then
  docker push eu.gcr.io/$(gcloud config get-value project)/"$1":"$TAG"
fi

if [ -n "$3" ]; then
  gcloud beta compute ssh "$3" --command 'docker kill $(docker ps -q) && docker system prune -fa && (sleep 1s; sudo reboot &) && exit'
  echo "Deployment done. Exiting."
fi
