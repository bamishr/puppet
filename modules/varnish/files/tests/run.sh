#!/bin/sh

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 change_id hostname"
    exit 1
fi

vagrant ssh -c "export JENKINS_USERNAME=$JENKINS_USERNAME ; export JENKINS_API_TOKEN=$JENKINS_API_TOKEN ; cd /vagrant/ ; ./run.py $2 $1 /utils/pcc"
