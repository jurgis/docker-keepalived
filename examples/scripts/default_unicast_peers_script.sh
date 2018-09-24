#!/bin/bash

# Another service name can be passed as the first argument $1

DEFAULT_SERVICE_NAME=keepalived-vip.kube-system.svc.cluster.local
SERVICE_NAME=${1:-$DEFAULT_SERVICE_NAME}

if [ -n "$KUBE_DNS_SERVICE_HOST" ]; then
  dig +short $SERVICE_NAME @$KUBE_DNS_SERVICE_HOST
else
  dig +short $SERVICE_NAME
fi

