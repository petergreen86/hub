#!/bin/bash
# one step deployment for hub with either the defaul pgsql container or an external db
# assumptions:
# 1. swarm is already running
# 2. the external database has already been initialised
# 3. your secrets exist in /opt/secrets

HUB_RELEASE_VERSION=2019.6.1
DESTINATION_DIR="/opt/"
WORKING_DIR="/opt/hub-${HUB_RELEASE_VERSION}"
HUB_SOURCE="https://github.com/blackducksoftware/hub/archive/v${HUB_RELEASE_VERSION}.tar.gz"
DATABASE_HOST=[REPLACE_ME]
DATABASE_PORT=[REPLACE_ME]

echo "Hub one step installer for $HUB_RELEASE_VERSION"

getHub() {

    HUB_FILENAME=${HUB_FILENAME:-$(awk -F "/" '{print $NF}' <<< $HUB_SOURCE)}
    HUB_DESTINATION="${DESTINATION_DIR}/${HUB_FILENAME}"

    #check if we've already pulled the file

    if [ -f "$HUB_DESTINATION" ]; then
    echo "we already have the binary at ${HUB_DESTINATION}"
    else
    echo "getting ${HUB_SOURCE} from GitHub"

    curlReturn=$(curl --silent -w "%{http_code}" -L -o $HUB_DESTINATION "${HUB_SOURCE}")
    if [ 200 -eq $curlReturn ]; then
      echo "saved ${HUB_SOURCE} to ${DESTINATION_DIR}"
    else
      echo "The curl response was ${curlReturn}, which is not successful - please check your configuration and environment."
      exit -1
    fi
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

createSecrets(){
    # check if secrets files exist, if they do, create docker secret
    # if not, exit
    if [ ! \( -f "/opt/secrets/POSTGRES_USER_PASSWORD_FILE" -a -f "/opt/secrets/POSTGRES_ADMIN_PASSWORD_FILE" \) ] ; then 
      echo "One of the secrets does not exist - EXITING"
      exit -1
    else
      echo "secrets files found, let's create them"
      docker secret create hub_POSTGRES_USER_PASSWORD_FILE /opt/secrets/POSTGRES_USER_PASSWORD_FILE
      docker secret create hub_POSTGRES_ADMIN_PASSWORD_FILE /opt/secrets/POSTGRES_ADMIN_PASSWORD_FILE
    fi

}

pullExternalLocalOverrides(){
    # backup original local overrides 
    if [ -f docker-compose.local-overrides.yml ] ; then
        mv docker-compose.local-overrides.yml docker-compose.local-overrides.bak
    fi
    
    # pull custom local overrides with external db refs
    curlReturn=$(curl --silent -w "%{http_code}" -L -o "${WORKING_DIR}/docker-swarm/docker-compose.local-overrides.yml" "https://raw.githubusercontent.com/petergreen86/hub/master/docker-compose.local-overrides.yml")
    if [ 200 -eq $curlReturn ]; then
      echo "saved docker-compose.local-overrides.yml for external db"
    else
      echo "The curl response was ${curlReturn}, which is not successful - please check your configuration and environment."
      exit -1
    fi

    #update database variables
    echo "replacing database host and port"
    cd $WORKING_DIR/docker-swarm/
    sed -i "s/HUB_POSTGRES_HOST=/HUB_POSTGRES_HOST=$DATABASE_HOST/g" "hub-postgres.env"
    sed -i "s/HUB_POSTGRES_PORT=/HUB_POSTGRES_PORT=$DATABASE_PORT/g" "hub-postgres.env"

}

deployHubExternal(){
    docker stack deploy -c docker-compose.externaldb.yml -c docker-compose.local-overrides.yml hub
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

if [ $# -eq 0 ]
then
        echo "Missing options!"
        echo "(run $0 -h for help)"
        echo ""
        exit 0
fi

while getopts "seh" OPTION; do
        case $OPTION in

                s)
                        #standard
                        checkWrite
                        getHub
                        extractHub
                        deployHub
                        ;;

                e)
                        #external
                        checkWrite
                        getHub
                        extractHub
                        createSecrets
                        pullExternalLocalOverrides
                        deployHubExternal
                        ;;
                h)
                        #help
                        echo "usage:"
                        echo "hubDeploy.sh -s deploys hub with internal postgres db"
                        echo "hubDeploy.sh -e deploys hub with external database"
                        echo "hubDeploy.sh -h displays help output"
                        exit 0
                        ;;

        esac
done
