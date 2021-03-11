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
# export DEVWORKSPACE_PROJECT=devworkspace-project
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
  createWorkspaceDevWorkspaceController
  waitWorkspaceStartedDevWorkspaceController
}

initDefaults
installYq
runTest
