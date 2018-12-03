#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

source ${SCRIPT_DIR}/functions.sh

CONFIGURATION="allinone"
CONTROLLER=${CONTROLLER:-controller}
DOMAIN_DIRECTORY=vms

destroy_controller ${CONFIGURATION} ${CONTROLLER}
