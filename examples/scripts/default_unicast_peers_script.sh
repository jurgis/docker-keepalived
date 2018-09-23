#!/bin/bash

# Another service name can be passed as the first argument $1

DEFAULT_SERVICE_NAME=keepalived-vip.kube-system.svc.cluster.local
SERVICE_NAME=${1:-$DEFAULT_SERVICE_NAME}

dig +short $SERVICE_NAME

