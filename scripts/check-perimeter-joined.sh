#!/usr/bin/env bash

if [[ "$#" -lt 3 ]]; then
	echo "Usage: check-perimeter-joined.sh <access_policy_number> <perimeter_name> <project_identifier>"
	exit 1
fi

ACCESS_POLICY=$1
PERIMETER_NAME=$2
PROJECT_IDENTIFIER=$3

RETRY=25
PAUSE=10
VALUE_FORMAT="value(status.resources.list().sub(',', ' '))"

while true; do

  echo "[Attempting verification that Resource has joined Perimeter]"

  PROJECTS=$(gcloud access-context-manager perimeters describe $PERIMETER_NAME --policy $ACCESS_POLICY --format="$VALUE_FORMAT")
  
  for PROJECT in ${PROJECTS}; do 
    if [[ "$PROJECT" = "${PROJECT_IDENTIFIER}" ]]; then 
      echo "[PROJECT ${PROJECT} found in Perimeter]"
      exit 0
    fi
  done

  echo "[PROJECT ${PROJECT_IDENTIFIER} not contained in Perimeter]"

  $((--RETRY)) > /dev/null 2>&1

  if [[ "$RETRY" -lt 0 ]]; then 
    echo "[RETRY count exceeded]"
    exit 1
  fi

  echo "[Pausing for ${PAUSE} seconds before retrying]"
  sleep $PAUSE

  echo "[${RETRY} retries remaining]"
done