openmrs-config-ces
==============================

### Prerequistes

Some utility scripts, "install.sh" and "watch.sh", have been written to ease having to manually run mvn install
and watch commands on both this project and the "openmrs-config-pihemr" project.

However, these scripts depend on finding your "openmrs-config-pihemr" relative to this project, so they should both be 
checked out into the same directory, and the "openmrs-config-pihemr" directory should be named "openmrs-config-pihemr"
or "config-pihemr".

Example directory structure:

openmrs-config-pihemr
openmrs-config-ces

or

config-pihemr
config-ces

### Steps to deploy new changes to your local development server

Run "./install.sh [serverId]" where [serverId] is the name of the SDK server you are deploying to.  This will first build 
the config-pihemr project, then build the config-ces project, (pulling in any changes to config-pihemr),
and finally deploying the changes to the server specified by [serverId].

#### To enable watching, you run the following:

"./watch.sh [serverId]" where [serverId] is the name of the SDK server you are deploying too.  This will watch
*both* the config-pihemr and config-ces projects for changes and redeploy when there are changes.  It runs
indefinitely, so you will need to cancel it with a "Ctrl-C".


### General usage

`mvn clean compile` - Will generate your configurations into "target/openmrs-packager-config/configuration"
`mvn clean package` - Will compile as above, and generate a zip package at "target/${artifactId}-${version}.zip"

In order to facilitate deploying configurations easily into an OpenMRS SDK server, one can add an additional parameter
to either of the above commands to specify that the compiled configuration should also be copied to an existing 
OpenMRS SDK server:

`mvn clean compile -DserverId=ces` - Will compile as above, and copy the resulting configuration to `~/openmrs/ces/configuration`

If the configuration package you are building will be depended upon by another configuration package, you must "install" it
in order for the other package to be able to pick it up.

`mvn clean install` - Will compile and package as above, and install as an available dependency on your system

For more details regarding the available commands please see:
https://github.com/openmrs/openmrs-contrib-packager-maven-plugin 


### Configuring Concepts for Chiapas

1. On the concepts server (concepts.pih-emr.org), create a "Mexico MoH (Ministry of Health, or equivalent..) concept set", similar to the “[Liberia MoH diagnosis set](https://concepts.pih-emr.org/openmrs/dictionary/concept.htm?conceptId=10595)”. Create child sets, e.g. “Mexico MoH diagnosis”, “Mexico MoH Labs”, etc. Add concepts to these subsets.

2. For each concept in the source data dictionary:

    1. If there is an existing concept in the concepts server that is an exact match, add a mapping to the "Mexico MoH" vocabulary item, and a Spanish translation if required.

    2. If there is no existing concept, create it and add vocabulary mapping and translation.

    3. Add this concept to appropriate concept set.

3. In the Metadata Sharing module, create a package called "Mexico Concepts" and create a new version. See example here for “[Liberia Concepts](https://concepts.pih-emr.org/openmrs/module/metadatasharing/export/details.form?group=c0dc491e-a26e-4dee-99c4-c4dc5cb2e787)”.

4. Download the zipped package of this version.

5. Add the zip file to the PIH openmrs-module-mirebalais-metadata Github repo [here](https://github.com/PIH/openmrs-module-mirebalaismetadata/tree/master/api/src/main/resources). This will add the metadata concepts to our build pipeline.

6. The concepts should then be available companero staging server.

#### Diagnoses

Add diagnoses concept set setting here: [https://github.com/PIH/openmrs-module-pihcore/blob/master/api/src/main/java/org/openmrs/module/pihcore/deploy/bundle/mexico/MexicoMetadataBundle.java](https://github.com/PIH/openmrs-module-pihcore/blob/master/api/src/main/java/org/openmrs/module/pihcore/deploy/bundle/mexico/MexicoMetadataBundle.java)

Example: [https://github.com/PIH/openmrs-module-pihcore/blob/master/api/src/main/java/org/openmrs/module/pihcore/deploy/bundle/haiti/HaitiMetadataBundle.java#L100](https://github.com/PIH/openmrs-module-pihcore/blob/master/api/src/main/java/org/openmrs/module/pihcore/deploy/bundle/haiti/HaitiMetadataBundle.java#L100)
