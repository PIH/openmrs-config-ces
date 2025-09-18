set @startDate = '2025-01-01';
set @endDate = '2025-09-30';
-- set @patientId = 2337;

set SESSION group_concat_max_len = 1000000;
set @locale = global_property_value('default_locale', 'es');
set @mexConsultEnc = encounter_type('aa61d509-6e76-4036-a65d-7813c0c3b752');
set @mexRegistrationEnc = encounter_type('873f968a-73a8-4f9c-ac78-9f4778b751b6');

-- Start out by building temporary tables representing the encounters and obs that are included in this export

drop temporary table if exists temp_encounters;
create temporary table temp_encounters
(
    encounter_id               int,
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
    insurance_policy_number    varchar(255)
);

-- Include all encounters in the given date range and/or limited by patient
insert into temp_encounters (encounter_id, patient_id, encounter_date)
select e.encounter_id, e.patient_id, e.encounter_datetime
from encounter e
inner join patient p on e.patient_id = p.patient_id
where e.voided = 0 and p.voided = 0
  and e.encounter_type in (@mexConsultEnc)
  and (
    (@patientId is not null and e.patient_id = @patientId) or
    (@patientId is null and date(e.encounter_datetime) >= @startDate and date(e.encounter_datetime) <= @endDate)
  )
;

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
update temp_encounters set registration_location_name = encounter_location_name(registration_encounter_id);
update temp_encounters set insurance_policy_number = obs_value_text(registration_encounter_id, 'PIH', 'Insurance policy number');

select * from temp_encounters;