#!/bin/bash

### PaperMConBedrock server start script
### made by octoturnip
### https://github.com/octoTurnip
### Version: 2025.07.14

# Check for directory function
check-dir() {
    mkdir -p "$1"
}

# Check .jar function
check-jar() {
    local filePattern="$1" # e.g., "server" or "plugins/Geyser-Spigot"
    local searchDir=$(dirname "$filePattern")
    local namePattern=$(basename "$filePattern")

    # If the pattern starts with "plugins/", search in the "plugins" directory
    if [[ "$filePattern" == "plugins/"* ]]; then
         searchDir="plugins"
         namePattern="${namePattern}" # No change, it's just the basename
    else
        searchDir="." # Search in current directory (where server.jar is)
        namePattern="$filePattern" # Pattern is just "server"
    fi

    # Adjust the search for the actual file
    if ! find "$searchDir" -maxdepth 1 -name "${namePattern}-*.jar" -print -quit | grep -q .; then
        FirstRun="YES"
        # If no existing JAR found. Setting FirstRun to YES.
    fi
}

# Check if minecraft directory exists
check-dir "/minecraft"

# Check for extras
check-dir "/minecraft/extras"
if [ ! -f '/minecraft/extras/plugins.yaml' ]; then
    echo "Moving plugins.yaml to /minecraft/extras/"
    cp /scripts/plugins.yaml /minecraft/extras/plugins.yaml
fi

# Make Minecraft user or User inputted
if [ "$(id -u)" = '0' ]; then
    # Check if user already exists before adding
    if ! id -u "$namedUser" >/dev/null 2>&1; then
        useradd -r -s /bin/bash "$namedUser"
                chown -R "$namedUser":"$namedUser" /minecraft
        exec su "$namedUser" -c "/scripts/startServer.sh"
    fi
fi

# Check and change to the starting directory
cd /minecraft || { echo "ERROR: Failed to change directory to /minecraft. Exiting."; exit 1; }

### First run test
FirstRun="NO"
# Plugin Directory
check-dir "plugins"

# Paper jar
check-jar "server"

# Geyser jar
check-jar "plugins/Geyser-Spigot"

# Floodgate jar
check-jar "plugins/Floodgate-Spigot"

# ViaVersion jar
check-jar "plugins/ViaVersion"

# Backup Directory
check-dir "BACKUPS"

# Logs Directory
check-dir "logs"


# Create backups then rotate them
if [ "$FirstRun" = "NO" ]; then
    if [ "$BackupCount" = "0" ]; then
        echo "Skipping backup of the server, due to your wishes..."
    else
        echo "Backing up server..."
        tarArgs=(--exclude='./BACKUPS' -pczf "BACKUPS/$(date +%Y.%m.%d-%H.%M.%S).tar.gz" ./)
        tar "${tarArgs[@]}"
        # Rotate backups
        pushd BACKUPS/ || { echo "ERROR: Failed to change directory to BACKUPS. Skipping backup rotation."; }
        if [ "$?" -eq 0 ]; then # Only run if pushd was successful
            ls -1tr | head -n -"$BackupCount" | xargs -r -d '\n' rm -f -- 
            popd
        fi
    fi
fi

# Remove old logs now that they're backed up
rm -f logs/*.txt

### Display settings used (for debugging reasons)
echo " "
echo "**************************************************"
echo "      User profile of: $(whoami)"
echo "      Starting in directory path: $(pwd)"
echo "      PaperMC version: $PaperVersion"
echo "      Experimental PaperMC: $experimentalBuilds"
echo "      Geyser version: $GeyserVersion"
echo "      Floodgate version: $FloodgateVersion"
echo "      ViaVersion version: $ViaVersion"
echo "      Java port set to: $JavaPort"
echo "      Bedrock port set to: $BedrockPort"
echo "      Timezone: $TZ"
echo "**************************************************"
echo " "

### Update PaperMC, Geyser, and Floodgate if newer one is available OR was changed
# PaperMC
Current_PaperJar=$(find . -maxdepth 1 -name "server-*.jar" -print -quit 2>/dev/null)
if [[ -z "$Current_PaperJar" ]]; then
    Current_PaperVersion="NOT_INSTALLED"
else
    # Extract version from filename
    Current_PaperVersion=$(basename "$Current_PaperJar" | sed -E 's/^server-(.*)\.jar$/\1/')
fi

Current_PaperVersion="$Current_PaperVersion" yq eval -n '.paperUpdate.Current_PaperVersion = env(Current_PaperVersion)' > logs/startupVars.yaml
if [[ "$PaperVersion" == "latest" ]]; then
    PaperVersion=$(curl -s --no-progress-meter https://api.papermc.io/v2/projects/paper | jq -r '.versions[-1]')
    PaperVersion="$PaperVersion" yq -i '.paperUpdate.PaperVersion = env(PaperVersion)' logs/startupVars.yaml
fi

latestPaperBuild=$(curl -s --no-progress-meter "https://api.papermc.io/v2/projects/paper/versions/${PaperVersion}/builds" | jq -r '.builds | map(select(.channel == "default") | .build) | .[-1]')
latestPaperBuild="$latestPaperBuild" yq -i '.paperUpdate.latestPaperBuild = env(latestPaperBuild)' logs/startupVars.yaml
if [[ "$experimentalBuilds" == "on" ]]; then
    latestPaperBuild=$(curl -s --no-progress-meter "https://api.papermc.io/v2/projects/paper/versions/${PaperVersion}/builds" | jq -r '.builds | map(select(.channel == "experimental") | .build) | .[-1]')
    latestPaperBuild="$latestPaperBuild" yq -i '.paperUpdate.latestPaperBuild = env(latestPaperBuild)' logs/startupVars.yaml
fi
if [[ -z "$latestPaperBuild" || "$latestPaperBuild" == "null" ]]; then
    echo "ERROR: There are only experamental PaperMC builds for version $PaperVersion."
    echo "Please use a different version or wait for the next stable release."
    echo "Exiting..."
    exit 1
fi
Paper_NeedsUpdate="false"
Target_PaperVersion="${PaperVersion}-${latestPaperBuild}"
Target_PaperVersion="$Target_PaperVersion" yq -i '.paperUpdate.Target_PaperVersion = env(Target_PaperVersion)' logs/startupVars.yaml
if [[ "$Current_PaperVersion" == "NOT_INSTALLED" ]]; then
    Paper_NeedsUpdate="true"
elif [[ "$Current_PaperVersion" == "$Target_PaperVersion" ]]; then
    echo -e "\nNo update needed for PaperMC."
elif [[ -n "$Current_PaperVersion" && -n "$Target_PaperVersion" ]]; then
    if printf '%s\n' "$Current_PaperVersion" "$Target_PaperVersion" | sort -V -C; then
        Paper_NeedsUpdate="true"
    fi
fi
Paper_NeedsUpdate="$Paper_NeedsUpdate" yq -i '.paperUpdate.Paper_NeedsUpdate = env(Paper_NeedsUpdate)' logs/startupVars.yaml
if [[ "$Paper_NeedsUpdate" == "true" ]]; then
    echo "Updating PaperMC version..."
    jarName="paper-${PaperVersion}-${latestPaperBuild}.jar"
    jarName="$jarName" yq -i '.paperUpdate.jarName = env(jarName)' logs/startupVars.yaml
    PaperURL="https://api.papermc.io/v2/projects/paper/versions/${PaperVersion}/builds/${latestPaperBuild}/downloads/${jarName}"
    PaperURL="$PaperURL" yq -i '.paperUpdate.PaperURL = env(PaperURL)' logs/startupVars.yaml
    rm -f server-*.jar
    curl -o "server-${PaperVersion}-${latestPaperBuild}.jar" "$PaperURL"
fi


# Geyser
curl -L --no-progress-meter https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest > geyserTemp.json
Current_GeyserJar=$(find plugins -maxdepth 1 -name "Geyser-Spigot-*.jar" -print -quit 2>/dev/null)
if [[ -z "$Current_GeyserJar" ]]; then
    Current_GeyserVersion="NOT_INSTALLED"
else
    Current_GeyserVersion=$(basename "$Current_GeyserJar" | sed -E 's/^Geyser-Spigot-(.*)\.jar$/\1/')
fi
Current_GeyserVersion="$Current_GeyserVersion" yq -i '.geyserUpdate.Current_GeyserVersion = env(Current_GeyserVersion)' logs/startupVars.yaml
if [[ "$GeyserVersion" == "latest" ]]; then
    GeyserVersion=$(jq -r '.version' geyserTemp.json)
    GeyserVersion="$GeyserVersion" yq -i '.geyserUpdate.GeyserVersion = env(GeyserVersion)' logs/startupVars.yaml
fi
GeyserBuild=$(jq -r '.build' geyserTemp.json)
GeyserBuild="$GeyserBuild" yq -i '.geyserUpdate.GeyserBuild = env(GeyserBuild)' logs/startupVars.yaml

Target_GeyserVersion="${GeyserVersion}-${GeyserBuild}"
Geyser_NeedsUpdate="false"
if [[ "$Current_GeyserVersion" == "NOT_INSTALLED" ]]; then
    Geyser_NeedsUpdate="true"
elif [[ "$Current_GeyserVersion" == "$Target_GeyserVersion" ]]; then
    echo -e "\nNo update needed for Geyser."
elif [[ -n "$Current_GeyserVersion" && -n "$Target_GeyserVersion" ]]; then
    if printf '%s\n' "$Current_GeyserVersion" "$Target_GeyserVersion" | sort -V -C; then
        Geyser_NeedsUpdate="true"
    fi
fi

if [[ "$Geyser_NeedsUpdate" == "true" ]]; then
    echo "Updating Geyser..."
    GeyserURL="https://download.geysermc.org/v2/projects/geyser/versions/${GeyserVersion}/builds/$GeyserBuild/downloads/spigot"
    GeyserURL="$GeyserURL" yq -i '.geyserUpdate.GeyserURL = env(GeyserURL)' logs/startupVars.yaml
    rm -f plugins/Geyser-Spigot-*.jar
    curl -o "plugins/Geyser-Spigot-${GeyserVersion}-${GeyserBuild}.jar" "$GeyserURL"
fi
rm -f geyserTemp.json


# Floodgate
curl -L --no-progress-meter https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest > floodgateTemp.json
Current_FloodgateJar=$(find plugins -maxdepth 1 -name "Floodgate-Spigot-*.jar" -print -quit 2>/dev/null)
if [[ -z "$Current_FloodgateJar" ]]; then
    Current_FloodgateVersion="NOT_INSTALLED"
else
    Current_FloodgateVersion=$(basename "$Current_FloodgateJar" | sed -E 's/^Floodgate-Spigot-(.*)\.jar$/\1/')
fi
Current_FloodgateVersion="$Current_FloodgateVersion" yq -i '.floodgateUpdate.Current_FloodgateVersion = env(Current_FloodgateVersion)' logs/startupVars.yaml

if [[ "$FloodgateVersion" == "latest" ]]; then
    FloodgateVersion=$(jq -r '.version' floodgateTemp.json)
    FloodgateVersion="$FloodgateVersion" yq -i '.floodgateUpdate.FloodgateVersion = env(FloodgateVersion)' logs/startupVars.yaml
fi
FloodgateBuild=$(jq -r '.build' floodgateTemp.json)
FloodgateBuild="$FloodgateBuild" yq -i '.floodgateUpdate.FloodgateBuild = env(FloodgateBuild)' logs/startupVars.yaml

Target_FloodgateVersion="${FloodgateVersion}-${FloodgateBuild}"
Floodgate_NeedsUpdate="false"
if [[ "$Current_FloodgateVersion" == "NOT_INSTALLED" ]]; then
    Floodgate_NeedsUpdate="true"
elif [[ "$Current_FloodgateVersion" == "$Target_FloodgateVersion" ]]; then
    echo -e "\nNo update needed for Floodgate."
elif [[ -n "$Current_FloodgateVersion" && -n "$Target_FloodgateVersion" ]]; then
    if printf '%s\n' "$Current_FloodgateVersion" "$Target_FloodgateVersion" | sort -V -C; then
        Floodgate_NeedsUpdate="true"
    fi
fi

if [[ "$Floodgate_NeedsUpdate" == "true" ]]; then
    echo "Updating Floodgate..."
    FloodgateURL="https://download.geysermc.org/v2/projects/floodgate/versions/${FloodgateVersion}/builds/$FloodgateBuild/downloads/spigot"
    FloodgateURL="$FloodgateURL" yq -i '.floodgateUpdate.FloodgateURL = env(FloodgateURL)' logs/startupVars.yaml
    rm -f plugins/Floodgate-Spigot-*.jar
    curl -o "plugins/Floodgate-Spigot-${FloodgateVersion}-${FloodgateBuild}.jar" "$FloodgateURL"
fi
rm -f floodgateTemp.json

# ViaVersion
curl -L --no-progress-meter https://hangar.papermc.io/api/v1/projects/ViaVersion/versions > viaversionTemp.json
Current_ViaVersionJar=$(find plugins -maxdepth 1 -name "ViaVersion-*.jar" -print -quit 2>/dev/null)
if [[ -z "$Current_ViaVersionJar" ]]; then
    Current_ViaVersionVersion="NOT_INSTALLED"
else
    Current_ViaVersionVersion=$(basename "$Current_ViaVersionJar" | sed -E 's/^ViaVersion-(.*)\.jar$/\1/')
fi
Current_ViaVersionVersion="$Current_ViaVersionVersion" yq -i '.viaversionUpdate.Current_ViaVersionVersion = env(Current_ViaVersionVersion)' logs/startupVars.yaml

if [[ "$ViaVersion" == "latest" ]]; then
    ViaVersion=$(jq -r '.result.[].id' viaversionTemp.json | sort -V | tail -1)
    ViaVersion="$ViaVersion" yq -i '.viaversionUpdate.ViaVersion = env(ViaVersion)' logs/startupVars.yaml
fi
ViaVersionBuild=$(jq -r '.result.[].name' viaversionTemp.json | sort -V | tail -1)
ViaVersionBuild="$ViaVersionBuild" yq -i '.viaversionUpdate.ViaVersionBuild = env(ViaVersionBuild)' logs/startupVars.yaml

Target_ViaVersionVersion="${ViaVersionBuild}"
ViaVersion_NeedsUpdate="false"
if [[ "$Current_ViaVersionVersion" == "NOT_INSTALLED" ]]; then
    ViaVersion_NeedsUpdate="true"
elif [[ "$Current_ViaVersionVersion" == "$Target_ViaVersionVersion" ]]; then
    echo -e "\nNo update needed for ViaVersion."
elif [[ -n "$Current_ViaVersionVersion" && -n "$Target_ViaVersionVersion" ]]; then
    if printf '%s\n' "$Current_ViaVersionVersion" "$Target_ViaVersionVersion" | sort -V -C; then
        ViaVersion_NeedsUpdate="true"
    fi
fi

if [[ "$ViaVersion_NeedsUpdate" == "true" ]]; then
    echo "Updating ViaVersion..."
    ViaVersionURL="https://hangar.papermc.io/api/v1/projects/ViaVersion/versions/${ViaVersion}/PAPER/download"
    ViaVersionURL="$ViaVersionURL" yq -i '.viaversionUpdate.ViaVersionURL = env(ViaVersionURL)' logs/startupVars.yaml
    rm -f plugins/ViaVersion-*.jar
    wget -nv -O "plugins/ViaVersion-${ViaVersionBuild}.jar" "$ViaVersionURL"
fi
rm -f viaversionTemp.json
#####

# If this is the first run
if [[ "$FirstRun" == "YES" ]]; then
    echo -e "\nBeginning the first run!"
    echo "BE SURE TO ACCEPT THE EULA"
    echo -e "Then re-start the server...\n"
    exec java -Xms4096M -Xmx4096M -jar "server-${PaperVersion}-${latestPaperBuild}.jar" nogui
fi

# Match the Java port in server.properties to the ones you set
if [[ -f server.properties ]]; then
    sed -i "/server-port=/c\server-port=$JavaPort" server.properties
    sed -i "/query\.port=/c\query\.port=$JavaPort" server.properties
else
    echo -e "\033[41mWARNING:\033[0m server.properties not found. Skipping port configuration."
fi

# Match the Bedrock and Java port in Geyser config to what you set
if [ -e "plugins/Geyser-Spigot/config.yml" ]; then
    sed -i "s|  port: [0-9]*|  port: $BedrockPort|1" plugins/Geyser-Spigot/config.yml
    sed -i "s|  port: [0-9]*|  port: $JavaPort|2" plugins/Geyser-Spigot/config.yml
else
    echo -e "\033[41mWARNING:\033[0m plugins/Geyser-Spigot/config.yml not found. Skipping Geyser port configuration."
fi

# Auto-Plugin Updater
if [ "$autoUpdate" = "on" ]; then
    bash /scripts/pluginUpdater.sh "$PaperVersion"
fi
###

# If you wanted to run your own custom script, this next line is for that.
# Make sure to place your file in the "/minecraft/extras" directory and name it "customScript.sh"
if [ -f "/minecraft/extras/customScript.sh" ]; then
    bash /minecraft/extras/customScript.sh
fi

### Start the server
echo " "
echo "**************************************************"
echo "*                                                *"
echo "*         NOW starting PaperMC server            *"
echo "*                                                *"
echo "**************************************************"
echo " "

JAVA_MAX_MEM="${MaxMemory:-4096M}"
JAVA_MIN_MEM="${MinMemory:-1024M}"

# Ensure the JAR file exists before attempting to run it
SERVER_JAR_PATH="server-${PaperVersion}-${latestPaperBuild}.jar"
if [[ ! -f "$SERVER_JAR_PATH" ]]; then
    echo -e "\033[41mCRITICAL ERROR:\033[0m Server JAR file $SERVER_JAR_PATH not found! Cannot start server."
    exit 1
fi

echo "Starting Java server with -Xms${JAVA_MIN_MEM} -Xmx${JAVA_MAX_MEM}"
exec java -Xms"${JAVA_MIN_MEM}" -Xmx"${JAVA_MAX_MEM}" -jar "$SERVER_JAR_PATH" nogui

# Exit container (this will only be used if the 'exec' fails
exit 0