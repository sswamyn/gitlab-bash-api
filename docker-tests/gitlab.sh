#!/bin/bash

# https://docs.gitlab.com/omnibus/docker/README.html

source "$(dirname $(realpath "$0"))/generated-config-bootstrap/init.sh"

function display_usage {
  echo "Usage: $0
  Start docker container
    $0 --start
    $0 --run
    $0 -s
  Restart docker container
    $0 --restart
  Configure private token
    $0 --configure-token
    $0 -t
  Stop and remove docker container
    $0 --stop
    $0 --remove
  Show help
    $0 --help
    $0 -h
" >&2
  exit 100
}

function docker_run {
  sudo docker run --detach \
    --hostname "${DOCKER_GITLAB_HTTP_HOST}" \
    --publish 443:443 --publish ${DOCKER_HTTP_PORT}:80 --publish ${DOCKER_SSH_PORT}:22 \
    --name "${DOCKER_NAME}" \
    --restart "${DOCKER_RESTART_MODE}" \
    --volume "${DOCKER_ETC_VOLUME}:/etc/gitlab" \
    --volume "${DOCKER_LOGS_VOLUME}:/var/log/gitlab" \
    --volume "${DOCKER_DATA_VOLUME}:/var/opt/gitlab" \
    "${DOCKER_GITLAB_VERSION}"
  docker_run_rc=$?

  if [ ${docker_run_rc} -ne 0 ]; then
    echo "*** docker run error :  ${docker_run_rc}" >&2
  fi
  if [ ${docker_run_rc} -eq 125 ]; then
    echo "Already running ? - try to restart
  $0 --restart
" >&2
  fi
}

function docker_restart {
  sudo docker restart "${DOCKER_NAME}"
}

function docker_stop_remove {
  sudo docker stop "${DOCKER_NAME}"
  sudo docker rm "${DOCKER_NAME}"
}

function generate_private_token {
  echo "Try to generate private token (Will fail if GitLab not yet fully started)" >&2

  "${DOCKER_GITLAB_HOME_PATH}/bin/generate-private-token.sh"
}

function display_help {
  echo "
To upgrade gitlab or change version (current version '${DOCKER_GITLAB_VERSION}')
or all to have cache all versions locally.
  sudo docker pull gitlab/gitlab-ce:latest
  sudo docker pull gitlab/gitlab-ce:rc
  sudo docker pull gitlab/gitlab-ee:latest
  sudo docker pull gitlab/gitlab-ee:rc

then stop and remove the existing container:
  $0 --stop

finally start the container as you did originally.
  $0 --start

To reset/delete everything
  $0 --stop
  sudo rm -fr "${DOCKER_ETC_VOLUME}" "${DOCKER_LOGS_VOLUME}" "${DOCKER_DATA_VOLUME}"
"
}

function main {
  local action_rc=0

  if [ $# -ne 1 ]; then
    display_usage
    action_rc=$?
  fi

  while [[ $# > 0 ]]; do
    param="$1"
    shift

    case "${param}" in
      --restart)
        docker_restart
        action_rc=$?
        ;;
      -s|--start|--run)
        docker_run
        action_rc=$?
        display_help
        ;;
      --stop|--remove)
        docker_stop_remove
        action_rc=$?
        ;;
      -h|--help)
        display_help
        display_usage
        action_rc=$?
        ;;
      -t|--configure-token)
        generate_private_token
        action_rc=$?
        ;;
      *)
        # unknown option
        echo "Unknown parameter ${param}" >&2
        display_usage
        action_rc=$?
        ;;
    esac
  done

  exit ${action_rc}
}

main "$@" || exit $?
