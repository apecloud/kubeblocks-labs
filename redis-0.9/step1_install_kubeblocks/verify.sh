#!/bin/bash

# Run the command and capture its output
output="$(kubectl get deployment -n kb-system 2>&1)"

# Print the command prompt line as desired
echo "controlplane \$ k get deployment -n kb-system"
echo "$output"

# Check for the three deployments and a READY count of 1/1
if echo "$output" | grep -q "kb-addon-snapshot-controller" \
   && echo "$output" | grep -q "kubeblocks " \
   && echo "$output" | grep -q "kubeblocks-dataprotection" \
   && echo "$output" | grep -q "1/1"
then
  echo "done"
  exit 0
else
  echo "not ready yet"
  exit 1
fi