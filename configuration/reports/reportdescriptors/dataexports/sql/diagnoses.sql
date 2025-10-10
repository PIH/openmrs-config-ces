-- set @startDate = '2021-01-01';
-- set @endDate = '2021-01-31';

SET @locale = global_property_value('default_locale', 'es');

DROP TEMPORARY TABLE IF EXISTS temp_diagnoses;
CREATE TEMPORARY TABLE temp_diagnoses
(
    obs_id                      INT,
    obs_group_id                INT,
    patient_id					INT,
    encounter_id                INT,
    encounter_datetime			DATETIME,
    date_created                DATETIME,
    creator                     INT,
    entered_by          		VARCHAR(255),
    encounter_location			VARCHAR(255),
    age_at_encounter			INT,
    emr_id						VARCHAR(50),
    birthdate					DATETIME,
    gender						VARCHAR(50),
    value_coded                 INT,
    value_text                  VARCHAR(1000),
    diagnosis                   VARCHAR(1000),
    diagnosis_icd10_code        VARCHAR(255),
    diagnosis_order             VARCHAR(255),
    first_time                  BOOLEAN
 );
create index temp_diagnoses_obs_idx on temp_diagnoses(obs_id);
create index temp_diagnoses_obs_group_idx on temp_diagnoses(obs_group_id);
create index temp_diagnoses_patient_idx on temp_diagnoses(patient_id);
create index temp_diagnoses_encounter_idx on temp_diagnoses(encounter_id);

set @codedDiagnosis = concept_from_mapping('PIH', 'DIAGNOSIS');
set @nonCodedDiagnosis = concept_from_mapping('PIH', 'Diagnosis or problem, non-coded');
set @diagnosisOrder = concept_from_mapping('PIH', 'Diagnosis order');
set @diagnosisCertainty = concept_from_mapping('PIH', 'CLINICAL IMPRESSION DIAGNOSIS CONFIRMED');
set @confirmed = concept_from_mapping('PIH', 'CONFIRMED');

insert into temp_diagnoses
    (obs_id, obs_group_id, patient_id, encounter_id, encounter_datetime, date_created, creator, value_coded, value_text)
select
    o.obs_id, o.obs_group_id, e.patient_id, e.encounter_id, e.encounter_datetime, o.date_created, o.creator, o.value_coded, o.value_text
from obs o
inner join encounter e on o.encounter_id = e.encounter_id
inner join patient p on e.patient_id = p.patient_id
where o.voided = 0 and e.voided = 0 and p.voided = 0
and o.concept_id in (@codedDiagnosis, @nonCodedDiagnosis)
and (@startDate is null or (date(e.encounter_datetime) >= @startDate))
and (@endDate is null or (date(e.encounter_datetime) <= @endDate))
;

-- Populate encounter and demographic columns
update temp_diagnoses set entered_by = person_name_of_user(creator);
update temp_diagnoses set encounter_location = encounter_location_name(encounter_id);
update temp_diagnoses set age_at_encounter = age_in_full_years_on_date(patient_id, encounter_datetime);
update temp_diagnoses set emr_id = primary_emr_id(patient_id);
update temp_diagnoses set birthdate = birthdate(patient_id);
update temp_diagnoses set gender = gender(patient_id);

-- Get diagnosis observation data

drop temporary table if exists temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.value_coded_name_id ,o.comments 
from obs o
inner join temp_diagnoses t on (t.obs_group_id = o.obs_group_id or t.obs_id = o.obs_id)
where o.voided = 0;

create index temp_obs_concept_id on temp_obs(concept_id);
create index temp_obs_ogi on temp_obs(obs_group_id);
create index temp_obs_ci1 on temp_obs(obs_group_id, concept_id);

update temp_diagnoses set diagnosis = value_text where value_text is not null;
update temp_diagnoses set diagnosis = concept_name(value_coded, @locale) where value_coded is not null;
update temp_diagnoses set diagnosis_icd10_code = retrieveICD10(value_coded) where value_coded is not null;
update temp_diagnoses d set d.diagnosis_order = (select concept_name(value_coded, @locale) from temp_obs o where o.obs_group_id = d.obs_group_id and o.concept_id = @diagnosisOrder limit 1);
update temp_diagnoses d set d.first_time = (select if(value_coded = @confirmed, true, false) from temp_obs o where o.obs_group_id = d.obs_group_id and o.concept_id = @diagnosisCertainty limit 1);

alter table temp_diagnoses drop column obs_id;
alter table temp_diagnoses drop column obs_group_id;
alter table temp_diagnoses drop column creator;
alter table temp_diagnoses drop column value_coded;
alter table temp_diagnoses drop column value_text;

select * from temp_diagnoses;