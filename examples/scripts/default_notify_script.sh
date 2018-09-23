#!/bin/bash

# Set to INSTANCE or GROUP, depending on whether Keepalived invoked the program from vrrp_instance or vrrp_sync_group.
TYPE=$1

# Set to the name of the vrrp_instance or vrrp_sync_group.
NAME=$2

# Set to the end state of the transition: BACKUP, FAULT, or MASTER.
STATE=$3

echo "DEFAULT_NOTIFY_SCRIPT: VRRP $TYPE $NAME changed to state $STATE"

case $STATE in
  "BACKUP") # Perform action for transition to BACKUP state
    exit 0
    ;;

  "FAULT")  # Perform action for transition to FAULT state
    exit 0
    ;;

  "MASTER") # Perform action for transition to MASTER state
    exit 0
    ;;

  *)
    echo "Unknown state ${STATE} for VRRP ${TYPE} ${NAME}"
    exit 1
    ;;
esac

exit 0

