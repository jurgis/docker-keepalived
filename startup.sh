#!/bin/bash

# Startup script for keepalived
# 1. Wait for keepalived config template
# 2. Parse the template substituting following variables
#    * NODE_PRIORITY = 100 unless another variable provided in the environment
#    * ROUTER_ID = hostname
#    * UNICAST_PEERS = list of all keepalived server ip addresses (read from DNS entries)
#    * PASSWORD = the password (read from kubernetes secrets)
#    * VIRTUAL_IP = the virtual ip address (provided from kubernetes ConfigMap)
#    * ... TODO: add the others...
# 3. Check for configuration changes
# 4. Parse config file if it has changed and reload keepalived


# definign variables
# Directories
KEEPALIVED_DIR="/etc/keepalived"
SCRIPTS_DIR="$KEEPALIVED_DIR/scripts"
CONFIG_DIR="$KEEPALIVED_DIR/config"
SECRETS_DIR="$KEEPALIVED_DIR/secrets"

# Files
CONFIG_FILE="$KEEPALIVED_DIR/keepalived.conf"
CONFIG_TEMPLATE_FILE="$CONFIG_DIR/keepalived.conf"

# Configuration in files
PASSWORD_CONFIG_FILE="$SECRETS_DIR/keepalived-password"
UNICAST_PEERS_CONFIG_FILE="$CONFIG_DIR/unicast_peers"
VIRTUAL_IP_CONFIG_FILE="$CONFIG_DIR/virtual_ip"
UNICAST_PEERS_SERVICE_NAME_CONFIG_FILE="$CONFIG_DIR/unicast_peers_service_name"
CHECK_SCRIPT_CONFIG_FILE="$CONFIG_DIR/check_script"
NOTIFY_SCRIPT_CONFIG_FILE="$CONFIG_DIR/notify_script"
UNICAST_PEERS_SCRIPT_CONFIG_FILE="$CONFIG_DIR/unicast_peers_script"


# Set variables. If not defined set the default values.
set_variables()
{
  # Script files
  if [ -f "$CHECK_SCRIPT_CONFIG_FILE" ]; then
    CHECK_SCRIPT="$(cat $CHECK_SCRIPT_CONFIG_FILE)"
  fi
  CHECK_SCRIPT=${CHECK_SCRIPT:-/etc/keepalived/scripts/default_check_script.sh}
  
  if [ -f "$NOTIFY_SCRIPT_CONFIG_FILE" ]; then
    NOTIFY_SCRIPT="$(cat $NOTIFY_SCRIPT_CONFIG_FILE)"
  fi
  NOTIFY_SCRIPT=${NOTIFY_SCRIPT:-/etc/keepalived/scripts/default_notify_script.sh}

  if [ -f "$UNICAST_PEERS_SCRIPT_CONFIG_FILE" ]; then
    UNICAST_PEERS_SCRIPT="$(cat $UNICAST_PEERS_SCRIPT_CONFIG_FILE)"
  fi
  UNICAST_PEERS_SCRIPT=${UNICAST_PEERS_SCRIPT:-/etc/keepalived/scripts/default_unicast_peers_script.sh}

  if [ -f "$UNICAST_PEERS_SERVICE_NAME_CONFIG_FILE" ]; then
    UNICAST_PEERS_SERVICE_NAME=$(cat $UNICAST_PEERS_SERVICE_NAME_CONFIG_FILE)
  fi
  UNICAST_PEERS_SERVICE_NAME=${UNICAST_PEERS_SERVICE_NAME:-keepalived-vip.kube-system.svc.cluster.local}

  # Set node priority based on env variable
  if [ -z "$NODE_PRIORITY" ]; then
     NODE_PRIORITY=100
  fi

  ROUTER_ID=$(hostname)

  # Set the password password
  PASSWORD="UNDEFINED"
  if [ -f "$PASSWORD_CONFIG_FILE" ]; then
    PASSWORD=$(cat $PASSWORD_CONFIG_FILE)
  fi

  # Set unicast peers from static configuration
  UNICAST_PEERS="UNDEFINED"
  if [ -f "$UNICAST_PEERS_CONFIG_FILE" ]; then
    UNICAST_PEERS=$(cat $UNICAST_PEERS_CONFIG_FILE)
  fi

  # Override static configuration if script returns anything
  if [ -f "$UNICAST_PEERS_SCRIPT" ]; then
    UNICAST_PEERS2=$($UNICAST_PEERS_SCRIPT "$UNICAST_PEERS_SERVICE_NAME")
    if [ -n "$UNICAST_PEERS2" ]; then
      UNICAST_PEERS=$UNICAST_PEERS2
    fi
  fi

  # Set virtual ip address
  VIRTUAL_IP="UNDEFINED"
  if [ -f "$VIRTUAL_IP_CONFIG_FILE" ]; then
    VIRTUAL_IP=$(cat $VIRTUAL_IP_CONFIG_FILE)
  fi

  echo "========== VARIABLES =========="
  echo "KEEPALIVED_DIR: $KEEPALIVED_DIR"
  echo "CONFIG_DIR: $CONFIG_DIR"
  echo "CONFIG_FILE: $CONFIG_FILE"
  echo "CONFIG_TEMPLATE_FILE: $CONFIG_TEMPLATE_FILE"

  echo "CHECK_SCRIPT: $CHECK_SCRIPT"
  echo "NOTIFY_SCRIPT: $NOTIFY_SCRIPT"
  echo "UNICAST_PEERS_SCRIPT: $UNICAST_PEERS_SCRIPT"

  echo "NODE_PRIORITY: $NODE_PRIORITY"
  echo "ROUTER_ID: $ROUTER_ID"
  echo "PASSWORD: $PASSWORD"
  echo "UNICAST_PEERS: $UNICAST_PEERS"
  echo "VIRTUAL_IP: $VIRTUAL_IP"
  echo "==============================="
}

# Prepare configuration file
prepare_config_file()
{
  # wait for the config file template (added as ConfigMap in kubernetes)
  while [ ! -f "$CONFIG_TEMPLATE_FILE" ]; do
    echo "Configuration template file not found at: $CONFIG_TEMPLATE_FILE"
    echo "Waiting for 10 seconds"
    sleep 10
  done

  # Configuration template file found, copy it and replace some variables
  echo "Copying config template file from $CONFIG_TEMPLATE_FILE to $CONFIG_FILE"
  cp $CONFIG_TEMPLATE_FILE $CONFIG_FILE

  echo "Setting Router ID to: $ROUTER_ID"
  sed -i "s/{{ROUTER_ID}}/$ROUTER_ID/" $CONFIG_FILE

  echo "Setting check script to: $CHECK_SCRIPT"
  sed -i "s|{{CHECK_SCRIPT}}|$CHECK_SCRIPT|" $CONFIG_FILE

  echo "Setting priority to: $NODE_PRIORITY"
  sed -i "s/{{NODE_PRIORITY}}/$NODE_PRIORITY/" $CONFIG_FILE

  echo "Setting password to: $PASSWORD"
  sed -i "s|{{PASSWORD}}|$PASSWORD|" $CONFIG_FILE

  echo "Setting virtual ip address to: $VIRTUAL_IP"
  sed -i "s/{{VIRTUAL_IP}}/$VIRTUAL_IP/" $CONFIG_FILE

  echo "Setting unicast peers to: $UNICAST_PEERS"
  # sed can't handle multiline values or I did not find how to do it
  # sed -i "s/{{UNICAST_PEERS}}/$UNICAST_PEERS/" $CONFIG_FILE
  perl -pi -e "s/\{\{UNICAST_PEERS\}\}/$UNICAST_PEERS/" $CONFIG_FILE

  echo "Setting notify script to: $NOTIFY_SCRIPT"
  sed -i "s|{{NOTIFY_SCRIPT}}|$NOTIFY_SCRIPT|" $CONFIG_FILE
}

# Termination function
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


# === main script ===
echo "Starting script execution"

# Call stop() function when termination is required
trap "stop; exit 0;" SIGTERM SIGINT

# stop keepalived if it is running
pkill keepalived

set_variables
prepare_config_file

# This loop runs until we've started up successfully
while true; do

  # Check if Keepalived is running by recording it's PID (if it's not running $pid will be null):
  pid=$(pidof keepalived)
  echo "Checking keepalived pid: $pid"

  # If $pid is null, do this to start or restart Keepalived:
  while [ -z "$pid" ]; do
    echo "Displaying resulting /etc/keepalived/keepalived.conf contents..."
    cat ${CONFIG_FILE}

    echo "Starting Keepalived in the background..."
    /usr/local/sbin/keepalived --dont-fork --dump-conf --log-console --log-detail --vrrp &
    
    # Sleep for 2 seconds (this is needed otherwise keepalived is started twice)
    # TODO: Maybe there is a better way to deal with this issue, but this is working as well
    sleep 2
    
    # Check if Keepalived is now running by recording it's PID (if it's not running $pid will be null):
    pid=$(pidof keepalived)
    echo "Checking keepalived pid2: $pid"

    # If $pid is null, startup failed; log the fact and sleep for 2s
    # We'll then automatically loop through and try again
    if [ -z "$pid" ]; then
      echo "Startup of Keepalived failed, sleeping for 2s, then retrying..."
      sleep 2
    fi
  done

  # Break this outer loop once we've started up successfully
  break
done

### TODO: Run another loop and reload configuration if it has changed

# Wait until the Keepalived processes stop (for some reason)
echo "Waiting for process with pid $pid to terminate..."

wait $pid
echo "The Keepalived process is no longer running, exiting..."
# Exit with an error
exit 1

