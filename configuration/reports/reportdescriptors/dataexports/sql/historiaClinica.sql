-- set  @startDate = '2000-01-01';
-- set  @endDate = '2025-12-31';

set SESSION group_concat_max_len = 1000000;

set @locale = global_property_value('default_locale', 'en');

set @historiaClinicaEnc = encounter_type('0d16a7c9-07fb-43f6-8984-dd7787f26a5a');

drop temporary table if exists temp_hc;
create temporary table temp_hc
(
encounter_id int(11),
patient_id int(11),
location_id int(11),
location_name varchar(255),
full_facility_name text,
lastname varchar(255),
-- maternal name??? -- ----------------
firstname varchar(255),
birthdate date,
age int,
gender varchar(255),
address varchar(255),
localidad varchar(255),
telephone varchar(255),
family_history text, 
non_pathological_history text, 	
feeding varchar(255),
housing varchar(255),
occupation varchar(255),
hygiene varchar(255),
vaccine varchar(255),
other_non_path_history varchar(255),
pathological_history text,	-- <<<	need input							
gyn_history	text,									
main_symptom text,																
evolution_symptoms text,										
digestive text,										
respiratory	 text,									
genitourinary text,										
cardiovascular text,										
nervous_system	text,	 								
endocrine	text,									
locomotor text,			
temp float,
bp_systolic int,
bp_diastolic int,
bp text,	
hr float,
rr float,
otros_exam text,										
head text,									
neck text,									
chest text,									
abdomen text,									
extremities text,									
diagnoses  text,										
entry_date date,								
provider  text
);

insert into temp_hc (encounter_id, patient_id, location_id)
select encounter_id, patient_id, location_id 
FROM encounter e 
where  e.voided = 0 
AND e.encounter_type in (@historiaClinicaEnc)
AND date(e.encounter_datetime) >= @startDate
AND date(e.encounter_datetime) <= @endDate;

create index temp_hc_ei on temp_hc(encounter_id);
create index temp_hc_pi on temp_hc(patient_id);

update temp_hc
set location_name = location_name(location_id);

-- patient level columns
drop temporary table if exists temp_patients;
create temporary table temp_patients
(patient_id int(11),
firstname varchar(255),
lastname varchar(255),
birthdate date,
gender varchar(255),
address varchar(255),
localidad varchar(255),
telephone varchar(255));

create index temp_patients_pi on temp_patients(patient_id);

insert into temp_patients(patient_id)
select distinct patient_id from temp_hc;

update temp_patients
set firstname = person_given_name(patient_id);

update temp_patients
set lastname = person_family_name(patient_id);

update temp_patients
set birthdate = birthdate(patient_id);

update temp_patients
set gender = gender(patient_id);

update temp_patients
set localidad = person_address_city_village(patient_id);

update temp_patients
set address = person_address_one(patient_id);

update temp_patients
set telephone = phone_number(patient_id);

update temp_hc t
inner join temp_patients p on p.patient_id = t.patient_id
set t.firstname = p.firstname,
	t.lastname = p.lastname,
	t.birthdate = p.birthdate,
	t.gender = p.gender,
	t.address = p.address,
	t.localidad = p.localidad,
	t.telephone = p.telephone;

-- obs level columns
DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.obs_datetime, o.date_created, o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_text, o.value_coded_name_id , o.voided
from obs o
inner join temp_hc t on t.encounter_id = o.encounter_id 
where o.voided = 0;

create index temp_obs_concept_id on temp_obs(concept_id);

set @familyHistory = concept_from_mapping('PIH','10144');
update temp_hc 
set family_history = obs_value_text_from_temp_using_concept_id(encounter_id, @familyHistory);

-- non path history
set @feeding = concept_from_mapping('PIH','14171');
update temp_hc 
set feeding = obs_value_text_from_temp_using_concept_id(encounter_id, @feeding);

set @housing = concept_from_mapping('PIH','14172');
update temp_hc 
set housing = obs_value_text_from_temp_using_concept_id(encounter_id, @housing);

set @occupation = concept_from_mapping('PIH','14174');
update temp_hc 
set occupation = obs_value_text_from_temp_using_concept_id(encounter_id, @occupation);

set @hygiene = concept_from_mapping('PIH','14173');
update temp_hc 
set hygiene = obs_value_text_from_temp_using_concept_id(encounter_id, @hygiene);

set @vaccine = concept_from_mapping('PIH','14175');
update temp_hc 
set vaccine = obs_value_text_from_temp_using_concept_id(encounter_id, @vaccine);

set @other_non_path_history = concept_from_mapping('PIH','13749');
update temp_hc 
set other_non_path_history = obs_value_text_from_temp_using_concept_id(encounter_id, @other_non_path_history);

update temp_hc
set non_pathological_history = 
trim(trailing ', ' from
CONCAT(if(feeding is null, '', concat(feeding, ', ')),
if(housing is null, '', concat(housing, ', ')),
if(occupation is null, '', concat(occupation, ', ')),
if(hygiene is null, '', concat(hygiene, ', ')),
if(vaccine is null, '', concat(vaccine, ', ')),
if(other_non_path_history is null, '', concat(other_non_path_history, ', '))));

select
encounter_id,
patient_id,
location_id,
location_name,
full_facility_name,
lastname,
firstname,
birthdate,
age,
gender,
address,
localidad,
telephone,
family_history,
non_pathological_history,
feeding,
housing,
occupation,
hygiene,
vaccine,
other_non_path_history,
pathological_history,
gyn_history,
main_symptom,
evolution_symptoms,
digestive,
respiratory,
genitourinary,
cardiovascular,
nervous_system,
endocrine,
locomotor,
temp,
bp_systolic,
bp_diastolic,
bp,
hr,
rr,
otros_exam,
head,
neck,
chest,
abdomen,
extremities,
diagnoses,
entry_date,
provider
from temp_hc;
