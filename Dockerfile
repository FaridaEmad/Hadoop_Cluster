FROM ubuntu:24.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies including OpenJDK 17
RUN apt update && apt install -y \
    openjdk-17-jdk \
    ssh \
    rsync \
    wget \
    pdsh \
    curl \
    nano \
    sudo \
    zookeeperd \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME for Java 17
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

# Download Hadoop 3.4.2
RUN wget https://downloads.apache.org/hadoop/common/hadoop-3.4.2/hadoop-3.4.2.tar.gz \
    && tar -xvzf hadoop-3.4.2.tar.gz \
    && mv hadoop-3.4.2 /opt/hadoop \
    && rm hadoop-3.4.2.tar.gz
    
# Set Hadoop Environment
ENV HADOOP_HOME=/opt/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

WORKDIR /root

COPY start-cluster.sh /root/start-cluster.sh
RUN chmod +x /root/start-cluster.sh