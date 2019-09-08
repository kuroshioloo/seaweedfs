#!/bin/bash

#设置common脚本的位置
CUR_DIR=`pwd`

# 脚本参数操作
if [ $# -lt 1 ];then
    echo "param error!"
    echo "./deploy_seaweedfs_sign.sh [deploy|stop|start|clear]"
    exit 1
fi
OPTION=$1

#安装seaweedfs
# https://github.com/chrislusf/seaweedfs/releases
# 下载程序包

WEED_TGZ=linux_amd64.tar.gz
#检查WEED安装包是否存在
if [ ! -e ${WEED_TGZ} ];then
    echo "${WEED_TGZ} is not exist, please download first! [https://github.com/chrislusf/seaweedfs/releases]"
    exit 1
fi

WEED=weed
WEED_DIR=/usr/local/bin
WEED_BIN=${WEED_DIR}/${WEED}

WEED_DATA_DIR=/data/weedfs
V_PORT=18082
M_PORT=9333
#010同中心不同rack复制一份
REPLICATION=110

FRIST_PEER=9.147.21.210
PEERS=9.147.21.210:9333,9.147.20.181:9333,9.147.20.32:9333

#部署supervisor的配置文件目录，由supervisor部署脚本决定，默认:/etc/supervisord.d/conf/
SUPERVISOR_INI=/etc/supervisord.d/conf/
TEMPLATE_MASTER=template_master.ini
TEMPLATE_VOLUME=template_volume.ini

#服务部署信息
# | ip | 数据目录 | 端口 |
MASTER_NODES=(
    '9.147.21.210 /data/weedfs/master'
)

#seaweedfs volume部署信息
VOLUME_NODES=(
    '9.147.21.210 /mnt/fs_volume/volumes rack1 18082 dc1 15'
)
#'10.1.1.20 /mnt/fs_volume/volumes rack2 18082 dc1 15'
#'10.1.1.21 /mnt/fs_volume/volumes rack1 18082 dc2 15'

#所有需要部署seaweedfs服务的节点
ALL_NODES=(
    '9.147.21.210'
)

function replace() {
    KEY=$1
    VALUE=$2
    FILE=$3

    #区分mac os和linux系统
    if [ "$(uname)" == "Darwin" ];then
        sed -i "" "s#$KEY#$VALUE#g" $FILE
    elif [ "$(uname)" == "Linux" ];then
        sed -i "s#$KEY#$VALUE#g" $FILE
    fi
}

#部署master服务
function deploy_seaweedfs_master() {
    echo "deploy_seaweedfs_master"
    NODE=$1
    PEERS=$2
    INDEX=$3
    DIR=$4

    #创建目录
    mkdir -p ${DIR}

    MASTER_APP=seaweedfs_master_$INDEX
    MASTER_INI=seaweedfs_master_$INDEX.ini

    #创建配置文件
    cp -f ${TEMPLATE_MASTER} ${MASTER_INI}

    # 修改参数
    replace "{{NAME}}" ${MASTER_APP} ${MASTER_INI}
    replace "{{WEED_DIR}}" ${WEED_DIR} ${MASTER_INI}
    replace "{{WEED_BIN}}" ${WEED_BIN} ${MASTER_INI}
    replace "{{M_PORT}}" ${M_PORT} ${MASTER_INI}
    replace "{{NODE}}" ${NODE} ${MASTER_INI}
    replace "{{DATA}}" ${DIR} ${MASTER_INI}
    replace "{{PEERS}}" ${PEERS} ${MASTER_INI}
    replace "{{REPLICATION}}" ${REPLICATION} ${MASTER_INI}

    #长传文件
    cp -f ${MASTER_INI} ${SUPERVISOR_INI}

    #删除文件
    rm -f ${MASTER_INI}
}

#部署volume服务
function deploy_seaweedfs_volume() {
    echo "deploy_seaweedfs_volume"
    NODE=$1
    INDEX=$2
    DIR=$3
    RACK=$4
    MSERVER=$5
    PORT=$6
    DC=$7
    MAX=$8

    #创建目录
    mkdir -p ${DIR}

    #创建配置文件
    VOLUME_APP=seaweedfs_volume_$INDEX
    VOLUME_INI=seaweedfs_volume_$INDEX.ini

    # 复制template_volume
    cp -f ${TEMPLATE_VOLUME} ${VOLUME_INI}

    # 修改参数
    replace "{{NAME}}" ${VOLUME_APP} ${VOLUME_INI}
    replace "{{WEED_DIR}}" ${WEED_DIR} ${VOLUME_INI}
    replace "{{WEED_BIN}}" ${WEED_BIN} ${VOLUME_INI}
    replace "{{V_PORT}}" ${PORT} ${VOLUME_INI}
    replace "{{NODE}}" ${NODE} ${VOLUME_INI}
    replace "{{DATA}}" ${DIR} ${VOLUME_INI}
    replace "{{MSERVER}}" ${MSERVER} ${VOLUME_INI}
    replace "{{DATACENTER}}" ${DC} ${VOLUME_INI}
    replace "{{RACK}}" ${RACK} ${VOLUME_INI}
    replace "{{MAX}}" ${MAX} ${VOLUME_INI}

    #上传
    cp -f ${VOLUME_INI} ${SUPERVISOR_INI}

    #删除临时文件
    rm -f ${VOLUME_INI}
}

#停止
function stop_seaweedfs() {
    echo "stop_seaweedfs"
}

#启动
function start_seaweedfs() {
    echo "start_seaweedfs"
}

#部署weed二进制文件
function dispatch_seaweedfs_bin() {
    #解包weed
    tar -zxf ${WEED_TGZ}

    #部署weed文件
    cp -f ${WEED} ${WEED_DIR}
}

#部署
function deploy_seaweedfs() {
    #创建配置并上传
    FIRST_MSERVER=${FRIST_PEER}:${M_PORT}
    MSERVER_PEERS=${PEERS}

    echo "MSERVER_PEERS=${MSERVER_PEERS}"

    INDEX=0
    for N in "${MASTER_NODES[@]}";
    do
        INDEX=$(($INDEX+1))
        echo "MASTER: $INDEX"
        MNODE=(${N})
        IP=${MNODE[0]}
        DIR=${MNODE[1]}
        deploy_seaweedfs_master ${IP} ${MSERVER_PEERS} ${INDEX} ${DIR}
    done

    INDEX=0
    for N in "${VOLUME_NODES[@]}";
    do
        INDEX=$(($INDEX+1))
        echo "VOLUME: $INDEX"
        VNODE=(${N})
        IP=${VNODE[0]}
        DIR=${VNODE[1]}
        RACK=${VNODE[2]}
        PORT=${VNODE[3]}
        DC=${VNODE[4]}
        MAX=${VNODE[5]}
        deploy_seaweedfs_volume ${IP} ${INDEX} ${DIR} ${RACK} ${FIRST_MSERVER} ${PORT} ${DC} ${MAX}
    done

    #启动服务
}

#清理
function clear_seaweedfs() {
    echo "clear_seaweedfs"
}

###############################################
## main
###############################################

case $OPTION in
    "dispatch")
        echo "dispatch seaweedfs bin"
        dispatch_seaweedfs_bin
        ;;
    "start")
        echo "start seaweedfs"
        start_seaweedfs
        ;;
    "stop")
        echo "stop seaweedfs"
        stop_seaweedfs
        ;;
    "deploy")
        echo "deploy seaweedfs"
        deploy_seaweedfs
        ;;
    "clear")
        echo "clear seaweedfs"
        stop_seaweedfs
        clear_seaweedfs
        ;;
    *)
        echo "Usage: $OPTION [start|stop|deploy|clear]"
        exit1
        ;;
esac