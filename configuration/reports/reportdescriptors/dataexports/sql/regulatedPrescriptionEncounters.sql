set @startDate = '2025-01-01';
set @endDate = '2025-12-31';
-- set @patientId = 2337;

set SESSION group_concat_max_len = 1000000;
set @locale = global_property_value('default_locale', 'es');
set @mexConsultEnc = encounter_type('aa61d509-6e76-4036-a65d-7813c0c3b752');
set @mexControlledMedSet = concept_from_mapping('PIH', '20916');
set @medication = concept_from_mapping('PIH', 'MEDICATION ORDERS');
set @codedDiagnosis = concept_from_mapping('PIH', 'DIAGNOSIS');
set @nonCodedDiagnosis = concept_from_mapping('PIH', '7416');
set @diagnosisOrder = concept_from_mapping('PIH', 'Diagnosis order');
set @primary = concept_from_mapping('PIH', 'primary');
set @otherNonCoded = concept_from_mapping('PIH', 'OTHER');

-- We only want to include prescriptions that contain at least one non-OTC drug, so we first build the table of those

drop temporary table if exists temp_controlled_drugs;
create temporary table temp_controlled_drugs as
select d.drug_id, d.name, d.concept_id, concept_name(d.concept_id, @locale) as concept_name
from drug d
inner join concept_set s on d.concept_id = s.concept_id
where s.concept_set = @mexControlledMedSet
and d.retired = 0;

-- Start out by building temporary tables representing the encounters and obs that are included in this export

drop temporary table if exists temp_encounters;
create temporary table temp_encounters
(
    encounter_id int,
    patient_id int,
    encounter_date date,
    patient_name varchar(255),
    birthdate date,
    age int,
    diagnoses text,
    allergies text,
    has_qualifying_prescription boolean
);

insert into temp_encounters (encounter_id, patient_id, encounter_date, has_qualifying_prescription)
select e.encounter_id, e.patient_id, date(e.encounter_datetime), false
from encounter e
where e.voided = 0
  and e.encounter_type in (@mexConsultEnc)
  and (
    (@patientId is not null and e.patient_id = @patientId) or
    (@patientId is null and date (e.encounter_datetime) >= @startDate and date (e.encounter_datetime) <= @endDate)
    )
order by e.encounter_datetime, e.encounter_id
;
create index temp_encounters_enc_idx on temp_encounters(encounter_id);
create index temp_encounters_pat_idx on temp_encounters(patient_id);

-- Retrieve obs for each encounter
drop temporary table if exists temp_obs;
create temporary table temp_obs as
select o.obs_id, o.encounter_id, o.obs_group_id, o.concept_id, o.value_coded, o.value_drug, o.value_numeric, o.value_text, o.comments
from obs o
inner join temp_encounters t on t.encounter_id = o.encounter_id
where o.voided = 0;
create index temp_obs_enc_idx on temp_obs(encounter_id);
create index temp_obs_enc_concept_idx on temp_obs(encounter_id, concept_id);
create index temp_obs_enc_concept_drug_idx on temp_obs(encounter_id, concept_id, value_drug);
create index temp_obs_group_idx on temp_obs(obs_group_id);

-- Identify any encounters that contain at least one prescription for an appropriate drug
update temp_encounters e
inner join temp_obs o on e.encounter_id = o.encounter_id
inner join temp_controlled_drugs d on o.value_drug = d.drug_id
set e.has_qualifying_prescription = true
where o.concept_id = @medication
;

-- Remove rows without a qualifying prescription
delete from temp_encounters where has_qualifying_prescription = 0;

-- Populate demographics

update temp_encounters set patient_name = trim(person_name(patient_id));
update temp_encounters set birthdate = birthdate(patient_id);
update temp_encounters set age = timestampdiff(YEAR, birthdate, encounter_date);

-- Populate diagnoses
drop temporary table if exists temp_diagnoses;
create temporary table temp_diagnoses (
    encounter_id int,
    obs_group_id int,
    diagnosis varchar(255),
    sort_order int default 1
);
create index temp_diagnoses_enc_idx on temp_obs(encounter_id);

insert into temp_diagnoses (encounter_id, obs_group_id, diagnosis)
select encounter_id, obs_group_id, concept_name(value_coded, @locale) from temp_obs where concept_id = @codedDiagnosis;

insert into temp_diagnoses (encounter_id, obs_group_id, diagnosis)
select encounter_id, obs_group_id, value_text from temp_obs where concept_id = @nonCodedDiagnosis;

update temp_diagnoses d
inner join temp_obs o on d.obs_group_id = o.obs_group_id
set d.sort_order = 0
where o.concept_id = @diagnosisOrder and o.value_coded = @primary;

update temp_encounters e
inner join (select encounter_id, group_concat(diagnosis order by sort_order separator ', ') as diagnoses from temp_diagnoses group by encounter_id) d on e.encounter_id = d.encounter_id
set e.diagnoses = d.diagnoses;

# Populate allergies
drop temporary table if exists temp_allergies;
create temporary table temp_allergies (
    patient_id int,
    allergy varchar(255)
);
insert into temp_allergies (patient_id, allergy)
select a.patient_id, if (a.coded_allergen = @otherNonCoded, a.non_coded_allergen, concept_name(a.coded_allergen, @locale))
from allergy a
inner join temp_encounters e on a.patient_id = e.patient_id
group by a.patient_id, concept_name(a.coded_allergen, @locale)
;

update temp_encounters e
inner join (select patient_id, group_concat(allergy separator ', ') as allergies from temp_allergies group by patient_id) d on e.patient_id = d.patient_id
set e.allergies = d.allergies;

select * from temp_encounters;
