#!/bin/bash

# Set to INSTANCE or GROUP, depending on whether Keepalived invoked the program from vrrp_instance or vrrp_sync_group.
TYPE=$1

# Set to the name of the vrrp_instance or vrrp_sync_group.
NAME=$2

# Set to the end state of the transition: BACKUP, FAULT, or MASTER.
STATE=${3:-MASTER} # TODO: Remove when testing completed

echo "HETZNER_CLOUD_NOTIFY_SCRIPT: VRRP $TYPE $NAME changed to state $STATE"

if [ "$STATE" != "MASTER" ]; then
  echo "State not MASTER, ignoring it."
  exit 0
fi

API_BASE_URL="https://api.hetzner.cloud/v1"
# \s and \S do not work correctly on Mac (or I was doing something wrong)
API_TOKEN=$(cat ~/.config/hcloud/cli.toml | grep token | sed -E 's/^[ ]+token = "([^ ]+)"$/\1/')
API_AUTH_HEADER="Authorization: Bearer $API_TOKEN"
HOSTNAME=$(hostname)
FLOATING_IP=$(cat /etc/keepalived/config/virtual_ip)

# echo "API_KEY: $API_TOKEN"
# echo "API_AUTH_HEADER: $API_AUTH_HEADER"
echo "HOSTNAME: $HOSTNAME"

# Functions

get_api () {
  resource=${1:-unknown}
  result=$(curl --silent -H "$API_AUTH_HEADER" "$API_BASE_URL/$resource")
  if [ $? != "0" ]; then
    echo "Error when getting $resource: $?"
    exit 1
  fi

  echo $result
}

# Main function

# get current server id
servers=$(get_api "servers")
server_id=$(echo $servers | jq ".servers[] | select(.name == \"$HOSTNAME\") | .id")
if [ -z "$server_id" ]; then
  echo "Error while getting server id"
  exit 1
fi
echo "server_id: $server_id"

# get floating ip address id
floating_ips=$(get_api "floating_ips")
floating_ip_id=$(echo $floating_ips | jq ".floating_ips[] | select(.ip == \"$FLOATING_IP\") | .id")
if [ -z "$floating_ip_id" ]; then
  echo "Error while getting floating ip id"
  exit 1
fi
echo "floating_ip_id: $floating_ip_id"

# check if floating address is already assigned to this server
floating_ip_server_id=$(echo $floating_ips | jq ".floating_ips[] | select(.ip == \"$FLOATING_IP\") | .server")
if [ -n "$floating_ip_server_id" ] && [ "$floating_ip_server_id" == "$server_id" ]; then
  echo "Floating IP address $FLOATING_IP is already assigned to this server $HOSTNAME"
  exit 0
fi

# assign floating address to this server
url="$API_BASE_URL/floating_ips/$floating_ip_id/actions/assign"
data="{\"server\": $server_id}"
result=$(curl --silent -X POST -H "Content-Type: application/json" -H "$API_AUTH_HEADER" "$url" -d "$data")
if [ $? != "0" ]; then
  echo "Error when assigning floating ip address to server: $?"
  exit 1
fi

echo "Floating ip address $FLOATING_IP assigned to server $HOSTNAME"
exit 0
