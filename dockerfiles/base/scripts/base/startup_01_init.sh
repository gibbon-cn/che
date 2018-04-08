#!/bin/sh
# Copyright (c) 2017 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html

init_usage() {
  USAGE="
USAGE: 
  docker run -it --rm <DOCKER_PARAMETERS> ${CHE_IMAGE_FULLNAME} [COMMAND]

MANDATORY DOCKER PARAMETERS:
  -v <LOCAL_PATH>:${CHE_CONTAINER_ROOT}                Where user, instance, and log data saved${ADDITIONAL_MANDATORY_PARAMETERS}  

OPTIONAL DOCKER PARAMETERS:${ADDITIONAL_OPTIONAL_DOCKER_PARAMETERS}  
  -v <LOCAL_PATH>:${CHE_CONTAINER_ROOT}/instance       Where instance, user, log data will be saved
  -v <LOCAL_PATH>:${CHE_CONTAINER_ROOT}/backup         Where backup files will be saved
  -v <LOCAL_PATH>:/repo                ${CHE_MINI_PRODUCT_NAME} git repo - uses local binaries and manifests
  -v <LOCAL_PATH>:/assembly            ${CHE_MINI_PRODUCT_NAME} assembly - uses local binaries 
  -v <LOCAL_PATH>:/sync                Where remote ws files will be copied with sync command
  -v <LOCAL_PATH>:/unison              Where unison profile for optimizing sync command resides
  -v <LOCAL_PATH>:/chedir              Soure repository to convert into workspace with Chedir utility${ADDITIONAL_OPTIONAL_DOCKER_MOUNTS}  
    
COMMANDS:
  archetype                            Generate, build, and run custom assemblies of ${CHE_MINI_PRODUCT_NAME}
  action <action-name>                 Start action on ${CHE_MINI_PRODUCT_NAME} instance
  backup                               Backups ${CHE_MINI_PRODUCT_NAME} configuration and data to ${CHE_CONTAINER_ROOT}/backup volume mount
  config                               Generates a ${CHE_MINI_PRODUCT_NAME} config from vars; run on any start / restart
  destroy                              Stops services, and deletes ${CHE_MINI_PRODUCT_NAME} instance data
  dir <command>                        Use Chedir and Chefile in the directory mounted to :/chedir
  download                             Pulls Docker images for the current ${CHE_MINI_PRODUCT_NAME} version
  help                                 This message
  info                                 Displays info about ${CHE_MINI_PRODUCT_NAME} and the CLI
  init                                 Initializes a directory with a ${CHE_MINI_PRODUCT_NAME} install
  offline                              Saves ${CHE_MINI_PRODUCT_NAME} Docker images into TAR files for offline install
  restart                              Restart ${CHE_MINI_PRODUCT_NAME} services
  restore                              Restores ${CHE_MINI_PRODUCT_NAME} configuration and data from ${CHE_CONTAINER_ROOT}/backup mount
  rmi                                  Removes the Docker images for <version>, forcing a repull
  ssh <wksp-name> [machine-name]       SSH to a workspace if SSH agent enabled
  start                                Starts ${CHE_MINI_PRODUCT_NAME} services
  stop                                 Stops ${CHE_MINI_PRODUCT_NAME} services
  sync <wksp-name>                     Synchronize workspace with local directory mounted to :/sync
  test <test-name>                     Start test on ${CHE_MINI_PRODUCT_NAME} instance
  upgrade                              Upgrades ${CHE_MINI_PRODUCT_NAME} from one version to another with migrations and backups
  version                              Installed version and upgrade paths${ADDITIONAL_COMMANDS}

GLOBAL COMMAND OPTIONS:
  --fast                               Skips networking, version, nightly and preflight checks
  --offline                            Runs CLI in offline mode, loading images from disk
  --debug                              Enable debugging of ${CHE_MINI_PRODUCT_NAME} server
  --trace                              Activates trace output for debugging CLI${ADDITIONAL_GLOBAL_OPTIONS}
  --help                               Get help for a command  
"
}

init_constants() {
  BLUE='\033[1;34m'
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[38;5;220m'
  BOLD='\033[1m'
  UNDERLINE='\033[4m'
  NC='\033[0m'

  # CLI DEVELOPERS - ONLY INCREMENT THIS CHANGE IF MODIFYING SECTIONS THAT AFFECT LOADING
  #                  BEFORE :/REPO IS VOLUME MOUNTED.  CLI ASSEMBLIES WILL FAIL UNTIL THEY
  #                  ARE RECOMPILED WITH MATCHING VERSION.
  CHE_BASE_API_VERSION=2
}

init_global_vars() {
  LOG_INITIALIZED=false
  FAST_BOOT=false
  CHE_DEBUG=false
  CHE_OFFLINE=false
  CHE_SKIP_NIGHTLY=false
  CHE_SKIP_NETWORK=false
  CHE_SKIP_PULL=false
  CHE_COMMAND_HELP=false
  CHE_SKIP_SCRIPTS=false

  DEFAULT_CHE_PRODUCT_NAME="CHE"
  CHE_PRODUCT_NAME=${CHE_PRODUCT_NAME:-${DEFAULT_CHE_PRODUCT_NAME}}

  # Name used in CLI statements
  DEFAULT_CHE_MINI_PRODUCT_NAME="che"
  CHE_MINI_PRODUCT_NAME=${CHE_MINI_PRODUCT_NAME:-${DEFAULT_CHE_MINI_PRODUCT_NAME}}

  DEFAULT_CHE_FORMAL_PRODUCT_NAME="Eclipse Che"
  CHE_FORMAL_PRODUCT_NAME=${CHE_FORMAL_PRODUCT_NAME:-${DEFAULT_CHE_FORMAL_PRODUCT_NAME}}

  # Path to root folder inside the container
  DEFAULT_CHE_CONTAINER_ROOT="/data"
  CHE_CONTAINER_ROOT=${CHE_CONTAINER_ROOT:-${DEFAULT_CHE_CONTAINER_ROOT}}

  # Turns on stack trace
  DEFAULT_CHE_CLI_DEBUG="false"
  CHE_CLI_DEBUG=${CLI_DEBUG:-${DEFAULT_CHE_CLI_DEBUG}}

  # Activates console output
  DEFAULT_CHE_CLI_INFO="true"
  CHE_CLI_INFO=${CLI_INFO:-${DEFAULT_CHE_CLI_INFO}}

  # Activates console warnings
  DEFAULT_CHE_CLI_WARN="true"
  CHE_CLI_WARN=${CLI_WARN:-${DEFAULT_CHE_CLI_WARN}}

  # Activates console output
  DEFAULT_CHE_CLI_LOG="true"
  CHE_CLI_LOG=${CLI_LOG:-${DEFAULT_CHE_CLI_LOG}}

  DEFAULT_CHE_ASSEMBLY_IN_REPO_MODULE_NAME="assembly/assembly-main"
  CHE_ASSEMBLY_IN_REPO_MODULE_NAME=${CHE_ASSEMBLY_IN_REPO_MODULE_NAME:-${DEFAULT_CHE_ASSEMBLY_IN_REPO_MODULE_NAME}}

  DEFAULT_CHE_ASSEMBLY_IN_REPO="${DEFAULT_CHE_ASSEMBLY_IN_REPO_MODULE_NAME}/target/eclipse-che*/eclipse-che-*"
  CHE_ASSEMBLY_IN_REPO=${CHE_ASSEMBLY_IN_REPO:-${DEFAULT_CHE_ASSEMBLY_IN_REPO}}

  DEFAULT_CHE_SCRIPTS_CONTAINER_SOURCE_DIR="/repo/dockerfiles/cli/scripts"
  CHE_SCRIPTS_CONTAINER_SOURCE_DIR=${CHE_SCRIPTS_CONTAINER_SOURCE_DIR:-${DEFAULT_CHE_SCRIPTS_CONTAINER_SOURCE_DIR}}

  DEFAULT_CHE_BASE_SCRIPTS_CONTAINER_SOURCE_DIR="/scripts/base"
  CHE_BASE_SCRIPTS_CONTAINER_SOURCE_DIR=${CHE_BASE_SCRIPTS_CONTAINER_SOURCE_DIR:-${DEFAULT_CHE_BASE_SCRIPTS_CONTAINER_SOURCE_DIR}}

  DEFAULT_CHE_LICENSE_URL="https://www.eclipse.org/legal/epl-v10.html"
  CHE_LICENSE_URL=${CHE_LICENSE_URL:-${DEFAULT_CHE_LICENSE_URL}}

  DEFAULT_CHE_IMAGE_FULLNAME="eclipse/che-cli:<version>"
  CHE_IMAGE_FULLNAME=${CHE_IMAGE_FULLNAME:-${DEFAULT_CHE_IMAGE_FULLNAME}}

  # Constants
  CHE_MANIFEST_DIR="/version"
  CHE_VERSION_FILE="${CHE_MINI_PRODUCT_NAME}.ver.do_not_modify"
  CHE_ENVIRONMENT_FILE="${CHE_MINI_PRODUCT_NAME}.env"
  CHE_COMPOSE_FILE="docker-compose-container.yml"
  CHE_HOST_COMPOSE_FILE="docker-compose.yml"

  # Keep for backwards compatibility
  DEFAULT_CHE_SERVER_CONTAINER_NAME="${CHE_MINI_PRODUCT_NAME}"
  CHE_SERVER_CONTAINER_NAME="${CHE_SERVER_CONTAINER_NAME:-${DEFAULT_CHE_SERVER_CONTAINER_NAME}}"
 
  DEFAULT_CHE_CONTAINER_NAME="${CHE_SERVER_CONTAINER_NAME}"
  CHE_CONTAINER_NAME="${CHE_CONTAINER:-${DEFAULT_CHE_CONTAINER_NAME}}"

  DEFAULT_CHE_CONTAINER_PREFIX="${CHE_SERVER_CONTAINER_NAME}"
  CHE_CONTAINER_PREFIX="${CHE_CONTAINER_PREFIX:-${DEFAULT_CHE_CONTAINER_PREFIX}}"

  CHE_BACKUP_FILE_NAME="${CHE_MINI_PRODUCT_NAME}_backup.tar.gz"
  CHE_COMPOSE_STOP_TIMEOUT="180"

  DEFAULT_CHE_CLI_ACTION="help"
  CHE_CLI_ACTION=${CHE_CLI_ACTION:-${DEFAULT_CHE_CLI_ACTION}}

  DEFAULT_CHE_LICENSE=false
  CHE_LICENSE=${CHE_LICENSE:-${DEFAULT_CHE_LICENSE}}

  if [[ "${CHE_CONTAINER_NAME}" = "${CHE_MINI_PRODUCT_NAME}" ]]; then   
    if [[ "${CHE_PORT}" != "${DEFAULT_CHE_PORT}" ]]; then
      CHE_CONTAINER_NAME="${CHE_CONTAINER_PREFIX}-${CHE_PORT}"
    else 
      CHE_CONTAINER_NAME="${CHE_CONTAINER_PREFIX}"
    fi
  fi

  DEFAULT_CHE_COMPOSE_PROJECT_NAME="${CHE_CONTAINER_NAME}"
  CHE_COMPOSE_PROJECT_NAME="${CHE_COMPOSE_PROJECT_NAME:-${DEFAULT_CHE_COMPOSE_PROJECT_NAME}}"

  DEFAULT_CHE_USER="root"
  CHE_USER="${CHE_USER:-${DEFAULT_CHE_USER}}"

  CHE_USER_GROUPS=""

  UNAME_R=${UNAME_R:-$(uname -r)}

}

usage() {
 # debug $FUNCNAME
  init_usage
  printf "%s" "${USAGE}"
}

init_cli_version_check() {
  if [[ $CHE_BASE_API_VERSION != $CHE_CLI_API_VERSION ]]; then
    printf "CLI base ($CHE_BASE_API_VERSION) does not match CLI ($CHE_CLI_API_VERSION) version.\n"
    printf "Recompile the CLI with the latest version of the CLI base.\n"
    return 1;
  fi
}

init_usage_check() {
  # If there are no parameters, immediately display usage

  if [[ $# == 0 ]]; then
    usage
    return 1
  fi

  if [[ "$@" == *"--fast"* ]]; then
    FAST_BOOT=true
  fi

  if [[ "$@" == *"--debug"* ]]; then
    CHE_DEBUG=true
  fi

  if [[ "$@" == *"--offline"* ]]; then
    CHE_OFFLINE=true
  fi

  if [[ "$@" == *"--trace"* ]]; then
    CHE_TRACE=true
    set -x
  fi

  if [[ "$@" == *"--skip:nightly"* ]]; then
    CHE_SKIP_NIGHTLY=true
  fi

  if [[ "$@" == *"--skip:network"* ]]; then
    CHE_SKIP_NETWORK=true
  fi

  if [[ "$@" == *"--skip:pull"* ]]; then
    CHE_SKIP_PULL=true
  fi

  if [[ "$@" == *"--help"* ]]; then
    CHE_COMMAND_HELP=true
  fi

  if [[ "$@" == *"--skip:scripts"* ]]; then
    CHE_SKIP_SCRIPTS=true
  fi
}

cleanup() {
  RETURN_CODE=$?

  # CLI developers should only return '3' in code after the init() method has completed.
  # This will check to see if the CLI directory is not mounted and only offer the error
  # message if it isn't currently mounted.
  if [ $RETURN_CODE -eq "3" ]; then
    error ""
    error "Unexpected exit: Trace output saved to $CHE_HOST_CONFIG/cli.log."
  fi
}

start() {
  # pre_init is unique to each CLI assembly. This can be called before networking is established.
  source "/scripts/pre_init.sh"
  pre_init

  # Yo, constants
  # 初始化常量
  init_constants

  # Variables used throughout
  # 初始化全局变量
  init_global_vars

  # Check to make sure CLI assembly matches base
  # 保证CLI程序集与base相匹配
  init_cli_version_check

  # Checks for global parameters
  # 检查全局参数
  init_usage_check "$@"

  # Removes global parameters from the positional arguments
  # 从位置参数中去除全局参数
  ORIGINAL_PARAMETERS=$@
  set -- "${@/\-\-fast/}"
  set -- "${@/\-\-debug/}"
  set -- "${@/\-\-offline/}"
  set -- "${@/\-\-trace/}"
  set -- "${@/\-\-skip\:nightly/}"
  set -- "${@/\-\-skip\:network/}"
  set -- "${@/\-\-skip\:pull/}"
  set -- "${@/\-\-help/}"
  set -- "${@/\-\-skip\:scripts/}"

  source "${CHE_BASE_SCRIPTS_CONTAINER_SOURCE_DIR}"/startup_02_pre_docker.sh

  # Make sure Docker is working and we have /var/run/docker.sock mounted or valid DOCKER_HOST
  # 确保Docker在工作，以及/var/run/docker.sock已经加载，或者DOCKER_HOST有效（使用hash命令）
  # 最终获取CHE_VERSION变量，例如 6.3.0或latest等
  init_check_docker "$@"

  # Check to see if Docker is configured with a proxy and pull values
  # 确保Docker配置有代理，根据 docker info 输出变量http_proxy/https_proxy/no_proxy
  init_check_docker_networking

  # Verify that -i is passed on the command line
  # 确认-i在命令行中，根据 -t 1 和 docker inspect来判断
  init_check_interactive "$@"

  # Only verify mounts after Docker is confirmed to be working.
  # 确认挂载点
  init_check_mounts "$@"

  # Extract the value of --user from the docker command line
  # 提取由docker命令行传入的--user值，通过docker inspect命令
  init_check_user "$@"

  # Extract the value of --group-add from the docker command line
  # 提取由docker命令行传入的group-add参数
  init_check_groups "$@"

  # Only initialize after mounts have been established so we can write cli.log out to a mount folder
  # 在挂载建立后进行初始化，以便将cli.log输出到挂载的目录；/data/cli.log
  init_logging "$@"

  # Determine where the remaining scripts will be sourced from (inside image, or repo?)
  # 确定剩下的脚本从哪里获取，实在镜像内，还是仓库？
  # ${CHE_LOCAL_REPO} 本地仓库设置，检查方法是根据挂载的/data目录下的repo目录相关信息（？）
  # skip_script参数
  # SCRIPTS_BASE_CONTAINER_SOURCE_DIR = /repo/dockerfiles/base/scripts/base
  # 或者...
  init_scripts "$@"

  # We now know enough to load scripts from different locations - so source from proper source
  # 加载脚本
  source "${SCRIPTS_BASE_CONTAINER_SOURCE_DIR}"/startup_03_pre_networking.sh

  # If offline mode, then load dependent images from disk and populate the local Docker cache.
  # 如果是离线模式，则从磁盘加载独立的镜像，然后发布到本地的Docker缓存中
  # 检查CHE_OFFLINE参数，即offline全局参数；同时，容器存储地址为/data/backup，使用docker load加载容器
  # If not in offline mode, verify that we have access to DockerHub.
  # 如果不是离线模式，而且没有执行is_fast和skip_network选项，则确保能够访问DockerHub，否则失败；
    # 略过网络 --skip:network
  # This is also the first usage of curl
  # 第一次使用curl
  init_offline_or_network_mode "$@"

  # Pull the list of images that are necessary. If in offline mode, verifies that the images
  # 在必要时拉取镜像，如果是离线模式，则确保镜像已经加载到缓存
  # are properly loaded into the cache.
    # 此处代码没有对offline模式进行判断，直接使用docker images -q进行判断，如果不存在，则执行docker pull拉取镜像
    # 问题点
  init_initial_images "$@"

  # Each CLI assembly must provide this cli.sh - loads overridden functions and variables for the CLI
  # 每个CLI程序集必须提供此cli.sh脚本，用于加载重载的方法和CLI变量
  # D:\USR\uGit\che-src\dockerfiles\cli\scripts\post_init.sh   
  source "${SCRIPTS_CONTAINER_SOURCE_DIR}"/post_init.shpost_init.sh

  # The post_init method is unique to each assembly. This method must be provided by 
  # a custom CLI assembly in their container and can set global variables which are 
  # specific to that implementation of the CLI. Place initialization functions that
  # require networking here.
  # post_init对每一个程序集都是唯一的。每个定制的CLI程序集在容器中都要提供该方法，并且能够设置对CLI实现特定的全局变量。
  # 放置需要网络的初始化函数。
  # 通过BOOTSTRAP_IMAGE_CHEIP容器来获取Docker主机的IP，推测为che-ip（？）
  post_init

  # Begin product-specific CLI calls
  # 开始与产品相关的CLI调用
  info "cli" "$CHE_VERSION - using docker ${DOCKER_SERVER_VERSION} / $(get_docker_install_type)"

  # D:\USR\uGit\che-src\dockerfiles\base\scripts\base\startup_04_pre_cli_init.sh
  source "${SCRIPTS_BASE_CONTAINER_SOURCE_DIR}"/startup_04_pre_cli_init.sh

  # Allow CLI assemblies to load variables assuming networking, logging, docker activated  
  # 允许CLI程序集加载命令，用以假定网络、日志、激活的docker
  cli_pre_init

  # Set CHE_HOST, CHE_PORT, and apply any CLI-specific command-line overrides to variables  
  # 设定 CHE_HOST, CHE_PORT, 并应用任意CLI特定的命令行来重写变量
  cli_init "$@"

  # Additional checks for nightly version
  # 对于nightly版本增加额外的检查，通过jq解析 docker inspect结果获取变量值
  cli_verify_nightly "$@"

  # Additional checks to verify image matches version installed on disk & upgrade suitability
  # 确保镜像与在磁盘上安装的一直，并适当地升级
    # upgrade标识 -> 升级
    # 未指定fast，检查版本
  cli_verify_version "$@"

  # Allow CLI assemblies to load variables assuming CLI is finished bootstrapping
  # 假定CLI以及完成启动，允许CLI程序集加载变量
  cli_post_init

  # D:\USR\uGit\che-src\dockerfiles\base\scripts\base\startup_05_pre_exec.sh
  source "${SCRIPTS_BASE_CONTAINER_SOURCE_DIR}"/startup_05_pre_exec.sh

  # Loads the library and associated dependencies
  # 加载类库和依赖项 D:\USR\uGit\che-src\dockerfiles\base\scripts\base\library.sh
  cli_load "$@"

  # Parses the command list for validity
  # 解析命令列表用于验证
  # 例如start COMMAND = cmd_start
  cli_parse "$@"

  # Executes command lifecycle
  # 执行命令生命周期，以start为例
  # 加载脚本 D:\USR\uGit\che-src\dockerfiles\base\scripts\base\commands\cmd_start.sh
  # 检查输入参数，如果有误，输出帮助 help_cmd_start
  # 执行函数，并检查执行结果
    # pre_cmd_start
    # cmd_start
    # post_cmd_start
  cli_execute "$@"
}
