# PIH CES EMR Distribution

This repository defines the OpenMRS distribution for PIH CES (Chiapas, Mexico). It packages together the [PIH EMR](https://github.com/PIH/openmrs-distro-pihemr) parent distribution,
CES-specific content, and the PIH EMR frontend into a single deployable artifact.
For more background on OpenMRS distributions, see the [OpenMRS wiki](https://wiki.openmrs.org/display/docs/OpenMRS+Distributions).

## Repository Structure

| Directory | Description |
|---|---|
| [`content/`](content/README.md) | CES-specific OpenMRS content package (Initializer configuration files) |
| [`distro/`](distro/README.md) | Distribution definition — resolves all component versions into `openmrs-distro.properties` |

## Components

| Component | Artifact |
|---|---|
| PIH EMR parent distro | `org.openmrs.distro:pihemr` |
| PIH EMR shared content | `org.pih.openmrs:pihemr-content` |
| CES content | `org.pih.openmrs:ces-content` |
| PIH EMR frontend | `org.pih.openmrs:openmrs-frontend-pihemr` |

Component versions are defined in `distro/pom.xml` and resolved into `distro/openmrs-distro.properties` at build time.

## Supported Configuration Profiles

| Site | PIH Config |
|---|---|
| `mexico-demo` | `mexico,mexico-demo` |

## Developer Guide

Local development runs through the shared
[`openmrs-contrib-distro-tools`](https://github.com/PIH/openmrs-contrib-distro-tools) CLI
(`openmrs-docker`/`openmrs-sdk`), installed once per machine rather than embedded in this repo.
Follow that repo's [Install](https://github.com/PIH/openmrs-contrib-distro-tools#install) section first — the commands below assume `openmrs-docker`/`openmrs-sdk` are already on your `PATH`.

### Docker (`openmrs-docker`)

An example environment file, `mexico-demo.env`, is provided in the repo root to get started quickly.
Because this file is found in the distribution repository, it is assumed that this is checked out on your machine, and
that `openmrs-docker` commands are running from the root of the distribution repository — it sets `DISTRO_SOURCE_DIR`
to this location. If you're using it as an example for running elsewhere, you may need to change or remove that.

```bash
source mexico-demo.env
openmrs-docker create mexico-demo
openmrs-docker mexico-demo initialize # Optional, but speeds up initial startup
openmrs-docker mexico-demo start
openmrs-docker mexico-demo wait  # Tails logs until OpenMRS is ready, then exits
```

Once created, day-to-day commands only need the instance name:

```bash
openmrs-docker mexico-demo stop
openmrs-docker mexico-demo logs
openmrs-docker mexico-demo destroy
```


### Configuring Concepts for Chiapas

We currently used two different approaches to install concepts on the Mexico server.  For Diagnoses and Drugs, we are 
trialing using Initializer as easier and streamlined way to manage the diagnosis and drug lists.  For
other concepts (such as those used on Mexico forms) we use Metadata Sharing.

#### Adding New Diagnoses

The Diagnoses are groups into 4 Diagnoses sets:

* Mexico primary care diagnosis set
* Mexico MCH diagnosis set
* Mexico mental diagnosis set
* COVID-19 diagnosis set

Each set has a CSV file that defines all the concepts in the set, found in this directory:
https://github.com/PIH/openmrs-config-ces/tree/master/content/configuration/concepts

And then a separate file that explicitly sets up the set membership:
https://github.com/PIH/openmrs-config-ces/tree/master/content/configuration/concepts

To add a new concept/diagnosis:
* Search the Concept server (concepts.pih-emr.org) to determine if the concept currently exists in PIH EMR dictionary
* If it does not exist, search for it in the CIEL dictionary, using the Open Concept Lab:
  * Go to "https://openconceptlab.org/" and search for the term
  * Filter the results to "CIEL" and select the appropriate CIEL concept
  * (If no appropriate CIEL concept found, more analysis will likely be needed)
* Once you've found the concept, create a line in the appropriate diagnosis csv file for the new concept:
  * If the concept exists in the PIH EMR dictionary, set the uuid to the same uuid as the existing concept 
  * Otherwise, set the uuid to the "External ID" listed for the concept in OCL
  * Add the Spanish name you want to use as the Fully Specified Name to the "Fully Specified Name:es" column; add any Spanish short name or synonym to the "Short Name:es" column
    * Ideally, this would be the fully-specified Spanish name as defined on the Concept server or in CIEL
  * Add the English fully-specified name (taken from the PIH EMR dictionary or the CIEL dictionary) to the "Fully Specified Name:en" column
  * Add the description to the description column (OPTIONAL)
  * Add the appropriate Data Class and Data Type to the Data Class and Data Type column (generally "Diagnosis" and "N/A")
  * Add mapping codes as needed to the concept:
    * If the concept exists in the PIH EMR Dictionary, add the PIH mappings to the "PIH:Mappings|SAME-AS|PIH|Name" (for alphanumeric) and/or "Mappings|SAME-AS|PIH|Number" (for codes) as appropriate
    * Add the CIEL mapping to the "Mappings|SAME-AS|CIEL" column  (Look in the "Associations" section of OCL to find the Code, Source, and Relationship... note that it's the "Code" you want, not the "Name)
    * Add at least one ICD-10-WHO mapping to the appropriate "Mappings|*|ICD-10-WHO" column   (Again, look in the "Associations" section of OCL to find the Code, Source, and Relationship... note that it's the "Code" you want, not the "Name")
    * Any other mappings can be skipped
  * Move the row as necessary to maintain alphabetical sorting by "Fully Specified Name:es" (not necessary, but good practice)
* Update the concept set file:
  * Create a new row, setting the "Member" column to the "Fully Specified Name:es" of the new concept
    * Sort alphabetically and update the Sort Weight columns to maintain that order (not necessary, but good practice)
* Commit your code to a branch and issue a PR for review

To modify the name of an existing diagnosis:
* To update the name of a diagnosis, you can update the appropriate row and column for that diagnosis name in the relevant csv file.
* **HOWEVER** note that if you change the Spanish fully specified name of a concept, you'll need to update that name in the related concept set file as well (or the next time you update the concept set file things will likely fail).
 
To remove a concept:
* Set the "Void/Retire" column to True for the concept in *both* the concept and concept set files


TODO: we need to be careful about modifying the concept files until we implement: https://pihemr.atlassian.net/browse/UHM-6708
TODO: we may want to consider simplifying this into a single diagnosis set, if this is easier.
TODO: we may want to remove the other mapping columns we aren't using (AMPATH, etc) entirely

#### Adding New Drugs

Drugs are added via the following three files:

* The csv file that defines the *concepts* that drugs refer to: 
  * https://github.com/PIH/openmrs-config-ces/blob/master/content/configuration/concepts/drug-concepts.csv
* The csv file that groups these concepts into a single set:
  * https://github.com/PIH/openmrs-config-ces/blob/master/content/configuration/conceptsets/drug-concept-set.csv 
* The csv file that defines the actual drug formularies:
  * https://github.com/PIH/openmrs-config-ces/blob/master/content/configuration/drugs/drugs.csv

To add new drug, first determine if the drug *concept* already exists in thd drug-concept.csv file.  If not, add the drug as follows:
* Search the Concept server (concepts.pih-emr.org) to determine if the drug concept currently exists in PIH EMR dictionary
* If it does not exist, search for it in the CIEL dictionary, using the Open Concept Lab:
  * Go to "https://openconceptlab.org/" and search for the term
  * Filter the results to "CIEL" and select the appropriate CIEL concept
  * (If no appropriate CIEL concept found, more analysis will likely be needed)
* Once you've found the concept, create a line in the drug-concept.csv file for the new concept:
  * If the concept exists in the PIH EMR dictionary, set the uuid to the same uuid as the existing concept
  * Otherwise, set the uuid to the "External ID" listed for the concept in OCL
  * Add the English fully-specified name (taken from the PIH EMR dictionary or the CIEL dictionary) to the "Fully Specified Name:en" column
  * Add any Spanish fully-specified name (OPTIONAL) (note that Spanish display text comes from the drug formulary file, defined below, so this name is generally not used)
  * Add the description to the description column (OPTIONAL)
  * Add the appropriate Data Class and Data Type to the Data Class and Data Type column (generally "Drug" and "N/A")
  * Add mapping codes as needed to the concept:
    * If the concept exists in the PIH EMR Dictionary, add the PIH mappings to the "PIH:Mappings|SAME-AS|PIH|Name" (for alphanumeric) and/or "Mappings|SAME-AS|PIH|Number" (for codes) as appropriate
    * Add the CIEL mapping to the "Mappings|SAME-AS|CIEL" column  (Look in the "Associations" section of OCL to find the Code, Source, and Relationship... note that it's the "Code" you want, not the "Name)
    * Add the RxNorm and SNOMED-CT mapping to the appropriate columns   (Again, look in the "Associations" section of OCL to find the Code, Source, and Relationship... note that it's the "Code" you want, not the "Name")
    * Any other mappings can be skipped
  * Move the row as necessary to maintain alphabetical sorting by "Fully Specified Name:en" (not necessary, but good practice)
* Update the drug-concept-set file:
  * Create a new row, setting the "Member" column to the "Fully Specified Name:en" of the new concept
    * Sort alphabetically and update the Sort Weight columns to maintain that order (not necessary, but good practice)

Once the concept has been added, add any specific formularies to the drug.csv
* Generate a random uuid for each formulary using a tool such as: https://www.uuidgenerator.net/
* For "Name" include the Spanish display name for the formulary:
  * TODO: How to determine whether to prepend CES or SSA?
* For "Concept Drug", reference the appropriate drug using its CIEL or PIH mapping code
* Commit your code to a branch and issue a PR for review

To remove a drug:
* Set the "Void/Retire" column for that drug formulation in the drugs.csv file to "True"
* If there are no other drug formulations that reference the drug concept, you can set "Void/Retire" column to "True" in *both* the "drug-concepts.csv" and "drug-concept-sets.csv" as well.

#### Configuring other Concepts

(TODO: rework this when we next add a new form? what should the process be here?)

1. On the concepts server (concepts.pih-emr.org), create a "Mexico MoH (Ministry of Health, or equivalent..) concept set", similar to the “[Liberia MoH diagnosis set](https://concepts.pih-emr.org/openmrs/dictionary/concept.htm?conceptId=10595)”. Create child sets, e.g. “Mexico MoH diagnosis”, “Mexico MoH Labs”, etc. Add concepts to these subsets.

2. For each concept in the source data dictionary:

    1. If there is an existing concept in the concepts server that is an exact match, add a mapping to the "Mexico MoH" vocabulary item, and a Spanish translation if required.

    2. If there is no existing concept, create it and add vocabulary mapping and translation.

    3. Add this concept to appropriate concept set.

3. In the Metadata Sharing module, use the "[Mexico Concepts](https://concepts.pih-emr.org/openmrs/module/metadatasharing/export/details.form?group=b5ee1651-1f90-4371-95da-7c13f8523f8c)" package and create a new version. See example here for “[Liberia Concepts](https://concepts.pih-emr.org/openmrs/module/metadatasharing/export/details.form?group=c0dc491e-a26e-4dee-99c4-c4dc5cb2e787)”.

4. Download the zipped package of this version.

5. Add the zip file to the PIH openmrs-module-mirebalais-metadata Github repo [here](https://github.com/PIH/openmrs-module-mirebalaismetadata/tree/master/api/src/main/resources). This will add the metadata concepts to our build pipeline.

6. The concepts should then be available companero staging server.
