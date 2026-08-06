#!/bin/bash

echo "Removing stage/${1,,}/${2,,}/${3,,}"
rm -rf /home/geoffrey/dev/stage/${1,,}/${2,,}/${3,,}

echo "Recreating staging directory"
mkdir -p /home/geoffrey/dev/stage/${1,,}/${2,,}/${3,,}

if [ $# -eq 4 ] && [ ${4,,} = '--deep-clean' ]; then
  echo "Removing archives/${1,,}/${2,,}/${3,,}"
  rm -rf /home/geoffrey/dev/archives/${1,,}/${2,,}/${3,,}

  echo "Recreating archives directory"
  mkdir -p /home/geoffrey/dev/archives/${1,,}/${2,,}/${3,,}

  echo "Removing build/${1,,}/${2,,}/${3,,}/_deps/generated"
  rm -rf build/${1,,}/${2,,}/${3,,}/_deps/generated
fi

sleep 5