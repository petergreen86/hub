#!/bin/bash
# bare bones one step deployment
# assumes swarm is running already

HUB_RELEASE_VERSION=2019.4.2
DESTINATION_DIR="/opt/"
WORKING_DIR="/opt/hub-${HUB_RELEASE_VERSION}"
HUB_SOURCE="https://github.com/blackducksoftware/hub/archive/v${HUB_RELEASE_VERSION}.tar.gz"

echo "Hub one step installer for $HUB_RELEASE_VERSION"

run(){
    checkWrite
    getHub
    extractHub
    deployHub
}

getHub() {

    HUB_FILENAME=${HUB_FILENAME:-$(awk -F "/" '{print $NF}' <<< $HUB_SOURCE)}
    HUB_DESTINATION="${DESTINATION_DIR}/${HUB_FILENAME}"

    echo "getting ${HUB_SOURCE} from GitHub"
    curlReturn=$(curl --silent -w "%{http_code}" -L -o $HUB_DESTINATION "${HUB_SOURCE}")
    if [ 200 -eq $curlReturn ]; then
      echo "saved ${HUB_SOURCE} to ${DESTINATION_DIR}"
    else
      echo "The curl response was ${curlReturn}, which is not successful - please check your configuration and environment."
      exit -1
    fi
}

extractHub(){
    echo "extracting to $DESTINATION_DIR"
    cd $DESTINATION_DIR
    gunzip -f $HUB_FILENAME
    tar -xf v${HUB_RELEASE_VERSION}.tar

    #replace hostname
    cd $WORKING_DIR/docker-swarm/
    sed -i "s/localhost/$HOSTNAME/g" "hub-webserver.env"
}

deployHub(){
    docker stack deploy -c docker-compose.yml hub
}

checkWrite() {
if
 [ -w $DESTINATION_DIR ];
   then echo "directory is writable, ok to proceed with download";
 else
   echo "can't write to $DESTINATION_DIR, exiting!"
   exit 73
fi
}

run
