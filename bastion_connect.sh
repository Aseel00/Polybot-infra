#!/bin/bash

# Exit if KEY_PATH is not set
if [ -z "$KEY_PATH" ]; then
  echo "KEY_PATH env var is expected"
  exit 5
fi


# Get the number of arguments
ARGC=$#



# Case 2: Only Bastion IP provided (connect to bastion)
if [ $ARGC -eq 1 ]; then
  BASTION_IP=$1
  ssh -i "$KEY_PATH" ubuntu@$BASTION_IP

# Case 1 and 3: Bastion IP + Target private IP + optional command
elif [ $ARGC -ge 2 ]; then
  BASTION_IP=$1
  TARGET_IP=$2
  shift 2

  # If a command is provided (Case 3), run it on the target
  if [ $# -gt 0 ]; then
    ssh -i "$KEY_PATH" -o ProxyCommand="ssh -i $KEY_PATH -W %h:%p ubuntu@$BASTION_IP" ubuntu@$TARGET_IP "$@"
  else
    ssh -i "$KEY_PATH" -o ProxyCommand="ssh -i $KEY_PATH -W %h:%p ubuntu@$BASTION_IP" ubuntu@$TARGET_IP
  fi

# Case 4: Bad usage
else
  echo "Please provide bastion IP address"
  exit 5
fi
