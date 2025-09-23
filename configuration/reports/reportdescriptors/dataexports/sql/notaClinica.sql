set @startDate = '2025-01-01';
set @endDate = '2025-09-30';
-- set @patientId = 2337;

set SESSION group_concat_max_len = 1000000;
set @locale = global_property_value('default_locale', 'es');
set @mexConsultEnc = encounter_type('aa61d509-6e76-4036-a65d-7813c0c3b752');
set @mexRegistrationEnc = encounter_type('873f968a-73a8-4f9c-ac78-9f4778b751b6');
set @vitalsEnc = encounter_type('4fb47712-34a6-40d2-8ed3-e153abbd25b7');

-- Start out by building temporary tables representing the encounters and obs that are included in this export

drop temporary table if exists temp_encounters;
create temporary table temp_encounters
(
    encounter_id               int primary key,
    visit_id                   int,
    patient_id                 int,
    encounter_date             datetime,
    patient_name               varchar(255),
    birthdate                  date,
    age_years                  int,
    age_months                 int,
    age_days                   int,
    gender                     varchar(10),
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
    glucose_mg_dl              double
);

-- Include all encounters in the given date range and/or limited by patient
insert into temp_encounters (encounter_id, visit_id, patient_id, encounter_date)
select e.encounter_id, e.visit_id, e.patient_id, e.encounter_datetime
from encounter e
inner join patient p on e.patient_id = p.patient_id
where e.voided = 0 and p.voided = 0
  and e.encounter_type in (@mexConsultEnc)
  and (
    (@patientId is not null and e.patient_id = @patientId) or
    (@patientId is null and date(e.encounter_datetime) >= @startDate and date(e.encounter_datetime) <= @endDate)
  )
;
create index temp_encounters_patient_idx on temp_encounters(patient_id);
create index temp_encounters_visit_idx on temp_encounters(visit_id);

-- Populate demographic data

update temp_encounters set patient_name = trim(person_name(patient_id));
update temp_encounters set birthdate = birthdate(patient_id);
update temp_encounters set age_years = age_in_full_years_on_date(patient_id, encounter_date);
update temp_encounters set age_months = age_in_months_since_last_full_year_on_date(patient_id, encounter_date);
update temp_encounters set age_days = age_in_days_since_last_full_month_on_date(patient_id, encounter_date);
update temp_encounters set gender = gender(patient_id);
update temp_encounters set gender = if(gender = 'M', 'MASCULINO', if(gender = 'F', 'FEMININO', null));

-- Load each patient's most recent registration encounter information

update temp_encounters te set te.registration_encounter_id = (
    select e.encounter_id
    from encounter e
    where e.patient_id = te.patient_id
    and e.encounter_type = @mexRegistrationEnc
    and e.voided = 0
    order by encounter_date desc
    limit 1
);
create index temp_encounters_reg_enc_idx on temp_encounters(registration_encounter_id);
update temp_encounters set registration_location_name = encounter_location_name(registration_encounter_id);
update temp_encounters set insurance_policy_number = obs_value_text(registration_encounter_id, 'PIH', 'Insurance policy number');

-- Load vitals encounter from same visit as consult
update temp_encounters te set te.vitals_encounter_id = (
    select e.encounter_id
    from encounter e
    where e.visit_id = te.visit_id
      and e.encounter_type = @vitalsEnc
      and e.voided = 0
    order by encounter_date desc
    limit 1
);
create index temp_encounters_vitals_enc_idx on temp_encounters(vitals_encounter_id);

drop temporary table if exists temp_obs;
create temporary table temp_obs
select o.obs_id, o.obs_datetime, o.date_created, o.obs_group_id, o.encounter_id, o.person_id, o.concept_id, o.value_numeric, o.value_coded, o.value_datetime, o.value_text, o.value_coded_name_id, o.voided
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

select * from temp_encounters;