-- set @startDate = '2025-01-01';
-- set @endDate = '2025-12-31';
-- set @patientId = 2337;

set SESSION group_concat_max_len = 1000000;
set @locale = global_property_value('default_locale', 'es');
set @mexConsultEnc = encounter_type('aa61d509-6e76-4036-a65d-7813c0c3b752');
set @medicationGroup = concept_from_mapping('PIH', '14822');
set @medication = concept_from_mapping('PIH', 'MEDICATION ORDERS');
set @duration = concept_from_mapping('PIH', '9075');
set @durationUnits = concept_from_mapping('PIH', 'TIME UNITS');
set @medicationInstructions = concept_from_mapping('PIH', '9072');
set @dose1 = concept_from_mapping('PIH', '9073');
set @doseUnit1 = concept_from_mapping('PIH', 'Dosing units coded');
set @timing1 = concept_from_mapping('PIH', 'Part of the day');
set @dose2 = concept_from_mapping('PIH', '14824');
set @doseUnit2 = concept_from_mapping('PIH', '14825');
set @timing2 = concept_from_mapping('PIH', '14823');
set @morning = concept_from_mapping('PIH', 'IN THE MORNING');
set @noon = concept_from_mapping('PIH', '3425');
set @afternoon = concept_from_mapping('PIH', 'In the afternoon');
set @evening = concept_from_mapping('PIH', 'IN THE EVENING');
set @codedDiagnosis = concept_from_mapping('PIH', 'DIAGNOSIS');
set @nonCodedDiagnosis = concept_from_mapping('PIH', '7416');
set @diagnosisOrder = concept_from_mapping('PIH', 'Diagnosis order');
set @primary = concept_from_mapping('PIH', 'primary');
set @otherNonCoded = concept_from_mapping('PIH', 'OTHER');

-- We only want to include prescriptions that contain at least one non-OTC drug, so we first build the table of those

drop temporary table if exists temp_controlled_drugs;
create temporary table temp_controlled_drugs (
    drug_id int primary key,
    drug_name varchar(255),
    concept_id int,
    concept_name varchar(255),
    retired boolean
);
insert into temp_controlled_drugs
select drug_id, name, concept_id, concept_name(concept_id, @locale), retired from drug where concept_id in (
    concept_from_mapping('PIH', 'AMOXICILLIN'),
    concept_from_mapping('PIH', 'AMOXICILLIN AND CLAVULANIC ACID'),
    concept_from_mapping('PIH', 'AMPICILLIN'),
    concept_from_mapping('PIH', 'AZITHROMYCIN'),
    concept_from_mapping('PIH', 'BENZATHINE PENICILLIN'),
    concept_from_mapping('PIH', '9206'), -- cephalexin
    concept_from_mapping('PIH', 'CEFTRIAXONE'),
    concept_from_mapping('PIH', 'CIPROFLOXACIN'),
    concept_from_mapping('PIH', '12081'),  -- ciprofloxacin dexamethasone
    concept_from_mapping('PIH', 'CLARITHROMYCIN'),
    concept_from_mapping('PIH', 'CLINDAMYCIN'),
    concept_from_mapping('PIH', 'CHLORAMPHENICOL'),
    concept_from_mapping('PIH', 'CLOXACILLIN'),
    concept_from_mapping('PIH', 'DOXYCYCLINE'),
    concept_from_mapping('PIH', 'ERYTHROMYCIN'),
    concept_from_mapping('PIH', '14137'), -- fosfomycin
    concept_from_mapping('PIH', 'GENTAMICIN'),
    concept_from_mapping('PIH', 'LEVOFLOXACIN'),
    concept_from_mapping('PIH', '12078'), -- neomycin
    concept_from_mapping('PIH', 'TETRACYCLINE'),
    concept_from_mapping('PIH', '13295'), -- tobramycin
    concept_from_mapping('PIH', '916'), -- cotrimoxazone
    concept_from_mapping('PIH', 'AMITRYPTILINE'),
    concept_from_mapping('PIH', '12116'), -- clonazepam
    concept_from_mapping('PIH', 'DIAZEPAM'),
    concept_from_mapping('PIH', 'HALOPERIDOL'),
    concept_from_mapping('PIH', '12139'), -- lorazepam
    concept_from_mapping('PIH', '12091'), -- methylphenidate
    concept_from_mapping('PIH', '14138'), -- mifepristone
    concept_from_mapping('PIH', 'PHENOBARBITAL')
);

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
    has_qualifying_prescription boolean,
    med_1_obs_group_id int,
    med_1_name varchar(255),
    med_1_duration double,
    med_1_duration_units varchar(255),
    med_1_instructions text,
    med_1_dose_1 double,
    med_1_dose_1_units varchar(255),
    med_1_dose_1_morning varchar(255),
    med_1_dose_1_noon varchar(255),
    med_1_dose_1_afternoon varchar(255),
    med_1_dose_1_evening varchar(255),
    med_1_dose_2 double,
    med_1_dose_2_units varchar(255),
    med_1_dose_2_morning varchar(255),
    med_1_dose_2_noon varchar(255),
    med_1_dose_2_afternoon varchar(255),
    med_1_dose_2_evening varchar(255),
    med_2_obs_group_id int,
    med_2_name varchar(255),
    med_2_duration double,
    med_2_duration_units varchar(255),
    med_2_instructions text,
    med_2_dose_1 double,
    med_2_dose_1_units varchar(255),
    med_2_dose_1_morning varchar(255),
    med_2_dose_1_noon varchar(255),
    med_2_dose_1_afternoon varchar(255),
    med_2_dose_1_evening varchar(255),
    med_2_dose_2 double,
    med_2_dose_2_units varchar(255),
    med_2_dose_2_morning varchar(255),
    med_2_dose_2_noon varchar(255),
    med_2_dose_2_afternoon varchar(255),
    med_2_dose_2_evening varchar(255),
    med_3_obs_group_id int,
    med_3_name varchar(255),
    med_3_duration double,
    med_3_duration_units varchar(255),
    med_3_instructions text,
    med_3_dose_1 double,
    med_3_dose_1_units varchar(255),
    med_3_dose_1_morning varchar(255),
    med_3_dose_1_noon varchar(255),
    med_3_dose_1_afternoon varchar(255),
    med_3_dose_1_evening varchar(255),
    med_3_dose_2 double,
    med_3_dose_2_units varchar(255),
    med_3_dose_2_morning varchar(255),
    med_3_dose_2_noon varchar(255),
    med_3_dose_2_afternoon varchar(255),
    med_3_dose_2_evening varchar(255),
    med_4_obs_group_id int,
    med_4_name varchar(255),
    med_4_duration double,
    med_4_duration_units varchar(255),
    med_4_instructions text,
    med_4_dose_1 double,
    med_4_dose_1_units varchar(255),
    med_4_dose_1_morning varchar(255),
    med_4_dose_1_noon varchar(255),
    med_4_dose_1_afternoon varchar(255),
    med_4_dose_1_evening varchar(255),
    med_4_dose_2 double,
    med_4_dose_2_units varchar(255),
    med_4_dose_2_morning varchar(255),
    med_4_dose_2_noon varchar(255),
    med_4_dose_2_afternoon varchar(255),
    med_4_dose_2_evening varchar(255),
    med_5_obs_group_id int,
    med_5_name varchar(255),
    med_5_duration double,
    med_5_duration_units varchar(255),
    med_5_instructions text,
    med_5_dose_1 double,
    med_5_dose_1_units varchar(255),
    med_5_dose_1_morning varchar(255),
    med_5_dose_1_noon varchar(255),
    med_5_dose_1_afternoon varchar(255),
    med_5_dose_1_evening varchar(255),
    med_5_dose_2 double,
    med_5_dose_2_units varchar(255),
    med_5_dose_2_morning varchar(255),
    med_5_dose_2_noon varchar(255),
    med_5_dose_2_afternoon varchar(255),
    med_5_dose_2_evening varchar(255)
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
create temporary table temp_obs
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

# Populate meds

-- We support up to 5 medications.  If we need more, simply follow the same pattern to add additional columns

-- Medication 1
update temp_encounters e set med_1_obs_group_id = (select o.obs_id from temp_obs o where o.encounter_id = e.encounter_id and o.concept_id = @medicationGroup order by o.obs_id limit 1 offset 0);
update temp_encounters e set med_1_name = (select drugName(value_drug) from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @medication);
update temp_encounters e set med_1_duration = (select value_numeric from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @duration);
update temp_encounters e set med_1_duration_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @durationUnits);
update temp_encounters e set med_1_instructions = (select value_text from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @medicationInstructions);
update temp_encounters e set med_1_dose_1 = (select value_numeric from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @dose1);
update temp_encounters e set med_1_dose_1_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @doseUnit1);
update temp_encounters e set med_1_dose_1_morning = (select comments from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @timing1 and value_coded = @morning);
update temp_encounters e set med_1_dose_1_noon = (select comments from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @timing1 and value_coded = @noon);
update temp_encounters e set med_1_dose_1_afternoon = (select comments from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @timing1 and value_coded = @afternoon);
update temp_encounters e set med_1_dose_1_evening = (select comments from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @timing1 and value_coded = @evening);
update temp_encounters e set med_1_dose_2 = (select value_numeric from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @dose2);
update temp_encounters e set med_1_dose_2_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @doseUnit2);
update temp_encounters e set med_1_dose_2_morning = (select comments from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @timing2 and value_coded = @morning);
update temp_encounters e set med_1_dose_2_noon = (select comments from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @timing2 and value_coded = @noon);
update temp_encounters e set med_1_dose_2_afternoon = (select comments from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @timing2 and value_coded = @afternoon);
update temp_encounters e set med_1_dose_2_evening = (select comments from temp_obs where obs_group_id = med_1_obs_group_id and concept_id = @timing2 and value_coded = @evening);

-- Medication 2
update temp_encounters e set med_2_obs_group_id = (select o.obs_id from temp_obs o where o.encounter_id = e.encounter_id and o.concept_id = @medicationGroup order by o.obs_id limit 1 offset 1);
update temp_encounters e set med_2_name = (select drugName(value_drug) from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @medication);
update temp_encounters e set med_2_duration = (select value_numeric from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @duration);
update temp_encounters e set med_2_duration_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @durationUnits);
update temp_encounters e set med_2_instructions = (select value_text from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @medicationInstructions);
update temp_encounters e set med_2_dose_1 = (select value_numeric from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @dose1);
update temp_encounters e set med_2_dose_1_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @doseUnit1);
update temp_encounters e set med_2_dose_1_morning = (select comments from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @timing1 and value_coded = @morning);
update temp_encounters e set med_2_dose_1_noon = (select comments from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @timing1 and value_coded = @noon);
update temp_encounters e set med_2_dose_1_afternoon = (select comments from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @timing1 and value_coded = @afternoon);
update temp_encounters e set med_2_dose_1_evening = (select comments from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @timing1 and value_coded = @evening);
update temp_encounters e set med_2_dose_2 = (select value_numeric from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @dose2);
update temp_encounters e set med_2_dose_2_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @doseUnit2);
update temp_encounters e set med_2_dose_2_morning = (select comments from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @timing2 and value_coded = @morning);
update temp_encounters e set med_2_dose_2_noon = (select comments from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @timing2 and value_coded = @noon);
update temp_encounters e set med_2_dose_2_afternoon = (select comments from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @timing2 and value_coded = @afternoon);
update temp_encounters e set med_2_dose_2_evening = (select comments from temp_obs where obs_group_id = med_2_obs_group_id and concept_id = @timing2 and value_coded = @evening);

-- Medication 3
update temp_encounters e set med_3_obs_group_id = (select o.obs_id from temp_obs o where o.encounter_id = e.encounter_id and o.concept_id = @medicationGroup order by o.obs_id limit 1 offset 2);
update temp_encounters e set med_3_name = (select drugName(value_drug) from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @medication);
update temp_encounters e set med_3_duration = (select value_numeric from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @duration);
update temp_encounters e set med_3_duration_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @durationUnits);
update temp_encounters e set med_3_instructions = (select value_text from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @medicationInstructions);
update temp_encounters e set med_3_dose_1 = (select value_numeric from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @dose1);
update temp_encounters e set med_3_dose_1_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @doseUnit1);
update temp_encounters e set med_3_dose_1_morning = (select comments from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @timing1 and value_coded = @morning);
update temp_encounters e set med_3_dose_1_noon = (select comments from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @timing1 and value_coded = @noon);
update temp_encounters e set med_3_dose_1_afternoon = (select comments from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @timing1 and value_coded = @afternoon);
update temp_encounters e set med_3_dose_1_evening = (select comments from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @timing1 and value_coded = @evening);
update temp_encounters e set med_3_dose_2 = (select value_numeric from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @dose2);
update temp_encounters e set med_3_dose_2_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @doseUnit2);
update temp_encounters e set med_3_dose_2_morning = (select comments from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @timing2 and value_coded = @morning);
update temp_encounters e set med_3_dose_2_noon = (select comments from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @timing2 and value_coded = @noon);
update temp_encounters e set med_3_dose_2_afternoon = (select comments from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @timing2 and value_coded = @afternoon);
update temp_encounters e set med_3_dose_2_evening = (select comments from temp_obs where obs_group_id = med_3_obs_group_id and concept_id = @timing2 and value_coded = @evening);

-- Medication 4
update temp_encounters e set med_4_obs_group_id = (select o.obs_id from temp_obs o where o.encounter_id = e.encounter_id and o.concept_id = @medicationGroup order by o.obs_id limit 1 offset 3);
update temp_encounters e set med_4_name = (select drugName(value_drug) from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @medication);
update temp_encounters e set med_4_duration = (select value_numeric from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @duration);
update temp_encounters e set med_4_duration_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @durationUnits);
update temp_encounters e set med_4_instructions = (select value_text from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @medicationInstructions);
update temp_encounters e set med_4_dose_1 = (select value_numeric from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @dose1);
update temp_encounters e set med_4_dose_1_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @doseUnit1);
update temp_encounters e set med_4_dose_1_morning = (select comments from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @timing1 and value_coded = @morning);
update temp_encounters e set med_4_dose_1_noon = (select comments from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @timing1 and value_coded = @noon);
update temp_encounters e set med_4_dose_1_afternoon = (select comments from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @timing1 and value_coded = @afternoon);
update temp_encounters e set med_4_dose_1_evening = (select comments from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @timing1 and value_coded = @evening);
update temp_encounters e set med_4_dose_2 = (select value_numeric from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @dose2);
update temp_encounters e set med_4_dose_2_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @doseUnit2);
update temp_encounters e set med_4_dose_2_morning = (select comments from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @timing2 and value_coded = @morning);
update temp_encounters e set med_4_dose_2_noon = (select comments from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @timing2 and value_coded = @noon);
update temp_encounters e set med_4_dose_2_afternoon = (select comments from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @timing2 and value_coded = @afternoon);
update temp_encounters e set med_4_dose_2_evening = (select comments from temp_obs where obs_group_id = med_4_obs_group_id and concept_id = @timing2 and value_coded = @evening);

-- Medication 5
update temp_encounters e set med_5_obs_group_id = (select o.obs_id from temp_obs o where o.encounter_id = e.encounter_id and o.concept_id = @medicationGroup order by o.obs_id limit 1 offset 4);
update temp_encounters e set med_5_name = (select drugName(value_drug) from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @medication);
update temp_encounters e set med_5_duration = (select value_numeric from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @duration);
update temp_encounters e set med_5_duration_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @durationUnits);
update temp_encounters e set med_5_instructions = (select value_text from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @medicationInstructions);
update temp_encounters e set med_5_dose_1 = (select value_numeric from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @dose1);
update temp_encounters e set med_5_dose_1_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @doseUnit1);
update temp_encounters e set med_5_dose_1_morning = (select comments from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @timing1 and value_coded = @morning);
update temp_encounters e set med_5_dose_1_noon = (select comments from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @timing1 and value_coded = @noon);
update temp_encounters e set med_5_dose_1_afternoon = (select comments from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @timing1 and value_coded = @afternoon);
update temp_encounters e set med_5_dose_1_evening = (select comments from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @timing1 and value_coded = @evening);
update temp_encounters e set med_5_dose_2 = (select value_numeric from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @dose2);
update temp_encounters e set med_5_dose_2_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @doseUnit2);
update temp_encounters e set med_5_dose_2_morning = (select comments from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @timing2 and value_coded = @morning);
update temp_encounters e set med_5_dose_2_noon = (select comments from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @timing2 and value_coded = @noon);
update temp_encounters e set med_5_dose_2_afternoon = (select comments from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @timing2 and value_coded = @afternoon);
update temp_encounters e set med_5_dose_2_evening = (select comments from temp_obs where obs_group_id = med_5_obs_group_id and concept_id = @timing2 and value_coded = @evening);

select * from temp_encounters;
