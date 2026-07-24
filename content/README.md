# PIH CES Content Package

This module defines the CES-specific [OpenMRS Initializer](https://github.com/mekomsolutions/openmrs-module-initializer) configuration. At build time, the contents of `configuration/` are assembled into a zip artifact published as `org.pih.openmrs:ces-content`.

This content package is merged with the shared [PIH EMR content](https://github.com/PIH/openmrs-config-pihemr) (`org.pih.openmrs:pihemr-content`) when the distribution is built.

## Configuration Structure

Configuration files live under `configuration/` and are loaded by the OpenMRS Initializer module at startup.

| Directory | Purpose |
|---|---|
| `addresshierarchy/` | Address hierarchy entries for Chiapas |
| `appframework/` | App framework extension definitions for the OpenMRS frontend |
| `conceptclasses/` | Custom concept class definitions |
| `concepts/` | Concept definitions (diagnoses, drugs, lab tests) |
| `conceptsets/` | Concept set memberships and groupings |
| `drugs/` | Drug formulary definitions |
| `encountertypes/` | Encounter type definitions for CES workflows |
| `frontend/` | OpenMRS frontend configuration and customization |
| `globalproperties/` | OpenMRS global property overrides |
| `locations/` | Facility and location definitions for Chiapas clinics |
| `messageproperties/` | Message and notification properties |
| `metadatasets/` | Metadata set definitions |
| `patientidentifiertypes/` | Patient identifier type definitions |
| `pih/` | PIH-specific configuration (HTML forms, radiology constants, etc.) |
| `programs/` | Clinical program definitions |
| `programworkflows/` | Program workflow state definitions |
| `programworkflowstates/` | Program workflow state details |
| `reports/` | Report definitions and configurations |

## content.properties

`content.properties` provides the content package name and version (interpolated from the Maven project at build time), and defines key UUID constants used across the configuration:

| Property | Description |
|---|---|
| `var.patientIdentifierType.chiapasEmrId.uuid` | UUID of the Chiapas EMR ID patient identifier type |
| `var.patientIdentifierType.curp.uuid` | UUID of the CURP (Mexican national ID) patient identifier type |
| `var.patientIdentifierType.mexicoDossierNumber.uuid` | UUID of the Mexico dossier number patient identifier type |
| `var.encounterType.mexicoConsult.uuid` | UUID of the Mexico consultation encounter type |
| `var.encounterType.clinicalHistory.uuid` | UUID of the clinical history encounter type |
| `var.encounterType.PATIENT_REGISTRATION.name` | Name of the patient registration encounter type |
| `var.encounterType.CHECK_IN.name` | Name of the check-in encounter type |
| `var.encounterType.MEDICATION_DISPENSED.name` | Name of the medication dispensing encounter type |
| `var.encounterType.VITALS.name` | Name of the vital signs encounter type |
