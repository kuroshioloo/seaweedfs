#!/bin/bash
#部署supervisor服务

#设置common脚本的位置
CUR_DIR=`pwd`
COMMON_DIR=${CUR_DIR%/*}/common
echo "COMMON_DIR=${COMMON_DIR}"
export COMMON_SCRIPT_DIR=${COMMON_DIR}

. ${COMMON_SCRIPT_DIR}/common.sh

# 脚本参数操作
if [ $# -lt 1 ];then
    echo "param error!"
    echo "./deploy_supervisor.sh [deploy|stop|start|clear]"
    exit 1
fi
OPTION=$1

#需要部署supervisor的节点
NODES=(
    '10.1.1.19'
    '10.1.1.20'
    '10.1.1.21'
)

#安装supervisor的脚本
SCRIPT_INSTALL_SUPERVISOR=../supervisor/install_supervisor.sh
SUPERVISOR_SERVICE=../supervisor/supervisor.service

#安装supervisor
function install_supervisor() {
    IP=$1
    echo "install supervisor for ${IP}"

    DST_DIR=/tmp
    SERVICE_UNIT=/lib/systemd/system/

    #上传脚本
    deploy_upload ${IP} ${SCRIPT_INSTALL_SUPERVISOR} ${DST_DIR}

    #上传服务配置
    deploy_upload ${IP} ${SUPERVISOR_SERVICE} ${SERVICE_UNIT}

    #执行脚本
    deploy_ssh ${IP} "source /etc/profile; chmod +x /tmp/install_supervisor.sh; /tmp/install_supervisor.sh"
}

#启动
function start_supervisor() {
    echo "start_supervisor"
    
    for NODE in "${NODES[@]}";
    do
        deploy_ssh ${NODE} "systemctl start supervisor"
    done
}

#停止
function stop_supervisor() {
    echo "stop_supervisor"

    for NODE in "${NODES[@]}";
    do
        deploy_ssh ${NODE} "systemctl stop supervisor"
    done
}

#部署
function deploy_supervisor() {
    echo "deploy_supervisor"
    # install_supervisor "172.16.35.13"
    for NODE in "${NODES[@]}";
    do
        install_supervisor ${NODE}
    done
}

#清理
function clear_supervisor() {
    echo "need todo! clear_supervisor"
}

###############################################
## main
###############################################

case $OPTION in
    "start")
        echo "start supervisor"
        start_supervisor
        ;;
    "stop")
        echo "stop supervisor"
        stop_supervisor
        ;;
    "deploy")
        echo "deploy supervisor"
        deploy_supervisor
        ;;
    "clear")
        echo "clear supervisor"
        stop_supervisor
        clear_supervisor
        ;;
    *)
        echo "Usage: $OPTION [start|stop|deploy|clear]"
        exit1
        ;;
esac