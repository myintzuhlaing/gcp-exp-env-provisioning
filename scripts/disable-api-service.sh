#!/usr/bin/env bash

if [[ "$#" -lt 2 ]]; then
	echo "Usage: disable-api-service.sh <api-service> <project-id>"
	exit 1
fi

API_SERVICE=$1
PROJECT_ID=$2

RETRY=20
PAUSE=15

while true; do

  echo "[Attempting to Disable ${API_SERVICE}]"

  RESULT=$(gcloud services disable $API_SERVICE --force --project $PROJECT_ID 2> /dev/null)
  
  EXIT_STATUS=$?

  if [[ "$EXIT_STATUS" -eq 0 ]]; then
    echo "[API Service ${API_SERVICE} Successfully Disabled. EXIT_STATUS=${EXIT_STATUS}]"
    exit 0
  fi

  echo "[API Service ${API_SERVICE} Failed to be Disabled. EXIT_STATUS=${EXIT_STATUS}]"
  
  $((--RETRY)) > /dev/null 2>&1

  if [[ "$RETRY" -lt 0 ]]; then
    echo "[RETRY count exceeded]"
    exit 1
  fi

  echo "[Pausing for ${PAUSE} seconds before retrying]"
  sleep $PAUSE

  echo "[${RETRY} retries left]"
done