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
source "${OPERATOR_REPO}"/.github/bin/common.sh
source "${OPERATOR_REPO}"/.github/bin/oauth-provision.sh

# Stop execution on any error
trap "catchFinish" EXIT SIGINT

deployChe() {
  chectl server:deploy  --telemetry=off --workspace-engine=dev-workspace --platform=openshift --installer=operator --batch
}

runTest() {
  deployChe
  waitDevWorkspaceControllerStarted

  # wait for 2 min for devworkspace-controller ready to work.
  sleep 120
  createWorkspaceDevWorkspaceController
  waitWorkspaceStartedDevWorkspaceController 
  sleep 120
  oc get pods -n ${NAMESPACE}
  oc get routes -n ${NAMESPACE}

  wsname=$(oc get pods  | grep workspace | awk '{print $1}')
  oc logs $wsname -c theia-ide
  oc logs $wsname -c terminal
  oc get events -n ${NAMESPACE}

  # patch pod.yaml 
  wget https://gist.githubusercontent.com/SkorikSergey/3ce0000301d122b6a41782a98229ccc3/raw/0ef3858a21fbae844b1e0f691dee25a3b1fbe8ce/happy-path-pod.yaml
  ECLIPSE_CHE_URL=http://$(oc get route -n "${NAMESPACE}" che -o jsonpath='{.status.ingress[0].host}')
  TS_SELENIUM_DEVWORKSPACE_URL="https://$(oc get route -n "${NAMESPACE}" | grep theia/ | awk '{print $2}')/theia/"
  sed -i "s@CHE_URL@${ECLIPSE_CHE_URL}@g" happy-path-pod.yaml
  sed -i "s@WORKSPACE_ROUTE@${TS_SELENIUM_DEVWORKSPACE_URL}@g" happy-path-pod.yaml
  cat happy-path-pod.yaml

  oc apply -f happy-path-pod.yaml
  # wait for the pod to start
  while true; do
    sleep 3
    PHASE=$(oc get pod -n ${NAMESPACE} happy-path-che \
        --template='{{ .status.phase }}')
    if [[ ${PHASE} == "Running" ]]; then
        break
    fi
  done

  # wait for the test to finish
  oc logs -n ${NAMESPACE} happy-path-che -c happy-path-test -f

  # just to sleep
  sleep 3

  # download the test results
  mkdir -p tmp/
  oc rsync -n ${NAMESPACE} happy-path-che:/tmp/e2e/report/ tmp/ -c download-reports
  oc exec -n ${NAMESPACE} happy-path-che -c download-reports -- touch /tmp/done
}

initDefaults
installYq
runTest
