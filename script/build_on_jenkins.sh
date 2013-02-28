#!/bin/sh

# This file really shouldn't be in the hubspot_static_daemon...

export JENKINS_ROOT=${JENKINS_ROOT-'/mnt/jenkins-home'}
export RVM_ROOT=${RVM_ROOT-"$JENKINS_ROOT/rvm"}

export HOME=JENKINS_ROOT

echo -e "\nPrepare ruby env"

export rvm_path="$RVM_ROOT"
source $RVM_ROOT/scripts/rvm
rvm use 1.9.3

echo -e "\nUpdate the static daemon"


if [ -z "$USE_FUTURE_BUILD_SCRIPT" ]; then
    cd $JENKINS_ROOT/hubspot_static_daemon
    rvm gemset use default --create
    git checkout master
else
    echo -e "Using the future branch"
    cd $JENKINS_ROOT/hubspot_static_daemon_future
    rvm gemset use future --create
    git checkout future
fi  

git pull
bundle install --without=development

# Load some keys/passwords we don't want to store in the repo
source /mnt/jenkins-home/.hubspot/s3_creds

# Do that shit
ruby ./script/build_and_upload_to_s3.rb
