set @startDate = '2025-01-01';
set @endDate = '2025-09-30';
SET SESSION group_concat_max_len = 1000000;
set @locale =   global_property_value('default_locale', 'es');

drop temporary table if exists temp_encounters;
create temporary table temp_encounters
(
    encounter_id               int primary key,
    patient_id                 int,
    visit_id                   int,
    encounter_datetime         datetime,
    encounter_date             date,
    location_id                int,
    encounter_location         varchar(255),
    unidad_medica              varchar(255),
    provider                   varchar(255),
    patient_name               varchar(255),
    age_years                  int,
    age_months                 int,
    age_days                   int,
    birthdate                  date,
    gender                     char(1),
    gender_display             varchar(10),
    registration_encounter_id  int,
    registration_location_name varchar(255),
    insurance_policy_number    varchar(255),
    vitals_encounter_id        int,
    weight_kg                  double,
    height_cm                  double,
    height_m                   double,
    bmi                        double,
    systolic                   int,
    diastolic                  int,
    heart_rate                 int,
    respiratory_rate           int,
    temp_c                     double,
    glucose_mg_dl              double,
    subjective                 text,
    analysis                   text,
    physical_exam              text,
    physical_exam_line         text,
    ultrasound_type            varchar(1000),
    ultrasound_notes           text,
    ultrasound_line            text,
    glucose_fasting            varchar(255),
    hba1c                      varchar(255),
    proteinuria                varchar(255),
    glucose_line               text,
    cholesterol                double,
    hdl                        double,
    ldl                        double,
    cholesterol_line           text,
    test_results               text,
    diagnoses                  text,
    plan                       text,
    diagnoses_and_plan         text,
    treatment                  text
);

-- Load all consult encounters during the report time period

SET @consultEncounterType = encounter_type('aa61d509-6e76-4036-a65d-7813c0c3b752');

insert into temp_encounters (patient_id, visit_id, encounter_id, encounter_datetime, location_id)
select e.patient_id, e.visit_id, e.encounter_id, e.encounter_datetime, e.location_id
FROM encounter e
inner join patient p on e.patient_id = p.patient_id
where e.voided = 0  and p.voided = 0
AND e.encounter_type in (@consultEncounterType)
AND date(e.encounter_datetime) >= @startDate
AND date(e.encounter_datetime) <= @endDate
;
CREATE INDEX temp_encounters_e on temp_encounters(encounter_id);
create index temp_encounters_v on temp_encounters(visit_id);

-- Populate base demographic and encounter data

update temp_encounters set encounter_date = date(encounter_datetime);
update temp_encounters set encounter_location = encounter_location_name(location_id);
update temp_encounters set provider = provider(encounter_id);
update temp_encounters set patient_name = trim(person_name(patient_id));
update temp_encounters set birthdate = birthdate(patient_id);
update temp_encounters set age_years = age_in_full_years_on_date(patient_id, encounter_date);
update temp_encounters set age_months = age_in_months_since_last_full_year_on_date(patient_id, encounter_date);
update temp_encounters set age_days = age_in_days_since_last_full_month_on_date(patient_id, encounter_date);
update temp_encounters set gender = gender(patient_id);
update temp_encounters set gender_display = if(gender = 'M', 'MASCULINO', if(gender = 'F', 'FEMININO', null));

update temp_encounters set unidad_medica =
CASE encounter_location
   when 'Honduras' then 'Casa de Salud Honduras'
   when 'Laguna del Cofre' then 'CSR Laguna del Cofre'
   when 'Capitan' then 'Unidad Médica Rural Capitán Luis A. Vidal'
   when 'Letrero' then 'CSR El Letrero'
   when 'CSR El Letrero' then 'Casa de Salud Salvador Urbina'
   when 'Soledad' then 'Casa de Salud La Soledad'
   when 'Matazano ' then 'ESI El Matasanos'
   when 'Plan Alta' then 'Casa de Salud Plan de la Libertad'
   when 'Plan Baja' then 'Casa de Salud Plan de la Libertad'
   when 'Reforma' then 'CSR Reforma'
END;

-- Populate data from the patient's most recent registration encounter

set @registrationEncounterType = encounter_type('873f968a-73a8-4f9c-ac78-9f4778b751b6');

update temp_encounters te set te.registration_encounter_id = (
    select e.encounter_id
    from encounter e
    where e.patient_id = te.patient_id
      and e.encounter_type = @registrationEncounterType
      and e.voided = 0
    order by encounter_date desc
    limit 1
);

create index temp_encounters_reg_enc_idx on temp_encounters(registration_encounter_id);

update temp_encounters set registration_location_name = encounter_location_name(registration_encounter_id);
update temp_encounters set insurance_policy_number = obs_value_text(registration_encounter_id, 'PIH', 'Insurance policy number');

-- Populate data from the most recent vitals encounter within the same visit as each consult

SET @vitalsEncounterType = encounter_type('4fb47712-34a6-40d2-8ed3-e153abbd25b7');

update temp_encounters te set te.vitals_encounter_id = (
    select e.encounter_id
    from encounter e
    where e.visit_id = te.visit_id
      and e.encounter_type = @vitalsEncounterType
      and e.voided = 0
    order by e.encounter_datetime desc
    limit 1
);

create index temp_encounters_ve on temp_encounters(vitals_encounter_id);

drop temporary table if exists temp_obs;
create temporary table temp_obs
select o.obs_id, o.obs_datetime, o.date_created, o.obs_group_id, o.encounter_id, o.person_id, o.concept_id,
       o.value_numeric, o.value_coded, o.value_drug, o.value_datetime, o.value_text, o.value_coded_name_id, o.comments, o.voided
from obs o inner join temp_encounters t on t.vitals_encounter_id = o.encounter_id
where o.voided = 0;

create index temp_obs_encounter_idx on temp_obs(encounter_id);
create index temp_obs_concept_idx on temp_obs(encounter_id, concept_id);

update temp_encounters set weight_kg = obs_value_numeric_from_temp(vitals_encounter_id, 'PIH', 'WEIGHT (KG)');
update temp_encounters set height_cm = obs_value_numeric_from_temp(vitals_encounter_id, 'PIH', 'HEIGHT (CM)');
update temp_encounters set height_m = if(height_cm is null, null, height_cm / 100);
update temp_encounters set bmi = if(weight_kg is null or height_m is null, null, round(weight_kg / (height_m * height_m), 1));
update temp_encounters set systolic = obs_value_numeric_from_temp(vitals_encounter_id, 'PIH', 'SYSTOLIC BLOOD PRESSURE');
update temp_encounters set diastolic = obs_value_numeric_from_temp(vitals_encounter_id, 'PIH', 'DIASTOLIC BLOOD PRESSURE');
update temp_encounters set heart_rate = obs_value_numeric_from_temp(vitals_encounter_id, 'PIH', 'PULSE');
update temp_encounters set respiratory_rate = obs_value_numeric_from_temp(vitals_encounter_id, 'PIH', 'RESPIRATORY RATE');
update temp_encounters set temp_c = obs_value_numeric_from_temp(vitals_encounter_id, 'PIH', 'TEMPERATURE (C)');
update temp_encounters set glucose_mg_dl = obs_value_numeric_from_temp(vitals_encounter_id, 'PIH', 'SERUM GLUCOSE');

-- Load observations from consult encounter

drop temporary table if exists temp_obs;
create temporary table temp_obs
select o.obs_id, o.obs_datetime, o.date_created, o.obs_group_id, o.encounter_id, o.person_id, o.concept_id,
       o.value_numeric, o.value_coded, o.value_drug, o.value_datetime, o.value_text, o.value_coded_name_id, o.comments, o.voided
from obs o inner join temp_encounters t on t.encounter_id = o.encounter_id
where o.voided = 0;

create index temp_obs_encounter_idx on temp_obs(encounter_id);
create index temp_obs_concept_idx on temp_obs(encounter_id, concept_id);

update temp_encounters set subjective = obs_value_text_from_temp(encounter_id, 'PIH', 'PRESENTING HISTORY');
update temp_encounters set subjective = if(subjective is null, null, concat('S: ', subjective));

update temp_encounters set analysis = obs_value_text_from_temp(encounter_id, 'PIH','CLINICAL IMPRESSION COMMENTS');

update temp_encounters set physical_exam = obs_value_text_from_temp(encounter_id, 'PIH', 'PHYSICAL EXAMINATION');
update temp_encounters set physical_exam_line = concat('Exploración Física: ', physical_exam) where physical_exam is not null;
update temp_encounters set ultrasound_type = obs_value_coded_list_from_temp(encounter_id, 'PIH','14068',@locale);
update temp_encounters set ultrasound_notes = obs_value_text_from_temp(encounter_id, 'PIH','7018');
update temp_encounters set ultrasound_line = concat(if(ultrasound_line is null, '', concat(ultrasound_line, ', ')), ultrasound_type) where ultrasound_type is not null;
update temp_encounters set ultrasound_line = concat(if(ultrasound_line is null, '', concat(ultrasound_line, ', ')), ultrasound_notes) where ultrasound_notes is not null;
update temp_encounters set ultrasound_line = concat('Ultrasonido: ', ultrasound_line) where ultrasound_line is not null;
update temp_encounters set glucose_mg_dl = obs_value_numeric_from_temp(encounter_id, 'PIH','SERUM GLUCOSE') where glucose_mg_dl is null;
update temp_encounters set glucose_fasting = obs_value_coded_list_from_temp(encounter_id, 'PIH','Fasting for blood glucose test', @locale);
update temp_encounters set hba1c = obs_value_numeric_from_temp(encounter_id, 'PIH','HbA1c');
update temp_encounters set proteinuria = obs_value_numeric_from_temp(encounter_id, 'PIH','URINARY ALBUMIN');
update temp_encounters set glucose_line = concat('Glucosa: ', glucose_mg_dl) where glucose_mg_dl is not null;
update temp_encounters set glucose_line = concat(if(glucose_line is null, '', concat(glucose_line, ', ')), concat('Ayuno: ', glucose_fasting)) where glucose_fasting is not null;
update temp_encounters set glucose_line = concat(if(glucose_line is null, '', concat(glucose_line, ', ')), concat('Hba1c: ', hba1c)) where hba1c is not null;
update temp_encounters set glucose_line = concat(if(glucose_line is null, '', concat(glucose_line, ', ')), concat('Proteinuria: ', proteinuria)) where proteinuria is not null;
update temp_encounters set cholesterol = obs_value_numeric_from_temp(encounter_id, 'PIH','1006');
update temp_encounters set hdl = obs_value_numeric_from_temp(encounter_id, 'PIH','1007');
update temp_encounters set ldl = obs_value_numeric_from_temp(encounter_id, 'PIH','1008');
update temp_encounters set cholesterol_line = concat('Colesterol: ', cholesterol) where cholesterol is not null;
update temp_encounters set cholesterol_line = concat(if(cholesterol_line is null, '', concat(cholesterol_line, ', ')), concat('HDL: ', hdl)) where hdl is not null;
update temp_encounters set cholesterol_line = concat(if(cholesterol_line is null, '', concat(cholesterol_line, ', ')), concat('LDL: ', ldl)) where ldl is not null;
update temp_encounters set test_results = physical_exam_line where physical_exam_line is not null;
update temp_encounters set test_results = concat(if(test_results is null, '', '\n'), ultrasound_line) where ultrasound_line is not null;
update temp_encounters set test_results = concat(if(test_results is null, '', '\n'), glucose_line) where glucose_line is not null;
update temp_encounters set test_results = concat(if(test_results is null, '', '\n'), cholesterol_line) where cholesterol_line is not null;

set @diagnosisConcept = concept_from_mapping('PIH','DIAGNOSIS');
update temp_encounters e
inner join (
    select encounter_id, group_concat(concat(concept_name(value_coded,@locale), ' ', retrieveICD10(value_coded)) separator ', ') as dx
    from temp_obs
    where concept_id = @diagnosisConcept
    group by encounter_id
) o on e.encounter_id = o.encounter_id
set e.diagnoses = o.dx
;
update temp_encounters set plan = obs_value_text_from_temp(encounter_id, 'PIH',10534);
update temp_encounters set diagnoses_and_plan = concat('Diagnóstico: ', diagnoses) where diagnoses is not null;
update temp_encounters set diagnoses_and_plan = concat(if(diagnoses_and_plan is null, '', concat(diagnoses_and_plan, '\n')), concat('Indicaciones Médicas: ', plan)) where plan is not null;

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
    dose_2_evening varchar(255),
    dose_1_text varchar(1000),
    dose_2_text varchar(1000),
    display_text text
);

# Populate meds
insert into temp_meds (encounter_id, obs_group_id) select encounter_id, obs_id from temp_obs where concept_id = @medicationGroup;
create index temp_meds_encounter_idx on temp_obs(encounter_id);
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
update temp_meds set dose_1_text = concat('Dosis 1: ', dose_1, if(dose_1_units is null, '', concat(' ', dose_1_units))) where dose_1 is not null;
update temp_meds set dose_1_text = concat(dose_1_text, ', Mañana: ', dose_1_morning) where dose_1_morning is not null;
update temp_meds set dose_1_text = concat(dose_1_text, ', Medio dia: ', dose_1_noon) where dose_1_noon is not null;
update temp_meds set dose_1_text = concat(dose_1_text, ', Tarde: ', dose_1_afternoon) where dose_1_afternoon is not null;
update temp_meds set dose_1_text = concat(dose_1_text, ', Noche: ', dose_1_evening) where dose_1_evening is not null;
update temp_meds set dose_2_text = concat('Dosis 2: ', dose_2, if(dose_2_units is null, '', concat(' ', dose_2_units))) where dose_2 is not null;
update temp_meds set dose_2_text = concat(dose_2_text, ', Mañana: ', dose_2_morning) where dose_2_morning is not null;
update temp_meds set dose_2_text = concat(dose_2_text, ', Medio dia: ', dose_2_noon) where dose_2_noon is not null;
update temp_meds set dose_2_text = concat(dose_2_text, ', Tarde: ', dose_2_afternoon) where dose_2_afternoon is not null;
update temp_meds set dose_2_text = concat(dose_2_text, ', Noche: ', dose_2_evening) where dose_2_evening is not null;
update temp_meds set display_text = concat(name, ': ', dose_1_text, if(dose_2_text is null, '', concat(', ', dose_2_text)));

update temp_encounters e
    inner join (
        select encounter_id, group_concat(display_text separator ', ') as treatment
        from temp_meds
        group by encounter_id
    ) o on e.encounter_id = o.encounter_id
set e.treatment = o.treatment;

-- final output of all columns needed
select * from temp_encounters;
