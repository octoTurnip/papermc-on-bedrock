# Create a Minecraft server running PaperMC in a Docker container.
Also pre-packed with Geyser + Floodgate + ViaVersion.

GitHib: https://github.com/octoturnip/

Docker: https://hub.docker.com/u/octoturnip/

Inspiration from:
- [TheRemote](https://github.com/TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate)
- [AriRexouium](https://github.com/AriRexouium/papermc-docker)

## QUICK START

```
docker run -it --rm -v /your/path/here:/minecraft -p 25565:25565 -p 19132:19132/udp -p 19132:19132 octoturnip/papermc-on-bedrock
```

## Why make another?

Originally I just wanted to try and make something of my own with features I liked.
But I like what I have made for myself and feel like sharing with the rest of you!

## What are the features you can expect?

- Plug & Play
    - You can literally just use the quickstart and everything will always be current and updated.
    - Or set to any version you'd like with just a couple keystrokes.
- Customization
    - This PaperMC server comes packaged with Geyser, Floodgate, and ViaVersion.
    - If you want the most up to date plugin (or paper) with a specific version, you can input it into the Docker Compose file.
    - **(NEW)** Add your own script file that will be launched along with the startup script!
- Backups
    - Every time you start the server it creates a backup.
    - It also rolls over the last one, meaning if you go over the default amount of 10, the 1st one will be deleted to make room for the new one.
- **(NEW)** Automatic plugin updater/fetcher
    - Edit the `plugins.yaml` file in the extras folder to keep your plugins up to date.
    - Supports plugins from: Hanger.io and Modrinth. *(more sites planned later)*

# SETUP

Full compose.yml entry, explanations of each line, and recommended compose.yml entry.

## Full Compose entry (with all the defaults)

```yaml
  minecraft:
    image: 'octoturnip/papermc-on-bedrock'
    stdin_open: true
    tty: true
    volumes:
        - '/your/path/here:/minecraft'
    ports:
        - '25565:25565'
        - '19132:19132/udp'
        - '19132:19132'
    environment:
        - namedUser=minecraft
        - JavaPort=25565
        - BedrockPort=19132
        - MaxMemory=4096M
        - PaperVersion=latest
        - GeyserVersion=latest
        - FloodgateVersion=latest
        - ViaVersion=latest
        - TZ=America/Los_Angeles
        - BackupCount=10
        - autoUpdate=off
    container_name: minecraft
```

## Volumes

`/your/path/here:/minecraft`

`/your/path/here` path to where you want the server files to save on your server

`/minecraft` **required**

## Ports

You won't need to change these unless you change the ports in the 'environment' section.

`25565:25565` The port for Java clients.

`19132:19132` 'tcp/udp' The port for Bedrock clients. It is needed to have bot TCP (default) and UDP listed in the port section.

## Variables

All of the defaults can be changes to meet your needs and the startup script will update the downloaded config files: 

| Variable | Default | Description |
|:-:|:-:|:-:|
| `namedUser` | `minecraft` | It is not recommended to run the server as root. You can change to what you like. |
| `JavaPort` | `25565` | Port Java clients use connect to the server. |
| `BedrockPort` | `19132` | Port Bedrock clients use connect to the server. |
| `MaxMemory` | *empty* | Unless you change this, the server will start with recommended memory allocation of 4096Mb as per the [Paper website](https://docs.papermc.io/misc/tools/start-script-gen). |
| `PaperVersion` | `latest` | Always downloads and updates to the latest version of Paperclip. |
| `GeyserVersion` | `latest` | Always downloads and updates to the latest version of Geyser. |
| `FloodgateVersion` | `latest` | Always downloads and updates to the latest version of Floodgate. |
| `ViaVersion` | `latest` | Always downloads and updates to the latest version of ViaVersion. |
| `TZ` | `America/Los_Angeles` | Use [this link](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) to find a time zone that is right for you. |
| `BackupCount` | `10` | Ammount of backup files you want to keep. Created at every startup! |
| `autoUpdate` | `off` | Controlls weather or not you would like to keep your plugins automatically up to date. |

# Recommended setup for Minecraft version 1.21.7

```yaml
  minecraft:
    image: 'octoturnip/papermc-on-bedrock'
    stdin_open: true
    tty: true
    volumes:
        - '/your/path/here:/minecraft'
    ports:
        - '25565:25565'
        - '19132:19132/udp'
        - '19132:19132'
    environment:
        - PaperVersion=1.21.7
        - autoUpdate=on
    container_name: minecraft
```

# Plugin Auto Updater
I'm happy to bring you with an exciting new feature here! in the docker variables, make sure to set: `autoUpdate=on`.
In your `/minecraft` folder there will be a new folder called "extras" which will have an example file `plugins.yaml`.
Here is how it is layed out:
```yaml
plugins:
  essensials: 
    platform: hanger
    creator: EssentialsX
    name: Essentials
    jar: 
    version: latest
  chunky: 
    platform: hanger
    creator: pop4959
    name: Chunky
    jar: 
    version: 1.4.40
  voicechat:
    platform: modrinth
    creator: 
    name: simple-voice-chat
    jar: 
    version: latest
```

## Break it down:

`myName:` | A quick reference to what this plugin is called.
  - example: `essensials` or `chunky`

`platform:` | Where is this plugin is from? 

options: 
  - `hanger`
  - `modrinth`

`creator:` | Required for hanger.io plugins

`name:` | The plugins name on the website

`jar:` | This just gets filled in by the script

`version:` | Use `latest` to always keep it up to date, or pick a specific plugin version


### How to find the information you need:

- Example Hanger.io URL:
  - 'https://hangar.papermc.io/pop4959/Chunky'
  - `creator` = pop4959
  - `name` = Chunky
- Example Modrinth URL:
  - 'https://modrinth.com/plugin/simple-voice-chat'
  - `name` = simple-voice-chat


## Quick Notes

- I did not add `restart: unless-stopped` to my "compose.yml" but you can add it if you'd like.
- Remember: it is **NOT RECOMMENDED** to have the (Paper/Geyser/Floodgate)Version set to "latest". It is just there if you really don't care and want to get straight into playing with friends/family out of the box. Since the Docker image keeps everything updated, plugins or settings may not work anymore unless you're paying attention. 
- In the "Recommended setup" section, you can technically just have the "PaperVersion" set and nothing else. As of right now, all Geyser/Floodgate plugins work with every Minecraft version since 1.8.
- If you need to do something else in the terminal but don't want to shut the server down, simply use `control+P` followed by `control+Q`
    - To reattach the container, type the following command: `docker attach minecraft`
- **For the Auto Plugin Updater, if there is an external link required to download that plugin, it will fail. Only downloads from the sites will work.**

# History of Changes and Updates

Changelog and Updates to the repository are as follows:

## July 18th, 2025

- Yay! 1.21.7 is out. (as of writing this 1.21.8 just released)
- re-worked the startServer.sh to include
  - functions
  - less API calls
  - cleanup & better error handeling
- added pluginUpdater.sh
- added plugins.yaml (as a reference)
- added yq command to the Dockerfile

## March 3rd, 2025

- Polished up the 'README.md'
- Included "stdin_open: true" & "tty: true" in the compose.yml examples because I forgot to include them originally...
- Fixed typos in 
    - the compose.yml that would not make it run as intended
    - the Dockerfile
    - startServer.sh

## February 23nd, 2025

*Initial release*
