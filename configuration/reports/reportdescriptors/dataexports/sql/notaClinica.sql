set @startDate = '2025-01-01';
set @endDate = '2025-09-30';
-- set @patientId = 2337;

set SESSION group_concat_max_len = 1000000;
set @locale = global_property_value('default_locale', 'es');
SET @mexConsultEnc = encounter_type('aa61d509-6e76-4036-a65d-7813c0c3b752');
-- set @ = concept_from_mapping('PIH', '');

-- Start out by building temporary tables representing the encounters and obs that are included in this export

drop temporary table if exists temp_encounters;
create temporary table temp_encounters
(
    encounter_id   int,
    patient_id     int,
    encounter_date datetime,
    patient_name   varchar(255),
    birthdate      date,
    age_years      int,
    age_months     int,
    age_days       int,
    gender         varchar(10)
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

select * from temp_encounters;