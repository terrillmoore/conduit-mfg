#!/bin/bash

# Use this script on a Conduit to regenerate the host keys. This
# can be needed after a catastrophic system failure. Terry had
# to use this for recovering the Nuvasoft unit remotely, for
# example.

for type in rsa dsa ecdsa ed25519; do
  ssh-keygen -t ${type} -N "" -f /etc/ssh/ssh_host_${type}_key
done
