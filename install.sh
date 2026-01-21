#!/bin/bash

usage () {
    echo -e "Usage: install.sh [SERVER]\n"
    echo -e "Installs the configuration to SERVER, where a server is the name of an OpenMRS SDK instance at path '~/openmrs/[SERVER]'\n"
    echo -e "Also first installs the parent config if it is at ../openmrs-config-pihemr or ../config-pihemr.\n"
    echo -e "Example: ./install.sh mirebalais\n"
}

mvn_install() {
  mvn clean install
}

if [ $# -eq 0 ]; then
    echo -e "Please provide the name of the server to install to as a command line argument.\n"
    usage
    exit 1
fi

# if there's a "config-pihemr" or "openmrs-config-pihemr" directory at the same level as this project,
# run the install for it

if [[ -d '../config-pihemr' ]]; then
    (cd ../config-pihemr && mvn_install)
elif [[ -d '../openmrs-config-pihemr' ]]; then
    (cd ../openmrs-config-pihemr && mvn_install)
else
  echo "Unable to find PIH-EMR config, skipping building it"
fi

mvn clean compile -pl '!content' -DserverId=$1
