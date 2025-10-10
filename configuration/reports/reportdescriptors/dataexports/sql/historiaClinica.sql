-- set @startDate = '2025-06-01';
-- set @endDate = '2025-12-31';
-- set @patientId = 2337;

set SESSION group_concat_max_len = 1000000;

set @locale = global_property_value('default_locale', 'en');

set @historiaClinicaEnc = encounter_type('0d16a7c9-07fb-43f6-8984-dd7787f26a5a');
set @vitalsEnc = encounter_type('4fb47712-34a6-40d2-8ed3-e153abbd25b7');

drop temporary table if exists temp_hc;
create temporary table temp_hc
(
encounter_id int(11),
patient_id int(11),
visit_id int(11),
encounter_date date,
sheet_name varchar(100),
location_id int(11),
location_name varchar(255),
full_facility_name text,
lastname varchar(255),
firstname varchar(255),
birthdate date,
age int,
gender varchar(255),
address varchar(255),
localidad varchar(255),
telephone varchar(255),
family_history text, 
non_pathological_history text, 	
feeding text,
housing text,
occupation text,
hygiene text,
vaccine text,
other_non_path_history text,
daily_cigs float,
years_smoking float,
history_alcohol varchar(255),
years_alcohol float,
number_transfusions float,
date_transfusion date,
type_transfusion varchar(255),
number_surgeries float,
date_surgery date,
type_surgery varchar(255),
reason_surgery varchar(255),
number_hospitalizations float,
date_hospitalization date,
reason_hospitalization varchar(255),
other_pathological_history text,
pathological_history text,
age_first_menstrual_period float,
age_first_sexual_activity float,
blood_type varchar(255),
menstrual_cycle_details text,
gravida float,
parity float,
cesarian float,
abortions_before_20_weeks float,
abortions_after_20_weeks float,
date_previous_pregnancy date,
obstetric_notes text,
number_children float,
lmp_date date,
has_had_menopause varchar(255),
age_of_menopause float,
sti_notes text,
family_planning_notes text,
fp_method varchar(255),
pap_smear varchar(255),
breast_exam varchar(255),
gyn_history	text,									
main_symptom text,																
evolution_symptoms text,										
digestive text,										
respiratory	 text,									
genital text,
genitourinary text,
urinary text,
cardiovascular text,										
nervous_system	text,	 								
endocrine	text,									
locomotor text,		
vitals_encounter_id int(11),
temp float,
bp_systolic float,
bp_diastolic float,
bp text,
weight float,
height float,
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
provider  text,
latest_pap_smear_date date,
pap_smear_obs_group_id int(11),
pap_smear_result varchar(255),
pap_smear_comments text,
latest_breast_exam_date date,
breast_exam_obs_group_id int(11),
breast_exam_comments text
);

insert into temp_hc (encounter_id, patient_id, location_id, encounter_date, entry_date, visit_id)
select encounter_id, patient_id, location_id, date(encounter_datetime), date(date_created), visit_id
FROM encounter e 
where  e.voided = 0 
AND e.encounter_type in (@historiaClinicaEnc)
AND (
    (@patientId is not null and e.patient_id = @patientId) or
    (@patientId is null and date(e.encounter_datetime) >= @startDate and date(e.encounter_datetime) <= @endDate)
);

create index temp_hc_ei on temp_hc(encounter_id);
create index temp_hc_pi on temp_hc(patient_id);

update temp_hc
set location_name = location_name(location_id);

update temp_hc 
set full_facility_name =
CASE location_name
	when 'Laguna del Cofre' then 'Unidad de Salud (US) Laguna del Cofre'
	when 'Letrero' then 'Unidad de Salud (US) El Letrero'
	when 'Salvador' then 'Casa de Salud Salvador Urbina'
	when 'Soledad' then 'Casa de Salud La Soledad'
	when 'Plan Alta' then 'Casa de Salud Plan de la Libertad'
	when 'Plan Baja' then 'Casa de Salud Plan de la Libertad'
	when 'Matazano' then 'Casa de salud El Matasanos'
	when 'Reforma' then 'Unidad de salud Reforma'
	when 'Capitan' then 'Unidad Médica Rural Capitán Luis A. Vidal'
	when 'Honduras' then 'Casa de Salud Honduras'
	when 'Monterrey' then 'Monterrey'
	when 'Plan de la Libertad' then 'Plan de la Libertad'
	when 'Jaltenango' then 'Unidad de salud Jaltenango de la Paz'
	when 'Surgery' then 'Unidad de salud Jaltenango de la Paz'
	when 'Hospital' then 'Unidad de salud Jaltenango de la Paz'
	when 'CES Oficina' then 'Unidad de salud Jaltenango de la Paz'
	when 'CER' then 'Unidad de salud Jaltenango de la Paz'
	when 'Casa Materna' then 'Unidad de salud Jaltenango de la Paz'
	when 'Patient Home' then 'Unidad de salud Jaltenango de la Paz'
	when 'Pediatría' then 'Unidad de salud Jaltenango de la Paz'
END;


update temp_hc 
set provider = provider(encounter_id);

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
select o.obs_id, o.obs_datetime, o.date_created, o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_numeric, o.value_coded, o.value_datetime, o.value_text, o.value_coded_name_id , o.voided
from obs o
inner join temp_hc t on t.encounter_id = o.encounter_id 
where o.voided = 0;

create index temp_obs_encounter_id on temp_obs(encounter_id);
create index temp_obs_c1 on temp_obs(encounter_id, concept_id);
create index temp_obs_c2 on temp_obs(obs_group_id, concept_id);

set @familyHistory = concept_from_mapping('PIH','10144');
update temp_hc 
set family_history = replace(obs_value_coded_list_from_temp_using_concept_id(encounter_id, @familyHistory, @locale),' | ',', ');

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

set @daily_cigs = concept_from_mapping('PIH','12586');
update temp_hc 
set daily_cigs = obs_value_numeric_from_temp_using_concept_id(encounter_id, @daily_cigs);

set @history_alcohol = concept_from_mapping('PIH','1552');
update temp_hc 
set history_alcohol = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @history_alcohol, @locale);

set @years_smoking = concept_from_mapping('PIH','12998');
update temp_hc 
set years_smoking = obs_value_numeric_from_temp_using_concept_id(encounter_id, @years_smoking);

set @years_alcohol = concept_from_mapping('PIH','2241');
update temp_hc 
set years_alcohol = obs_value_numeric_from_temp_using_concept_id(encounter_id, @years_alcohol);

set @number_transfusions = concept_from_mapping('PIH','13748');
update temp_hc 
set number_transfusions = obs_value_numeric_from_temp_using_concept_id(encounter_id, @number_transfusions);

set @date_transfusion = concept_from_mapping('PIH','11064');
update temp_hc 
set date_transfusion = obs_value_datetime_from_temp_using_concept_id(encounter_id, @date_transfusion);

set @type_transfusion = concept_from_mapping('PIH','7864');
update temp_hc 
set type_transfusion = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @type_transfusion, @locale);

set @number_surgeries = concept_from_mapping('PIH','13768');
update temp_hc 
set number_surgeries = obs_value_numeric_from_temp_using_concept_id(encounter_id, @number_surgeries);

set @date_surgery = concept_from_mapping('PIH','13769');
update temp_hc 
set date_surgery = obs_value_datetime_from_temp_using_concept_id(encounter_id, @date_surgery);

set @type_surgery = concept_from_mapping('PIH','13770');
update temp_hc 
set type_surgery = obs_value_text_from_temp_using_concept_id(encounter_id, @type_surgery);

set @reason_surgery = concept_from_mapping('PIH','13771');
update temp_hc 
set reason_surgery = obs_value_text_from_temp_using_concept_id(encounter_id, @reason_surgery);

set @number_hospitalizations = concept_from_mapping('PIH','12594');
update temp_hc 
set number_hospitalizations = obs_value_numeric_from_temp_using_concept_id(encounter_id, @number_hospitalizations);

set @date_hospitalization = concept_from_mapping('PIH','12240');
update temp_hc 
set date_hospitalization = obs_value_datetime_from_temp_using_concept_id(encounter_id, @date_hospitalization);

set @reason_hospitalization = concept_from_mapping('PIH','11065');
update temp_hc 
set reason_hospitalization = obs_value_text_from_temp_using_concept_id(encounter_id, @reason_hospitalization);

set @other_pathological_history = concept_from_mapping('PIH','13752');
update temp_hc 
set other_pathological_history = obs_value_text_from_temp_using_concept_id(encounter_id, @other_pathological_history);

update temp_hc
set pathological_history = 
CONCAT(
if(daily_cigs is null, '', concat('Número de cigarros por día: ',daily_cigs, '. ')),
if(years_smoking is null, '', concat('Tiempo fumando en años: ', years_smoking, '. ')),
if(history_alcohol is null, '', concat('Ingiere bebidas alcohólicas: ', history_alcohol, '. ')),
if(years_alcohol is null, '', concat('Tiempo tomando bebidas alcoholicas en años: ',years_alcohol, '. ')),
if(number_transfusions is null, '', concat('Número de transfusiones hasta el día de hoy: ',number_transfusions, '. ')),
if(date_transfusion is null, '', concat('Fecha de transfusión: ', date_transfusion, '. ')),
if(type_transfusion is null, '', concat('Tipo de transfusión: ', type_transfusion, '. ')),
if(number_surgeries is null, '', concat('Número de cirugías hasta el día de hoy: ', number_surgeries, '. ')),
if(date_surgery is null, '', concat('Fecha de cirugía: ', date_surgery, '. ')),
if(type_surgery is null, '', concat('Tipo de cirugía: ', type_surgery, '. ')),
if(reason_surgery is null, '', concat('Motivo: ', reason_surgery, '. ')),
if(number_hospitalizations is null, '', concat('Número de hospitalizaciones hasta el día de hoy: ', number_hospitalizations, '. ')),
if(date_hospitalization is null, '', concat('Fecha de hospitalización: ', date_hospitalization, '. ')),
if(reason_hospitalization is null, '', concat('Motivo: ', reason_hospitalization, '. ')),
if(other_pathological_history is null, '', concat('Otros antecedentes patológicos: ', other_pathological_history, '. '))
);

-- obgyn section
set @age_first_menstrual_period = concept_from_mapping('PIH','13121');
update temp_hc 
set age_first_menstrual_period = obs_value_numeric_from_temp_using_concept_id(encounter_id, @age_first_menstrual_period);

set @age_first_sexual_activity = concept_from_mapping('PIH','13250');
update temp_hc 
set age_first_sexual_activity = obs_value_numeric_from_temp_using_concept_id(encounter_id, @age_first_sexual_activity);

set @blood_type = concept_from_mapping('PIH','300');
update temp_hc 
set blood_type = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @blood_type, @locale);

set @menstrual_cycle_details = concept_from_mapping('PIH','14176');
update temp_hc 
set menstrual_cycle_details = obs_value_text_from_temp_using_concept_id(encounter_id, @menstrual_cycle_details);

set @gravida = concept_from_mapping('PIH','5624');
update temp_hc 
set gravida = obs_value_numeric_from_temp_using_concept_id(encounter_id, @gravida);

set @parity = concept_from_mapping('PIH','1053');
update temp_hc 
set parity = obs_value_numeric_from_temp_using_concept_id(encounter_id, @parity);

set @cesarian = concept_from_mapping('PIH','7011');
update temp_hc 
set cesarian = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cesarian);

set @abortions_before_20_weeks = concept_from_mapping('PIH','13733');
update temp_hc 
set abortions_before_20_weeks = obs_value_numeric_from_temp_using_concept_id(encounter_id, @abortions_before_20_weeks);

set @abortions_after_20_weeks = concept_from_mapping('PIH','13734');
update temp_hc 
set abortions_after_20_weeks = obs_value_numeric_from_temp_using_concept_id(encounter_id, @abortions_after_20_weeks);

set @date_previous_pregnancy = concept_from_mapping('PIH','13124');
update temp_hc 
set date_previous_pregnancy = obs_value_datetime_from_temp_using_concept_id(encounter_id, @date_previous_pregnancy);

set @obstetric_notes = concept_from_mapping('PIH','6760');
update temp_hc 
set obstetric_notes = obs_value_text_from_temp_using_concept_id(encounter_id, @obstetric_notes);

set @number_children = concept_from_mapping('PIH','11117');
update temp_hc 
set number_children = obs_value_numeric_from_temp_using_concept_id(encounter_id, @number_children);

set @lmp_date = concept_from_mapping('PIH','968');
update temp_hc 
set lmp_date = obs_value_datetime_from_temp_using_concept_id(encounter_id, @lmp_date);

set @has_had_menopause = concept_from_mapping('PIH','14188');
update temp_hc 
set has_had_menopause = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @has_had_menopause, @locale);

set @age_of_menopause = concept_from_mapping('PIH','14189');
update temp_hc 
set age_of_menopause = obs_value_numeric_from_temp_using_concept_id(encounter_id, @age_of_menopause);

set @sti_notes = concept_from_mapping('PIH','1374');
update temp_hc 
set sti_notes = obs_value_text_from_temp_using_concept_id(encounter_id, @sti_notes);

set @family_planning_notes = concept_from_mapping('PIH','5281');
update temp_hc 
set family_planning_notes = obs_value_text_from_temp_using_concept_id(encounter_id, @family_planning_notes);

set @fp_method = concept_from_mapping('PIH','374');
update temp_hc 
set fp_method = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @fp_method, @locale);

set @pap_smear = concept_from_mapping('PIH','11319');
update temp_hc 
set pap_smear = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @pap_smear, @locale);

set @breast_exam = concept_from_mapping('PIH','14180');
update temp_hc 
set breast_exam = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @breast_exam, @locale);

-- pap smear 
set @pap_smear = concept_from_mapping('PIH','885');
drop temporary table if exists temp_pap_smear_groups;
create temporary table temp_pap_smear_groups
SELECT distinct encounter_id, obs_group_id
FROM temp_obs 
where value_coded = @pap_smear;

create index temp_pap_smear_groups_gi on temp_pap_smear_groups(obs_group_id); 

set @proc_datetime = concept_from_mapping('PIH','10485');
update temp_hc t 
set t.latest_pap_smear_date =
	(select max(value_datetime) 
	from temp_obs o
	inner join temp_pap_smear_groups g on g.obs_group_id = o.obs_group_id
	where o.encounter_id = t.encounter_id
	and o.concept_id = @proc_datetime);

update temp_hc t
set pap_smear_obs_group_id = 
	(select max(o.obs_group_id) from temp_obs o
	where o.encounter_id = t.encounter_id
	and o.concept_id = @proc_datetime
	and o.value_datetime = latest_pap_smear_date);

update temp_hc t
set pap_smear_result = obs_from_group_id_value_coded_list_from_temp(pap_smear_obs_group_id, 'PIH','885', @locale);

update temp_hc t
set pap_smear_comments = obs_from_group_id_value_text_from_temp(pap_smear_obs_group_id, 'PIH','10483');

-- breast exam
set @breast_exam = concept_from_mapping('PIH','20864');
drop temporary table if exists temp_breast_exam_groups;
create temporary table temp_breast_exam_groups
SELECT distinct encounter_id, obs_group_id
FROM temp_obs 
where value_coded = @breast_exam;

create index temp_breast_exam_groups_gi on temp_breast_exam_groups(obs_group_id); 

set @proc_datetime = concept_from_mapping('PIH','10485');
update temp_hc t 
set t.latest_breast_exam_date =
	(select max(value_datetime) 
	from temp_obs o
	inner join temp_breast_exam_groups g on g.obs_group_id = o.obs_group_id
	where o.encounter_id = t.encounter_id
	and o.concept_id = @proc_datetime);

update temp_hc t
set breast_exam_obs_group_id = 
	(select max(o.obs_group_id) from temp_obs o
	where o.encounter_id = t.encounter_id
	and o.concept_id = @proc_datetime
	and o.value_datetime = latest_breast_exam_date);

update temp_hc t
set breast_exam_comments = obs_from_group_id_value_text_from_temp(breast_exam_obs_group_id, 'PIH','10483');

update temp_hc
set gyn_history = 
CONCAT(
if(age_first_menstrual_period is null, '', concat('Edad de menarca: ', age_first_menstrual_period, '. ')),
if(age_first_sexual_activity is null, '', concat('Edad que inicio su vida sexual activa: ', age_first_sexual_activity, '. ')),
if(blood_type is null, '', concat('Tipo de sangre: ', blood_type, '. ')),
if(menstrual_cycle_details is null, '', concat('Ciclo menstrual: ', menstrual_cycle_details, '. ')),
if(gravida is null, '', concat('Gravida (G): ', gravida, '. ')),
if(parity is null, '', concat('Parity (P): ', parity, '. ')),
if(cesarian is null, '', concat('Cesarian (C): ', cesarian, '. ')),
if(abortions_before_20_weeks is null, '', concat('Perdidas menores de 20 SDG: ', abortions_before_20_weeks, '. ')),
if(abortions_after_20_weeks is null, '', concat('Perdidas mayores de 20 SDG: ', abortions_after_20_weeks, '. ')),
if(date_previous_pregnancy is null, '', concat('Fecha de último evento obstétrico: ', date_previous_pregnancy, '. ')),
if(obstetric_notes is null, '', concat('Notas : ', obstetric_notes, '. ')),
if(number_children is null, '', concat('Número de hijos: ', number_children, '. ')),
if(lmp_date is null, '', concat('FUM: ', lmp_date, '. ')),
if(has_had_menopause is null, '', concat('Ha pasado por la menopausia: ', has_had_menopause, '. ')),
if(age_of_menopause is null, '', concat('Edad que tuvo menopasia: ', age_of_menopause, '. ')),
if(sti_notes is null, '', concat('Enfermedades de transmisión sexual: ', sti_notes, '. ')),
if(family_planning_notes is null, '', concat('Método de planificación familiar usados: ', family_planning_notes, '. ')),
if(fp_method is null, '', concat('Método de planificación familiar usado actualmente: ', fp_method, '. ')),
if(pap_smear is null, '', concat('Se ha hecho examen de papanicolaou: ', pap_smear, '. ')),
if(latest_pap_smear_date is null, '', concat('última fecha de la prueba de papanicolaou: ', latest_pap_smear_date, '. ')),
if(pap_smear_result is null, '', concat('último resultado de la prueba de papanicolaou: ', pap_smear_result, '. ')),
if(pap_smear_comments is null, '', concat('comentarios sobre la prueba de Papanicolaou: ', pap_smear_comments, '. ')),
if(breast_exam is null, '', concat('Se ha hecho exploración de mama: ', breast_exam, '. ')),
if(latest_breast_exam_date is null, '', concat('última fecha del examen de mama: ', latest_breast_exam_date, '. ')),
if(breast_exam_comments is null, '', concat('comentarios sobre el examen de mama: ', breast_exam_comments, '. '))
);

set @main_symptom = concept_from_mapping('PIH','10137');
update temp_hc 
set main_symptom = obs_value_text_from_temp_using_concept_id(encounter_id, @main_symptom);

set @evolution_symptoms = concept_from_mapping('PIH','10898');
update temp_hc 
set evolution_symptoms = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @evolution_symptoms, @locale);


set @digestive = concept_from_mapping('PIH','13757');
update temp_hc 
set digestive = obs_value_text_from_temp_using_concept_id(encounter_id, @digestive);

set @respiratory = concept_from_mapping('PIH','13758');
update temp_hc 
set respiratory = obs_value_text_from_temp_using_concept_id(encounter_id, @respiratory);

set @genital = concept_from_mapping('PIH','13760');
update temp_hc 
set genital = obs_value_text_from_temp_using_concept_id(encounter_id, @genital);

set @urinary = concept_from_mapping('PIH','13759');
update temp_hc 
set urinary = obs_value_text_from_temp_using_concept_id(encounter_id, @urinary);

update temp_hc
set genitourinary = 
CONCAT(
if(genital is null, '', concat('Aparato genital: ', genital, '. ')),
if(urinary is null, '', concat('Aparato urinario: ', urinary, '. ')));

set @cardiovascular = concept_from_mapping('PIH','13761');
update temp_hc 
set cardiovascular = obs_value_text_from_temp_using_concept_id(encounter_id, @cardiovascular);

set @nervous_system = concept_from_mapping('PIH','13762');
update temp_hc 
set nervous_system = obs_value_text_from_temp_using_concept_id(encounter_id, @nervous_system);

set @endocrine = concept_from_mapping('PIH','13764');
update temp_hc 
set endocrine = obs_value_text_from_temp_using_concept_id(encounter_id, @endocrine);

set @locomotor = concept_from_mapping('PIH','13763');
update temp_hc 
set locomotor = obs_value_text_from_temp_using_concept_id(encounter_id, @locomotor);


set @head = concept_from_mapping('PIH','10466');
update temp_hc 
set head = obs_value_text_from_temp_using_concept_id(encounter_id, @head);

set @neck = concept_from_mapping('PIH','12900');
update temp_hc 
set neck = obs_value_text_from_temp_using_concept_id(encounter_id, @neck);

set @chest = concept_from_mapping('PIH','10471');
update temp_hc 
set chest = obs_value_text_from_temp_using_concept_id(encounter_id, @chest);

set @abdomen = concept_from_mapping('PIH','10469');
update temp_hc 
set abdomen = obs_value_text_from_temp_using_concept_id(encounter_id, @abdomen);

set @extremities = concept_from_mapping('PIH','13754');
update temp_hc 
set extremities = obs_value_text_from_temp_using_concept_id(encounter_id, @extremities);

set @otros_exam = concept_from_mapping('PIH','10468');
update temp_hc 
set otros_exam = obs_value_text_from_temp_using_concept_id(encounter_id, @otros_exam);

set @diagnoses = concept_from_mapping('PIH','3064');
update temp_hc 
set diagnoses = replace(obs_value_coded_list_from_temp_using_concept_id(encounter_id, @diagnoses, @locale),' | ',', ');

-- columns from vitals

drop temporary table if exists temp_vitals_visits;
create temporary table temp_vitals_visits
select distinct visit_id from temp_hc;

drop temporary table if exists temp_vitals_encounters;
create temporary table temp_vitals_encounters
select e.encounter_id, e.visit_id, e.encounter_datetime 
from encounter e 
inner join temp_vitals_visits v on v.visit_id = e.visit_id
where e.voided = 0
and e.encounter_type = @vitalsEnc;

update temp_hc t
inner join encounter e on e.encounter_id = 
(select v.encounter_id FROM temp_vitals_encounters v
where v.visit_id = t.visit_id 
order by v.encounter_datetime desc, v.encounter_id desc limit 1)
set t.vitals_encounter_id = e.encounter_id;

create index temp_hc_vei on temp_hc(vitals_encounter_id);

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.obs_datetime, o.date_created, o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_numeric, o.value_coded, o.value_datetime, o.value_text, o.value_coded_name_id , o.voided
from obs o
inner join temp_hc t on t.vitals_encounter_id = o.encounter_id 
where o.voided = 0;

set @temp = concept_from_mapping('PIH','5088');
update temp_hc 
set temp = obs_value_numeric_from_temp_using_concept_id(vitals_encounter_id, @temp);

set @bp_systolic = concept_from_mapping('PIH','5085');
update temp_hc 
set bp_systolic = obs_value_numeric_from_temp_using_concept_id(vitals_encounter_id, @bp_systolic);

set @bp_diastolic = concept_from_mapping('PIH','5086');
update temp_hc 
set bp_diastolic = obs_value_numeric_from_temp_using_concept_id(vitals_encounter_id, @bp_diastolic);

update temp_hc
set bp = 
CONCAT(
if(bp_systolic is null, '', concat(bp_systolic, '/', bp_diastolic)));

set @weight = concept_from_mapping('PIH','5089');
update temp_hc 
set weight = obs_value_numeric_from_temp_using_concept_id(vitals_encounter_id, @weight);

set @height = concept_from_mapping('PIH','5090');
update temp_hc 
set height = obs_value_numeric_from_temp_using_concept_id(vitals_encounter_id, @height);

set @hr = concept_from_mapping('PIH','5087');
update temp_hc 
set hr = obs_value_numeric_from_temp_using_concept_id(vitals_encounter_id, @hr);

set @rr = concept_from_mapping('PIH','5242');
update temp_hc 
set rr = obs_value_numeric_from_temp_using_concept_id(vitals_encounter_id, @rr);

-- sheet name
update temp_hc set sheet_name = if(@patientId is null, concat(lastname, '-'), '');
update temp_hc set sheet_name = concat(sheet_name, date_format(encounter_date, '%Y-%m-%d'), ' ', encounter_id);

select
encounter_id,
encounter_date,
sheet_name,
full_facility_name, 
location_name, 
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
bp, 
weight, 
height, 
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
provider,
latest_pap_smear_date,
pap_smear_result,
pap_smear_comments,
latest_breast_exam_date,
breast_exam_obs_group_id,
breast_exam_comments
from temp_hc;
