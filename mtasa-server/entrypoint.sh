#!/bin/bash
set -e

# install default config if not present
if [ ! -f /mtasa/mods/deathmatch/mtaserver.conf ]; then
    mkdir -p mods/deathmatch
    wget https://linux.mtasa.com/dl/baseconfig.tar.gz
    tar -xzf baseconfig.tar.gz -C mods/deathmatch --strip-components=1
    rm baseconfig.tar.gz
fi

# install default resources if not present
if [ ! -d /mtasa/mods/deathmatch/resources ]; then
    wget https://mirror-cdn.multitheftauto.com/mtasa/resources/mtasa-resources-latest.zip
    unzip mtasa-resources-latest.zip -d mods/deathmatch/resources
    rm mtasa-resources-latest.zip
fi

# run the server
./mta-server64
