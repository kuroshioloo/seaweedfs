#!/bin/bash

# 前置条件
# 设置master节点到其他节点ssh passwdless


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
TEMPLATE_MASTER=template_master.ini
TEMPLATE_VOLUME=template_volume.ini
V_PORT=18082
M_PORT=9333
SUPERVISOR_INI=/etc/supervisord.d/conf/

# 解压
tar -zxf ${WEED_TGZ}

# 移动二进制文件
mv ${WEED} ${WEED_DIR}

# 设置执行权限
chmod +x ${WEED_BIN}

# 部署节点设置
# 大于等于3个节点，默认前三个设置master节点
# 注：需要先确定节点并修改后执行
NODES=(
    172.16.35.12
    172.16.35.10
    172.16.35.11
)

# seaweedfs的master节点peers
PEERS=${NODES[0]}:${M_PORT},${NODES[1]}:${M_PORT},${NODES[2]}:${M_PORT}
echo ${PEERS}

# 部署seaweedfs master
function deploy_master()
{
    # node, index
    echo $1,$2
    NODE=$1
    # 根据传入的index值设置rack
    NUM=$2
    n1=$[$NUM%2]
    if [ $n1 -eq 0 ];then
        echo "偶数"
    else
        echo "奇数"
    fi
    MASTER_APP=seaweedfs_master_$NUM
    MASTER_INI=seaweedfs_master_$NUM.ini
    DATA_MASTER=${WEED_DATA_DIR}/master_$NUM
    # 创建目录
    ssh root@${NODE} "mkdir -p ${DATA_MASTER}"
    
    # 复制template_volume
    cp ${TEMPLATE_MASTER} ${MASTER_INI}

    # 修改参数
    sed -i "s#{{NAME}}#${MASTER_APP}#g" ${MASTER_INI}
    sed -i "s#{{WEED_DIR}}#${WEED_DIR}#g" ${MASTER_INI}
    sed -i "s#{{WEED_BIN}}#${WEED_BIN}#g" ${MASTER_INI}
    sed -i "s#{{M_PORT}}#${M_PORT}#g" ${MASTER_INI}
    sed -i "s#{{NODE}}#${NODE}#g" ${MASTER_INI}
    sed -i "s#{{DATA}}#${DATA_MASTER}#g" ${MASTER_INI}
    sed -i "s#{{PEERS}}#${PEERS}#g" ${MASTER_INI}

    # 将文件部署到对应机器的supervisor配置目录下
    scp ${MASTER_INI} root@${NODE}:${SUPERVISOR_INI}
}

# 部署seaweedfs volume
function deploy_volume()
{
    # node,index
    echo $1,$2
    NODE=$1
    # 根据传入的index值设置rack
    NUM=$2
    n1=$[$NUM%2]
    if [ $n1 -eq 0 ];then
        echo "偶数"
        RACK=rc2
    else
        echo "奇数"
        RACK=rc1
    fi
    VOLUME_APP=seaweedfs_volume_$NUM
    VOLUME_INI=seaweedfs_volume_$NUM.ini
    DATA_VOLUME=${WEED_DATA_DIR}/volume_$NUM
    MSERVER=${NODE}:${M_PORT}

    # 创建目录
    ssh root@${NODE} "mkdir -p ${DATA_VOLUME}"

    # 复制template_volume
    cp ${TEMPLATE_VOLUME} ${VOLUME_INI}

    # 修改参数
    sed -i "s#{{NAME}}#${VOLUME_APP}#g" ${VOLUME_INI}
    sed -i "s#{{WEED_DIR}}#${WEED_DIR}#g" ${VOLUME_INI}
    sed -i "s#{{WEED_BIN}}#${WEED_BIN}#g" ${VOLUME_INI}
    sed -i "s#{{V_PORT}}#${V_PORT}#g" ${VOLUME_INI}
    sed -i "s#{{NODE}}#${NODE}#g" ${VOLUME_INI}
    sed -i "s#{{DATA}}#${DATA_VOLUME}#g" ${VOLUME_INI}
    sed -i "s#{{MSERVER}}#${MSERVER}#g" ${VOLUME_INI}
    sed -i "s#{{RACK}}#${RACK}#g" ${VOLUME_INI}

    # 将文件部署到对应机器的supervisor配置目录下
    scp ${VOLUME_INI} root@${NODE}:${SUPERVISOR_INI}
}

INDEX=0

for ND in "${NODES[@]}";
do
    INDEX=$(($INDEX+1))
    echo $INDEX

    # 部署weed
    scp ${WEED_BIN} root@$ND:${WEED_DIR} 

    # 部署配置文件
    deploy_master $ND $INDEX
    deploy_volume $ND $INDEX
done
