-- set @startDate = '2021-03-18';
-- set @endDate = '2021-03-20';

SET @locale = GLOBAL_PROPERTY_VALUE('default_locale', 'es');

DROP TEMPORARY TABLE IF EXISTS temp_vitals;
CREATE TEMPORARY TABLE temp_vitals
(
    encounter_id				INT primary key,
    patient_id					INT,
    visit_id					INT,
    encounter_datetime			DATETIME,
    date_created                DATETIME,
    creator                     INT,
    entered_by          		VARCHAR(255),
    encounter_location			VARCHAR(255),
    age_at_encounter			INT,
    emr_id						VARCHAR(50),
    birthdate					DATETIME,
	gender						VARCHAR(50),
    height_cm					DOUBLE,
	weight_kg					DOUBLE,
    bmi						    DOUBLE,
    head_circumference          DOUBLE,
    systolic_bp	     			DOUBLE,
    diastolic_bp	 			DOUBLE,
    o2_sat						DOUBLE,
    glucose_fasting             BOOLEAN,
    glucose_mg_dl               DOUBLE,
    temp_c						DOUBLE,
    heart_rate					DOUBLE,
    resp_rate					DOUBLE,
    phq_2                       DOUBLE,
    gad_2                       DOUBLE,
    chief_complaint             TEXT
);
create index temp_vitals_patient_idx on temp_vitals(patient_id);
create index temp_vitals_encounter_idx on temp_vitals(encounter_id);

set @vitalsEncounterType = encounter_type('4fb47712-34a6-40d2-8ed3-e153abbd25b7');

-- Load all vitals encounters in the given date range

insert into temp_vitals
    (encounter_id, patient_id, visit_id, encounter_datetime, date_created, creator)
select
    e.encounter_id, e.patient_id, e.visit_id, e.encounter_datetime, e.date_created, e.creator
from encounter e
inner join patient p on e.patient_id = p.patient_id
where e.voided = 0 and p.voided = 0
and e.encounter_type = @vitalsEncounterType
and date(encounter_datetime) >= @startDate
and date(encounter_datetime) <= @endDate
;

-- Populate encounter and demographic columns
update temp_vitals set entered_by = person_name_of_user(creator);
update temp_vitals set encounter_location = encounter_location_name(encounter_id);
update temp_vitals set age_at_encounter = age_in_full_years_on_date(patient_id, encounter_datetime);
update temp_vitals set emr_id = primary_emr_id(patient_id);
update temp_vitals set birthdate = birthdate(patient_id);
update temp_vitals set gender = gender(patient_id);

-- Populate data collected on vitals form

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs
select o.obs_id, o.obs_datetime, o.date_created, o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_numeric, o.value_coded, o.value_datetime, o.value_text, o.value_coded_name_id , o.voided
from obs o inner join temp_vitals t on t.encounter_id = o.encounter_id
where o.voided = 0;

create index temp_obs_encounter_id on temp_obs(encounter_id);
create index temp_obs_c1 on temp_obs(encounter_id, concept_id);

update temp_vitals set height_cm = obs_value_numeric_from_temp(encounter_id, 'PIH', 'HEIGHT (CM)');
update temp_vitals set weight_kg = obs_value_numeric_from_temp(encounter_id, 'PIH', 'WEIGHT (KG)');
update temp_vitals set bmi = if(weight_kg is null or height_cm is null, null, round(weight_kg / ((height_cm / 100) * (height_cm / 100)), 1));
update temp_vitals set head_circumference = obs_value_numeric_from_temp(encounter_id, 'PIH', 'HEAD CIRCUMFERENCE');
update temp_vitals set systolic_bp = obs_value_numeric_from_temp(encounter_id, 'PIH', 'SYSTOLIC BLOOD PRESSURE');
update temp_vitals set diastolic_bp = obs_value_numeric_from_temp(encounter_id, 'PIH', 'DIASTOLIC BLOOD PRESSURE');
update temp_vitals set o2_sat = obs_value_numeric_from_temp(encounter_id, 'PIH', 'BLOOD OXYGEN SATURATION');
update temp_vitals set glucose_fasting = obs_value_coded_as_boolean_from_temp(encounter_id, 'PIH', 'Fasting for blood glucose test');
update temp_vitals set glucose_mg_dl = obs_value_numeric_from_temp(encounter_id, 'PIH', 'SERUM GLUCOSE');
update temp_vitals set temp_c = obs_value_numeric_from_temp(encounter_id, 'PIH', 'TEMPERATURE (C)');
update temp_vitals set heart_rate = obs_value_numeric_from_temp(encounter_id, 'PIH', 'PULSE');
update temp_vitals set resp_rate = obs_value_numeric_from_temp(encounter_id, 'PIH', 'RESPIRATORY RATE');
update temp_vitals set phq_2 = obs_value_numeric_from_temp(encounter_id, 'PIH', 'PHQ-2');
update temp_vitals set gad_2 = obs_value_numeric_from_temp(encounter_id, 'PIH', 'GAD-2');
update temp_vitals set chief_complaint = obs_value_text(encounter_id, 'CIEL', '160531');

alter table temp_vitals drop column creator;
select * from temp_vitals;