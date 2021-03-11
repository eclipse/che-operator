#!/bin/bash
#
# Copyright (c) 2012-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

################################ !!!   IMPORTANT   !!! ################################
########### THIS JOB USE openshift ci operators workflows to run  #####################
##########  More info about how it is configured can be found here: https://docs.ci.openshift.org/docs/how-tos/testing-operator-sdk-operators #############
#######################################################################################################################################################

# exit immediately when a command fails
set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail
# error on unset variables
set -u

export OPERATOR_REPO=$(dirname $(dirname $(readlink -f "$0")));
export DEVWORKSPACE_PROJECT=devworkspace-project
source "${OPERATOR_REPO}"/.github/bin/common.sh
source "${OPERATOR_REPO}"/.github/bin/oauth-provision.sh

# Stop execution on any error
trap "catchFinish" EXIT SIGINT

deployChe() {
  chectl server:deploy  --telemetry=off --workspace-engine=dev-workspace --platform=openshift --installer=operator --batch
}

runTest() {
  deployChe

  export n=0
  until
    if [ $n -gt 300 ]
    then
     echo "Failed to start workspace"
     # Get logs from 'devworkspace-webhook-server' pod
     wsname=$(oc get pods -n devworkspace-controller | grep devworkspace-webhook-server | awk '{print $1}')
     oc logs $wsname
     echo "Get logs from previous devworkspace-webhook-server pod"
     oc  logs -p $wsname

     exit 1
    fi

	  wsname=$(oc get pods -n devworkspace-controller | grep devworkspace-webhook-server | awk '{print $1}')
    oc get pod $wsname -n devworkspace-controller | grep -m 1 "Running"
  do
    oc get pod $wsname -n devworkspace-controller
    sleep 5
    n=$(( n+5 ))
  done

  oc new-project $DEVWORKSPACE_PROJECT
  sleep 10

  kubectl apply -f https://raw.githubusercontent.com/devfile/devworkspace-operator/main/samples/flattened_theia-next.yaml

  echo 'Wait pod readyness'
  export n=0
  until
    if [ $n -gt 300 ]
    then
     echo "Failed to start workspace"
     exit 1
    fi

	  wsname=$(oc get pods -n $DEVWORKSPACE_PROJECT | grep workspace | awk '{print $1}')
    oc get pod $wsname -n $DEVWORKSPACE_PROJECT | grep -m 1 "Running"
  do
    oc get pod $wsname -n $DEVWORKSPACE_PROJECT
    oc get pod $wsname -n devworkspace-controller
    sleep 5
    n=$(( n+5 ))
  done
}

initDefaults
installYq
runTest
