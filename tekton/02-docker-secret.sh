#!/bin/bash
# Run this script to create the Docker registry secret for ACR
# Usage: ./02-docker-secret.sh <acr_username> <acr_password> <acr_name>

USER_NAME=${1:?"Usage: $0 <username> <password> <acr_name>"}
PASSWORD=${2:?"Usage: $0 <username> <password> <acr_name>"}
ACR_NAME=${3:?"Usage: $0 <username> <password> <acr_name>"}

echo "$USER_NAME:$PASSWORD" | base64 -w0 | \
  jq -R -c "{\"auths\": {\"${ACR_NAME}.azurecr.io\": {\"auth\": .}}}" > config.json

kubectl create secret generic docker-credentials \
  --from-file=config.json=./config.json \
  --namespace=default

rm config.json
echo "Docker credentials secret created!"
