#!/bin/bash
PaperVersion="$1"
echo " "
echo "***************************************************"
echo "* Checking for plugin updates as per plugins.yaml *"
echo "***************************************************"
echo " "
key=0

while true; do
    pluginKey=$(yq -r ".plugins | keys[$key]" extras/plugins.yaml)
    if [[ "$pluginKey" = "null" ]]; then
        break
    fi

    # Set parameters (corrected typo from 'peramiters')
    pluginPlatform=$(yq -r ".plugins.\"$pluginKey\".platform" extras/plugins.yaml)
    pluginName=$(yq -r ".plugins.\"$pluginKey\".name" extras/plugins.yaml)
    pluginVersion=$(yq -r ".plugins.\"$pluginKey\".version" extras/plugins.yaml)
    
    # Plugin from Hanger.io
    if [[ "$pluginPlatform" == "hanger" ]]; then
        echo "Checking plugin: $pluginName from $pluginPlatform"
        curl -L --no-progress-meter "https://hangar.papermc.io/api/v1/projects/$pluginName/versions" \
            | jq -r '[.result.[] | select(.channel.name=="Release") | {name: .downloads.PAPER.fileInfo.name, version: .name, url: .downloads.PAPER.downloadUrl, externalUrl: .downloads.PAPER.externalUrl, jar: .downloads.PAPER.fileInfo.name, supportedVersions: .platformDependencies.PAPER}]' > logs/${pluginName}CURL.txt
        pluginJar=$(yq -r ".plugins.\"$pluginKey\".jar" extras/plugins.yaml)
        # Check for "null" or empty
        if [[ "$pluginJar" == "" || "$pluginJar" == "null" ]]; then
            pluginJar=$(jq -r '.[0].jar' logs/${pluginName}CURL.txt)
            yq -i ".plugins.\"$pluginKey\".jar = \"$pluginJar\"" extras/plugins.yaml
        fi
        # Find the current version
        currentPluginFile=$(find plugins -maxdepth 1 -name "${pluginJar}" -print -quit 2>/dev/null)
        if [[ -z "$currentPluginFile" ]]; then
            currentPluginVersion="NOT_INSTALLED"
        else
            currentPluginVersion="$currentPluginFile"
        fi

        # Ensure pluginVersion matches is updated if "latest" was specified
        if [[ "$pluginVersion" == "latest" ]]; then
            pluginVersion=$(jq -r '.[0].version' logs/${pluginName}CURL.txt)
        else
            i=$(jq -r --arg pv "$pluginVersion" '[.[] | select(.version==$pv)]' logs/${pluginName}CURL.txt)
            echo $i > logs/${pluginName}CURL.txt
        fi
        matchGameVersion=$(jq -r --arg pv "$PaperVersion" '[.[0].supportedVersions] | any(index($pv))' logs/${pluginName}CURL.txt)
        oldPluginVersion=$(yq -r ".plugins.\"$pluginKey\".jar" extras/plugins.yaml)
        if [[ $(jq -r '.' logs/${pluginName}CURL.txt) == "[]" ]]; then
            echo "Among the recent releases, there is no stable versions."
            echo -e "You can view it at \033[42mhttps://hangar.papermc.io/$pluginName/versions?channel=Release&platform=PAPER\033[0m"
            echo -e "Skipping this plugin.\n"
        elif [[ "$pluginVersion" == "" ]]; then
            echo "Among the recent releases, there is no stable versions."
            echo -e "You can view it at \033[42mhttps://hangar.papermc.io/$pluginName/versions?channel=Release&platform=PAPER\033[0m"
            echo -e "Skipping this plugin.\n"
        elif [[ "$matchGameVersion" != "true" ]]; then
            pluginCreator=$(yq -r ".plugins.\"$pluginKey\".creator" extras/plugins.yaml)
            echo "No matching game versions for this plugin were found for PaperVersion $PaperVersion."
            echo -e "You can view it at \033[42mhttps://hangar.papermc.io/$pluginCreator/$pluginName/versions?channel=Release&platform=PAPER\033[0m"
            echo -e "Skipping this plugin.\n"
        else
            # Extract version number from filename
            newPluginVersionNum=$(echo "$pluginJar" | grep -oP '(\d+\.\d+(\.\d+)*(-\w+)*)\.jar$' | sed 's/\.jar$//')
            currentPluginVersionNum=""
            if [[ "$currentPluginVersion" != "NOT_INSTALLED" ]]; then
                currentPluginVersionNum=$(echo "$currentPluginVersion" | grep -oP '(\d+\.\d+(\.\d+)*(-\w+)*)\.jar$' | sed 's/\.jar$//')
            fi

            needs_update="false"
            if [[ "$currentPluginVersion" == "NOT_INSTALLED" ]]; then
                needs_update="true"
            elif [[ -n "$newPluginVersionNum" && -n "$currentPluginVersionNum" ]]; then
                if printf '%s\n' "$currentPluginVersionNum" "$newPluginVersionNum" | sort -V -C; then
                    echo "No new updates found."
                    echo -e "Skipping this plugin.\n"
                elif [[ "$newPluginVersionNum" == "$currentPluginVersionNum" ]]; then
                    echo "No new updates found."
                    echo -e "Skipping this plugin.\n"
                else
                    needs_update="true"
                fi
            else
                # Fallback to simple string comparison if version numbers couldn't be parsed
                if [[ "plugins/$pluginJar" > "$currentPluginVersion" ]]; then
                    needs_update="true"
                fi
            fi

            if [[ "$needs_update" == "true" ]]; then
                echo "Grabbing $pluginName..."
                # Check for external URLs and download
                pluginExternal=$(jq -r '.[0].externalUrl' logs/${pluginName}CURL.txt)
                if [[ "$pluginExternal" == "null" || -z "$pluginExternal" ]]; then
                    hangerURL=$(jq -r '.[0].url' logs/${pluginName}CURL.txt)
                    rm -f plugins/"$pluginName"-*.jar
                    wget -nv -O "plugins/$pluginJar" "$hangerURL"
                    echo "$(date +%Y.%m.%d-%H.%M.%S): Updated $pluginName from version $oldPluginVersion to $pluginJar" >> logs/newUpdates.txt
                else
                    echo "Unfortunately, this plugin requires an external URL to download from."
                    echo "Please download the plugin from '$pluginExternal' and place it in the plugins folder."
                    echo -e "Skipping this plugin.\n"
                fi
            fi
        fi

    # Plugin from Modrinth
    elif [[ "$pluginPlatform" == "modrinth" ]]; then
        echo "Checking plugin: $pluginName from $pluginPlatform"
        curl -L --no-progress-meter "https://api.modrinth.com/v2/project/$pluginName/version" \
            | jq -r '[.[] | select(.loaders[]=="paper") | select(.version_type=="release") | {name: .name, version: .version_number, url: .files[].url, jar: .files[].filename, supportedVersions: .game_versions}] | sort_by(.version) | reverse' > logs/${pluginName}CURL.txt
        pluginJar=$(yq -r ".plugins.\"$pluginKey\".jar" extras/plugins.yaml)
        # Check for "null" or empty
        if [[ "$pluginJar" == "" || "$pluginJar" == "null" ]]; then
            pluginJar=$(jq -r '.[0].jar' logs/${pluginName}CURL.txt)
            yq -i ".plugins.\"$pluginKey\".jar = \"$pluginJar\"" extras/plugins.yaml
        fi
        # Find the current version
        currentPluginFile=$(find plugins -maxdepth 1 -name "${pluginJar}" -print -quit 2>/dev/null)
        if [[ -z "$currentPluginFile" ]]; then
            currentPluginVersion="NOT_INSTALLED"
        else
            currentPluginVersion="$currentPluginFile"
        fi

        # Ensure pluginVersion matches is updated if "latest" was specified
        if [[ "$pluginVersion" == "latest" ]]; then
            pluginVersion=$(jq -r '.[0].version' logs/${pluginName}CURL.txt)
        else
            i=$(jq -r --arg pv "$pluginVersion" '[.[] | select(.version==$pv)]' logs/${pluginName}CURL.txt)
            echo $i > logs/${pluginName}CURL.txt
        fi
        matchGameVersion=$(jq -r --arg pv "$PaperVersion" '[.[0].supportedVersions] | any(index($pv))' logs/${pluginName}CURL.txt)
        oldPluginVersion=$(yq -r ".plugins.\"$pluginKey\".jar" extras/plugins.yaml)
        if [[ $(jq -r '.' logs/${pluginName}CURL.txt) == "[]" ]]; then
            echo "Among the recent releases, there is no stable versions."
            echo -e "You can view it at \033[42mhttps://modrinth.com/plugin/$pluginName/versions?l=paper&c=release\033[0m"
            echo -e "Skipping this plugin.\n"
        elif [[ "$pluginVersion" == "" ]]; then
            echo "Among the recent releases, there is no stable versions."
            echo -e "You can view it at \033[42mhttps://modrinth.com/plugin/$pluginName/versions?l=paper&c=release\033[0m"
            echo -e "Skipping this plugin.\n"
        elif [[ "$matchGameVersion" != "true" ]]; then
            echo "No matching game versions for this plugin were found for PaperVersion $PaperVersion."
            echo -e "You can view it at \033[42mhttps://modrinth.com/plugin/$pluginName/versions?l=paper&c=release\033[0m"
            echo -e "Skipping this plugin.\n"
        else
            # Extract version number from filename
            newPluginVersionNum=$(echo "$pluginJar" | grep -oP '(\d+\.\d+(\.\d+)*(-\w+)*)\.jar$' | sed 's/\.jar$//')
            currentPluginVersionNum=""
            if [[ "$currentPluginVersion" != "NOT_INSTALLED" ]]; then
                currentPluginVersionNum=$(echo "$currentPluginVersion" | grep -oP '(\d+\.\d+(\.\d+)*(-\w+)*)\.jar$' | sed 's/\.jar$//')
            fi

            needs_update="false"
            if [[ "$currentPluginVersion" == "NOT_INSTALLED" ]]; then
                needs_update="true"
            elif [[ -n "$newPluginVersionNum" && -n "$currentPluginVersionNum" ]]; then
                if printf '%s\n' "$currentPluginVersionNum" "$newPluginVersionNum" | sort -V -C; then
                    echo "No new updates found."
                    echo -e "Skipping this plugin.\n"
                elif [[ "$newPluginVersionNum" == "$currentPluginVersionNum" ]]; then
                    echo "No new updates found."
                    echo -e "Skipping this plugin.\n"
                else
                    needs_update="true"
                fi
            else
                # Fallback to simple string comparison if version numbers couldn't be parsed
                if [[ "plugins/$pluginJar" > "$currentPluginVersion" ]]; then
                    needs_update="true"
                fi
            fi

            if [[ "$needs_update" == "true" ]]; then
                echo "Grabbing $pluginName..."
                # Check for external URLs and download
                pluginExternal=$(jq -r '.[0].externalUrl' logs/${pluginName}CURL.txt)
                if [[ "$pluginExternal" == "null" || -z "$pluginExternal" ]]; then
                    modrinthURL=$(jq -r '.[0].url' logs/${pluginName}CURL.txt)
                    rm -f plugins/"$pluginName"-*.jar
                    wget -nv -O "plugins/$pluginJar" "$modrinthURL"
                    echo "$(date +%Y.%m.%d-%H.%M.%S): Updated $pluginName from version $oldPluginVersion to $pluginJar" >> logs/newUpdates.txt
                else
                    echo "Unfortunately, this plugin requires an external URL to download from."
                    echo "Please download the plugin from '$pluginExternal' and place it in the plugins folder."
                    echo -e "Skipping this plugin.\n"
                fi
            fi
        fi
    fi
    echo " "
    ((key++))
done
echo -e "Plugin update check completed.\n"
