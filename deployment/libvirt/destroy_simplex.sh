#!/usr/bin/env bash

MY_WORKING_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"
source ${MY_WORKING_DIR}/functions.sh

IDENTITY="simplex"
CONTROLLER=${CONTROLLER:-controller}

destroy_controller ${IDENTITY} ${CONTROLLER}
