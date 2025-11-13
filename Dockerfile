### PaperMConBedrock
### PaperMC + Geyser + Floodgate + ViaVersion
### Made by octoturnip
### https://github.com/octoTurnip

# Ubuntu rolling version
FROM --platform=linux/amd64 ubuntu:rolling

# Fetch dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wget \
    jq \
    binfmt-support \
    tzdata \
    sudo \
    curl \
    ca-certificates \
    apt-transport-https \
    gnupg \
    bash
# Install yq for YAML processing
RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq

# Recommended Java per the PaperMC website
RUN wget -O - https://apt.corretto.aws/corretto.key | sudo gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | sudo tee /etc/apt/sources.list.d/corretto.list
RUN apt-get update && apt-get install -y \
    java-21-amazon-corretto-jdk \
    libxi6 \
    libxtst6 \
    libxrender1 \
    && rm -rf /var/cache/apt/*

# Use other username besides 'minecraft'
ENV namedUser="minecraft"

# Set port variables
ENV JavaPort=25565
ENV BedrockPort=19132

# Set a maximum memory amount
ENV MaxMemory="4096M"

# Set Paper Version
ENV PaperVersion="latest"
# Set Paper Experimental Builds finder
ENV experimentalBuilds="off"
# Set Geyser Version
ENV GeyserVersion="latest"
# Set Floodgate Version
ENV FloodgateVersion="latest"
# Set ViaVersion... Version
ENV ViaVersion="latest"

# Set timezone - OPTIONAL
ENV TZ="America/Los_Angeles"

# Rolling backup amount
ENV BackupCount=10

# Auto-Updater on/off
ENV autoUpdate="off"

# Expose ports
EXPOSE 25565/tcp
EXPOSE 19132/tcp
EXPOSE 19132/udp

# Script management
RUN mkdir /scripts
COPY *.sh /scripts
COPY plugins.yaml /scripts
RUN chmod -R +x /scripts/*.sh


# Set entrypoint and start the server script
ENTRYPOINT ["/bin/bash", "/scripts/startServer.sh"]