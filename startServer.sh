#!/bin/bash

### PaperMConBedrock server start script
### made by octoturnip
### https://github.com/octoTurnip

# Check if directory exists
if [ ! -d '/minecraft' ]; then
    mkdir /minecraft
fi

# Make Minecraft user or User inputed
if [ "$(id -u)" = '0' ]; then
    if [ $namedUser = 'minecraft' ]; then
        useradd -r -s /bin/bash minecraft
        chown -R minecraft:minecraft /minecraft
        exec su minecraft  -c "$0 $@"
    else
        useradd -r -s /bin/bash $namedUser
        chown -R $namedUser:$namedUser /minecraft
        exec su $namedUser -c "$0 $@"
    fi
fi

# Starting directory
cd /minecraft

### First run test
FirstRun="NO"
# Plugin Directory
if [ ! -d plugins/ ]; then
    mkdir plugins
    FirstRun="YES"
    if [ ! -d plugins/ ]; then
        echo "unable to make the directory"
        exit 1
    fi
fi
# Paper jar
if [ ! -f server-*.jar ]; then
    echo "temp text" > server-0-0.jar
    FirstRun="YES"
fi
# Geyser jar
if [ ! -f plugins/Geyser-Spigot-*.jar ]; then
    echo "temp text" > plugins/Geyser-Spigot-0.0.jar
    FirstRun="YES"
fi
# Floodgate jar
if [ ! -f plugins/Floodgate-Spigot-*.jar ]; then
    echo "temp text" > plugins/Floodgate-Spigot-0.0.jar
    FirstRun="YES"
fi
# ViaVersion jar
if [ ! -f plugins/ViaVersion-*.jar ]; then
    echo "temp text" > plugins/ViaVersion-0.0.jar
    FirstRun="YES"
fi
# Backup Directory
if [ ! -d BACKUPS/ ]; then
    mkdir BACKUPS/
fi


# Create backups then rotate them
if [ "$FirstRun" = "NO" ]; then
    if [ "$BackupCount" = "0" ]; then
        echo "Skipping backup of the server, do to your wishes..."
    else
        echo "Backing up server..."
        tarArgs=(--exclude='./BACKUPS')
        tarArgs+=(-pcf BACKUPS/$(date +%m.%d.%Y.%H.%M.%S).tar.gz ./*)
        tar "${tarArgs[@]}"
        # Rotate backups
        pushd BACKUPS/
        ls -1tr | head -n -$BackupCount | xargs -d '\n' rm -f --
        popd
    fi
fi

### Display settings used (for debugging reasons)
echo " "
echo "**************************************************"
echo "      User profile of: $(whoami)"
echo "      Starting in directory path: $(pwd)"
echo "      PaperMC version: $PaperVersion"
echo "      Geyser version: $GeyserVersion"
echo "      Floodgate version: $FloodgateVersion"
echo "      ViaVersion version: $ViaVersion"
echo "      Java port set to: $JavaPort"
echo "      Bedrock port set to: $BedrockPort"
echo "      Timezone: $TZ"
echo "**************************************************"
echo " "

### Update PaperMC, Geyser, and Floodgate if newer one is avaiable OR was changed
# PaperMC
Current_PaperVersion=$(ls server-*)
if [[ "$PaperVersion" == latest ]]; then
    PaperVersion=$(curl -s --no-progress-meter https://api.papermc.io/v2/projects/paper | jq -r '.versions[-1]')
fi
LATEST_BUILD=$(curl -s --no-progress-meter https://api.papermc.io/v2/projects/paper/versions/${PaperVersion}/builds | jq -r '.builds | map(select(.channel == "default") | .build) | .[-1]')
if [[ "server-${PaperVersion}-${LATEST_BUILD}.jar" > "$Current_PaperVersion" ]]; then
    echo "Updateing PaperMC version..."
    JAR_NAME=paper-${PaperVersion}-${LATEST_BUILD}.jar
    PAPERMC_URL="https://api.papermc.io/v2/projects/paper/versions/${PaperVersion}/builds/${LATEST_BUILD}/downloads/${JAR_NAME}"
    rm server-*.jar
    curl -o server-${PaperVersion}-${LATEST_BUILD}.jar $PAPERMC_URL
fi

# Geyser
Current_GeyserVersion=$(ls plugins/Geyser-Spigot-*)
if [[ "$GeyserVersion" == latest ]]; then
    GeyserVersion=$(curl -L --no-progress-meter https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest | jq -r '.version')
fi
GEYSER_BUILD=$(curl -L --no-progress-meter https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest | jq -r '.build')
if [[ "plugins/Geyser-Spigot-${GeyserVersion}-${GEYSER_BUILD}.jar" > "$Current_GeyserVersion" ]]; then
    echo "Updateing Geyser..."
    GEYSER_URL="https://download.geysermc.org/v2/projects/geyser/versions/${GeyserVersion}/builds/$GEYSER_BUILD/downloads/spigot"
    rm plugins/Geyser-Spigot-*.jar
    curl -o plugins/Geyser-Spigot-${GeyserVersion}-${GEYSER_BUILD}.jar $GEYSER_URL
fi

# Floodgate
Current_FloodgateVersion=$(ls plugins/Floodgate-Spigot-*)
if [[ "$FloodgateVersion" == latest ]]; then
    FloodgateVersion=$(curl -L --no-progress-meter https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest | jq -r '.version')
fi
FLOODGATE_BUILD=$(curl -L --no-progress-meter https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest | jq -r '.build')
if [[ "plugins/Floodgate-Spigot-${FloodgateVersion}-${FLOODGATE_BUILD}.jar" > "$Current_FloodgateVersion" ]]; then
    echo "Updateing Floodgate..."
    FLOODGATE_URL="https://download.geysermc.org/v2/projects/floodgate/versions/${FloodgateVersion}/builds/$FLOODGATE_BUILD/downloads/spigot"
    rm plugins/Floodgate-Spigot-*.jar
    curl -o plugins/Floodgate-Spigot-${FloodgateVersion}-${FLOODGATE_BUILD}.jar $FLOODGATE_URL
fi

# ViaVersion
Current_ViaVersionVersion=$(ls plugins/ViaVersion-*)
if [[ "$ViaVersion" == latest ]]; then
    ViaVersion=$(curl -L --no-progress-meter https://hangar.papermc.io/api/v1/projects/ViaVersion/versions | jq -r '.result.[].id' | sort -un | tail -1)
fi
VIAVERSION_BUILD=$(curl -L --no-progress-meter https://hangar.papermc.io/api/v1/projects/ViaVersion/versions | jq -r '.result.[].name' | sort -un | tail -1)
if [[ "plugins/ViaVersion-${VIAVERSION_BUILD}.jar" > "$Current_ViaVersionVersion" ]]; then
    echo "Updateing ViaVersion..."
    VIAVERSION_URL="https://hangar.papermc.io/api/v1/projects/ViaVersion/versions/${ViaVersion}/PAPER/download"
    rm plugins/ViaVersion-*.jar
    wget -nv -O plugins/ViaVersion-${VIAVERSION_BUILD}.jar $VIAVERSION_URL
fi
#####

# If this is the first run
if [[ "$FirstRun" == YES ]]; then
    echo "Beginning the first run!"
    echo "BE SURE TO ACCEPT THE EULA"
    echo "Then re-start the server..."
    exec java -Xms4096M -Xmx4096M -jar server-${PaperVersion}-${LATEST_BUILD}.jar nogui
    exit 0
fi
#####

# Match the Java port in server.properties to the ones you set
sed -i "/server-port=/c\server-port=$JavaPort" server.properties
sed -i "/query\.port=/c\query\.port=$JavaPort" server.properties

# Match the Bedrock and Java port in Geyser config to what you set
if [ -e /minecraft/plugins/Geyser-Spigot/config.yml ]; then
    sed -i -z "s/  port: [0-9]*/  port: $BedrockPort/1" plugins/Geyser-Spigot/config.yml
    sed -i -z "s/  port: [0-9]*/  port: $JavaPort/2" plugins/Geyser-Spigot/config.yml
fi


### Start the server
echo " "
echo "**************************************************"
echo "*                                                *"
echo "*         NOW starting PaperMC server            *"
echo "*                                                *"
echo "**************************************************"
echo " "

if [[ -z "$MaxMemory" ]] || [[ "$MaxMemory" -le 0 ]]; then
    exec java -XX:+UnlockDiagnosticVMOptions -Xms4096M -Xmx4096M -jar server-${PaperVersion}-${LATEST_BUILD}.jar nogui
else
    exec java -XX:+UnlockDiagnosticVMOptions -Xms4096M -Xmx${MaxMemory}M -jar server-${PaperVersion}-${LATEST_BUILD}.jar
fi

# Exit container
exit 0
