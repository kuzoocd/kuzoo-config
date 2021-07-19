#!/bin/bash
set -e
#set -x

#
# uploads global and apps folders to kuzoo hub using kuzoo api for validation
# polls for validation result until result is obtained, or timeout is reached
# validation logic is designed to fail fast as soon as it encounters any error
#
# required tools - curl, jq, tar
# must be run from this scripts directory
#

#
# globals
#
NUM_POLLS=10
KUZOO_API_AUTH_URL=http://kuzoo.com:3000/apiauth
KUZOO_UPLOAD_URL=http://kuzoo.com:3000/api/artifact/uploadArtifactsForValidation
KUZOO_POLL_URL=http://kuzoo.com:3000/api/artifact/pollValidationResult
KUZOO_ACCOUNT=kuzoodotcom
KUZOO_API_USER=
KUZOO_API_TOKEN=

#
# functions
#
apiAuthenticate() {
  echo "api login"
  local response=$(curl -s -X POST -H 'Content-Type: application/json' -d'{"account": "'$KUZOO_ACCOUNT'","username": "'${KUZOO_API_USER}'","token": "'$KUZOO_API_TOKEN'"}' ${KUZOO_API_AUTH_URL})
  JWT=$(echo "$response" | jq -r '.token')
}

bundleGlobal() {
  cd ..
  tar -czf scripts/global.tar.gz global
  cd - &>/dev/null
}

bundleApps() {
  cd ..
  tar -czf scripts/apps.tar.gz apps
  cd - &>/dev/null
}

uploadBundles() {
  echo "uploading bundles"
  local response=$(curl -s -X POST -H "Authorization: Bearer ${JWT}" -F 'global=@global.tar.gz' -F 'apps=@apps.tar.gz' ${KUZOO_UPLOAD_URL})
  POLL_KEY=$(echo "$response" | jq -r '.key')
}

deleteBundles() {
  rm global.tar.gz
  rm apps.tar.gz
}

pollTillResultOrTimeout() {
  echo "polling for results"
  sleep 2s
  for i in $(seq 1 $TIMEOUT_MINUTES); do
    local response=$(curl -s -X GET -H "Authorization: Bearer ${JWT}" -H 'Content-Type: application/json' "${KUZOO_POLL_URL}?key=${POLL_KEY}")
    local status=$(echo "$response" | jq -r '.status')
    if [[ $status != 'pending' ]]; then
      echo "$response" | jq .
      if [[ $status == 'success' ]]; then
        exit 0
      else
        exit 1
      fi
    fi
    sleep 30s
  done
}

#
# main
#

apiAuthenticate
bundleGlobal
bundleApps
uploadBundles
deleteBundles
pollTillResultOrTimeout
