#!/bin/bash

HOST=$(hostname)
echo "Starting services on $HOST..."

# Helper to start a service only if not already running
start_if_not_running() {
    local service=$1
    local cmd=$2
    if ! jps | grep -q "$service"; then
        echo "Starting $service..."
        $cmd
    else
        echo "$service is already running."
    fi
}

# Helper to wait until Active NameNode is reachable
wait_for_namenode() {
    echo "Waiting for Active NameNode (nn1) to become reachable..."
    until hdfs haadmin -getServiceState nn1 >/dev/null 2>&1; do
        sleep 5
    done
    echo "Active NameNode is reachable."
}

# Ensure required HDFS directories exist
prepare_hdfs_dirs() {
    local type=$1
    if [ "$type" = "namenode" ]; then
        mkdir -p /opt/hadoop/dfs/name
        chmod 700 /opt/hadoop/dfs/name
    elif [ "$type" = "datanode" ]; then
        mkdir -p /opt/hadoop/dfs/data
        chmod 700 /opt/hadoop/dfs/data
        # Remove old storage if clusterID mismatch
        if [ -f "/opt/hadoop/dfs/data/current/VERSION" ]; then
            echo "Cleaning old DataNode storage..."
            rm -rf /opt/hadoop/dfs/data/*
        fi
    fi
    mkdir -p /opt/hadoop/logs
    chmod 755 /opt/hadoop/logs
}

case $HOST in
  node01)
    # Active NameNode + JournalNode
    start_if_not_running "JournalNode" "hdfs --daemon start journalnode"
    sleep 5

    prepare_hdfs_dirs namenode

    if [ ! -d "/opt/hadoop/dfs/name/current" ] || [ -z "$(ls -A /opt/hadoop/dfs/name/current 2>/dev/null)" ]; then
        echo "Formatting NameNode..."
        hdfs namenode -format -force
    fi

    start_if_not_running "NameNode" "hdfs --daemon start namenode"
    sleep 10

    # Format ZKFC only if not done yet
    if ! hdfs zkfc -formatZK -nonInteractive 2>&1 | grep -q "already formatted"; then
        echo "ZKFC formatted."
    fi
    start_if_not_running "DFSZKFailoverController" "hdfs --daemon start zkfc"

    start_if_not_running "ResourceManager" "yarn --daemon start resourcemanager"
    ;;

  node02)
    # Standby NameNode + JournalNode
    start_if_not_running "JournalNode" "hdfs --daemon start journalnode"
    sleep 5

    wait_for_namenode
    prepare_hdfs_dirs namenode

    if [ ! -d "/opt/hadoop/dfs/name/current" ] || [ -z "$(ls -A /opt/hadoop/dfs/name/current 2>/dev/null)" ]; then
        echo "Bootstrapping Standby NameNode..."
        hdfs namenode -bootstrapStandby
    fi

    start_if_not_running "NameNode" "hdfs --daemon start namenode"
    sleep 10

    start_if_not_running "DFSZKFailoverController" "hdfs --daemon start zkfc"
    start_if_not_running "ResourceManager" "yarn --daemon start resourcemanager"
    ;;

  node03)
    # JournalNode + DataNode
    start_if_not_running "JournalNode" "hdfs --daemon start journalnode"
    sleep 5

    wait_for_namenode
    prepare_hdfs_dirs datanode
    start_if_not_running "DataNode" "hdfs --daemon start datanode"
    sleep 5

    start_if_not_running "NodeManager" "yarn --daemon start nodemanager"
    ;;

  node04)
    # ZooKeeper + DataNode
    echo "Starting ZooKeeper..."
    service zookeeper start
    sleep 5

    wait_for_namenode
    prepare_hdfs_dirs datanode
    start_if_not_running "DataNode" "hdfs --daemon start datanode"
    sleep 5
    start_if_not_running "NodeManager" "yarn --daemon start nodemanager"
    ;;

  node05)
    # DataNode + NodeManager
    wait_for_namenode
    prepare_hdfs_dirs datanode
    start_if_not_running "DataNode" "hdfs --daemon start datanode"
    sleep 5
    start_if_not_running "NodeManager" "yarn --daemon start nodemanager"
    ;;

  *)
    echo "Unknown host role"
    ;;
esac

echo "All services started on $HOST"

# Keep container alive
tail -f /dev/null