-- set @startDate = '2025-01-01';
-- set @endDate = '2025-12-31';
-- set @patientId = 2337;

set SESSION group_concat_max_len = 1000000;
set @locale = global_property_value('default_locale', 'es');
set @mexConsultEnc = encounter_type('aa61d509-6e76-4036-a65d-7813c0c3b752');
set @mexControlledMedSet = concept_from_mapping('PIH', '20916');
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
create temporary table temp_encounters as
select e.encounter_id, false as has_qualifying_prescription
from encounter e
where e.voided = 0
  and e.encounter_type in (@mexConsultEnc)
  and (
    (@patientId is not null and e.patient_id = @patientId) or
    (@patientId is null and date (e.encounter_datetime) >= @startDate and date (e.encounter_datetime) <= @endDate)
    )
;
create index temp_encounters_enc_idx on temp_encounters(encounter_id);

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

-- Populate meds

drop temporary table if exists temp_meds;
create temporary table temp_meds (
    encounter_id int,
    obs_group_id int,
    name varchar(255),
    duration double,
    duration_units varchar(255),
    instructions text,
    dose_1 double,
    dose_1_units varchar(255),
    dose_1_morning varchar(255),
    dose_1_noon varchar(255),
    dose_1_afternoon varchar(255),
    dose_1_evening varchar(255),
    dose_2 double,
    dose_2_units varchar(255),
    dose_2_morning varchar(255),
    dose_2_noon varchar(255),
    dose_2_afternoon varchar(255),
    dose_2_evening varchar(255)
);

# Populate meds
insert into temp_meds (encounter_id, obs_group_id)
select o.encounter_id, o.obs_id
from temp_obs o
inner join temp_encounters e on o.encounter_id = e.encounter_id
where o.concept_id = @medicationGroup;

create index temp_meds_obs_group_idx on temp_obs(obs_group_id);

update temp_meds m set m.name = (select drugName(value_drug) from temp_obs where obs_group_id = m.obs_group_id and concept_id = @medication);
update temp_meds m set m.duration = (select value_numeric from temp_obs where obs_group_id = m.obs_group_id and concept_id = @duration);
update temp_meds m set m.duration_units = (select concept_name(value_coded, @locale) from temp_obs where obs_group_id = m.obs_group_id and concept_id = @durationUnits);
update temp_meds m set m.instructions = (select value_text from temp_obs where obs_group_id = m.obs_group_id and concept_id = @medicationInstructions);
update temp_meds m set m.dose_1 = (select value_numeric from temp_obs where obs_group_id = m.obs_group_id and concept_id = @dose1);
update temp_meds m set m.dose_1_units = (select concept_short_name(value_coded, @locale) from temp_obs where obs_group_id = m.obs_group_id and concept_id = @doseUnit1);
update temp_meds m set m.dose_1_morning = (select comments from temp_obs where obs_group_id = m.obs_group_id and concept_id = @timing1 and value_coded = @morning);
update temp_meds m set m.dose_1_noon = (select comments from temp_obs where obs_group_id = m.obs_group_id and concept_id = @timing1 and value_coded = @noon);
update temp_meds m set m.dose_1_afternoon = (select comments from temp_obs where obs_group_id = m.obs_group_id and concept_id = @timing1 and value_coded = @afternoon);
update temp_meds m set m.dose_1_evening = (select comments from temp_obs where obs_group_id = m.obs_group_id and concept_id = @timing1 and value_coded = @evening);
update temp_meds m set m.dose_2 = (select value_numeric from temp_obs where obs_group_id = m.obs_group_id and concept_id = @dose2);
update temp_meds m set m.dose_2_units = (select concept_short_name(value_coded, @locale) from temp_obs where obs_group_id = m.obs_group_id and concept_id = @doseUnit2);
update temp_meds m set m.dose_2_morning = (select comments from temp_obs where obs_group_id = m.obs_group_id and concept_id = @timing2 and value_coded = @morning);
update temp_meds m set m.dose_2_noon = (select comments from temp_obs where obs_group_id = m.obs_group_id and concept_id = @timing2 and value_coded = @noon);
update temp_meds m set m.dose_2_afternoon = (select comments from temp_obs where obs_group_id = m.obs_group_id and concept_id = @timing2 and value_coded = @afternoon);
update temp_meds m set m.dose_2_evening = (select comments from temp_obs where obs_group_id = m.obs_group_id and concept_id = @timing2 and value_coded = @evening);

select * from temp_meds;