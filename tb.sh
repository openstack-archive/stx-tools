#!/bin/bash
# tb.sh - tbuilder commands
#
# Subcommands:
# env - Display a selection of configuration values
# exec - Starts a shell inside a running container
# run - Starts a container
# stop - Stops a running container
#
# Configuration
# tb.sh expects to find its configuration file buildrc in the current
# directory, like Vagrant looks for Vagrantfile.

SCRIPT_DIR=$(cd $(dirname "$0") && pwd)
WORK_DIR=$(pwd)

# Load tbuilder configuration
if [[ -r ${WORK_DIR}/buildrc ]]; then
    source ${WORK_DIR}/buildrc
fi

CMD=$1

TC_CONTAINER_NAME=${USER}-centos-builder
TC_CONTAINER_TAG=local/${USER}-stx-builder:7.3
TC_DOCKERFILE=Dockerfile.centos73.TC-builder

function exec_container {
    docker cp ${WORK_DIR}/buildrc ${TC_CONTAINER_NAME}:/home/${MYUNAME}
    docker cp ${WORK_DIR}/localrc ${TC_CONTAINER_NAME}:/home/${MYUNAME}
    docker exec -it --user=${MYUNAME} -e MYUNAME=${MYUNAME} ${TC_CONTAINER_NAME} script -q -c "/bin/bash" /dev/null
}

function run_container {
	# create localdisk
    mkdir -p ${LOCALDISK}/designer/${USER}/${PROJECT}

    docker run -it --rm \
        --name ${TC_CONTAINER_NAME} \
        --detach \
        -v ${LOCALDISK}:/${GUEST_LOCALDISK} \
        -v ${HOST_MIRROR_DIR}:/import/mirrors:ro \
        -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
        -v ~/.ssh:/mySSH:ro \
        -e "container=docker" \
        -e MYUNAME=${MYUNAME} \
        --privileged=true \
        --security-opt seccomp=unconfined \
        ${TC_CONTAINER_TAG}
}

function stop_container {
    docker stop ${TC_CONTAINER_NAME}
}

function kill_container {
    docker kill ${TC_CONTAINER_NAME}
}

function usage {
    echo "$0 [run|exec|env|stop|kill]"
}

case $CMD in
    env)
        echo "LOCALDISK=${LOCALDISK}"
        echo "GUEST_LOCALDISK=${GUEST_LOCALDISK}"
        echo "TC_DOCKERFILE=${TC_DOCKERFILE}"
        echo "TC_CONTAINER_NAME=${TC_CONTAINER_NAME}"
        echo "TC_CONTAINER_TAG=${TC_CONTAINER_TAG}"
        echo "SOURCE_REMOTE_NAME=${SOURCE_REMOTE_NAME}"
        echo "SOURCE_REMOTE_URI=${SOURCE_REMOTE_URI}"
        echo "HOST_MIRROR_DIR=${HOST_MIRROR_DIR}"
        echo "MY_TC_RELEASE=${MY_TC_RELEASE}"
        echo "MY_REPO_ROOT_DIR=${MY_REPO_ROOT_DIR}"
        ;;
	exec)
		exec_container
		;;
    run)
        run_container
        ;;
    stop)
        stop_container
        ;;
    kill)
        kill_container
        ;;
    *)
        echo "Unknown command: $CMD"
	usage
        exit 1
        ;;
esac
