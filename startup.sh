#!/bin/bash

# Startup script for keepalived
# 1. Wait for keepalived config template
# 2. Parse the template substituting following variables
#    * NODE_PRIORITY = 100 unless another variable provided in the environment
#    * ROUTER_ID = hostname
#    * UNICAST_PEERS = list of all keepalived server ip addresses (read from DNS entries)
#    * PASSWORD = the password (read from kubernetes secrets)
#    * VIRTUAL_IP = the virtual ip address (provided from kubernetes ConfigMap)
# 3. Check for configuration changes
# 4. Parse config file if it has changed and reload keepalived


# definign variables
CONFIG_DIR=/etc/keepalived
TEMPLATES_DIR=${CONFIG_DIR}/templates
CONFIG_FILE=${CONFIG_DIR}/keepalived.conf
CONFIG_TEMPLATE_FILE=${TEMPLATE_DIR}/keepalived.conf


# Call stop() function when termination is required
trap "stop; exit 0;" SIGTERM SIGINT

stop()
{
  echo "SIGTERM caught, terminating keepalived process..."

  pid=$(pidof keepalived)
  if [ -n "$pid" ]; then
    # kill the process
    kill -TERM $pid > /dev/null 2>&1
    # wait until process is killed
    wait $pid
  fi
   
  echo "Terminated."
  exit 0
}

# stop keepalived if it is running
pkill keepalived

# wait for the config file template (added as ConfigMap in kubernetes)
while [ ! -f "${CONFIG_TEMPLATE_FILE}" ]; do
  echo "Configuration template file not found at: ${CONFIG_TEMPLATE_FILE}"
  echo "Waiting for 10 seconds"
  sleep 10
done

# Configuration template file found, copy it and replace some variables
cp ${CONFIG_TEMPLATE_FILE} ${CONFIG_FILE}

# Set node priority based on env variable
if [ -z "$NODE_PRIORITY" ]; then
   NODE_PRIORITY=100
fi

echo "Setting priority to: $NODE_PRIORITY"
sed -i "s/{{NODE_PRIORITY}}/${NODE_PRIORITY}/" ${CONFIG_FILE}

ROUTER_ID=$(hostname)
echo "Setting Router ID to: $ROUTER_ID"
sed -i "s/{{ROUTER_ID}}/${ROUTER_ID}/" ${CONFIG_FILE}

### TODO: Substitute UNICAST_PEERS


# This loop runs till until we've started up successfully
while true; do

  # Check if Keepalived is running by recording it's PID (if it's not running $pid will be null):
  pid=$(pidof keepalived)

  # If $pid is null, do this to start or restart Keepalived:
  while [ -z "$pid" ]; do
    echo "Displaying resulting /etc/keepalived/keepalived.conf contents..."
    cat ${CONFIG_FILE}

    echo "Starting Keepalived in the background..."
    /usr/local/sbin/keepalived --dont-fork --dump-conf --log-console --log-detail --vrrp &
    
    # Check if Keepalived is now running by recording it's PID (if it's not running $pid will be null):
    pid=$(pidof keepalived)

    # If $pid is null, startup failed; log the fact and sleep for 2s
    # We'll then automatically loop through and try again
    if [ -z "$pid" ]; then
      echo "Startup of Keepalived failed, sleeping for 2s, then retrying..."
      sleep 2
    fi
  done

  # Break this outer loop once we've started up successfully
  # Otherwise, we'll silently restart and Rancher won't know
  break
done

### TODO: Run another loop and reload configuration if it has changed

# Wait until the Keepalived processes stop (for some reason)
wait $pid
echo "The Keepalived process is no longer running, exiting..."
# Exit with an error
exit 1

