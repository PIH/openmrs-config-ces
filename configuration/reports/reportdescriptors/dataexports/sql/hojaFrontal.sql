-- set @startDate = '2023-03-20';
-- set @endDate = '2023-09-24';

set SESSION group_concat_max_len = 1000000;

set @locale = global_property_value('default_locale', 'es');

SET @mexConsultEnc = encounter_type('aa61d509-6e76-4036-a65d-7813c0c3b752');
set @insuranceConcept = concept_from_mapping('PIH', 'Mexico Insurance Coded');
set @seguroPopularConcept = concept_from_mapping('PIH', 'Seguro Popular');

drop temporary table if exists temp_hoja_frontal;
create temporary table temp_hoja_frontal
(
    patient_id int(11),
    lastname varchar(255),
    paternal_lastname varchar(255),
    maternal_lastname varchar(255),
    firstname varchar(255),
    registration_encounter_id int,
    registration_date date,
    seguro_popular_obs_group_id int,
    seguro_popular_policy_number varchar(100),
    birthdate date,
    gender varchar(100),
    civil_status varchar(255),
    occupation varchar(255),
    address varchar(255),
    localidad varchar(255),
    municipio varchar(255),
    telephone varchar(100),
    curp varchar(100)
);

-- Include all patients with a consulta in the given date range
insert into temp_hoja_frontal (patient_id)
select distinct(e.patient_id)
from encounter e
where e.voided = 0
  and e.encounter_type in (@mexConsultEnc)
  and date(e.encounter_datetime) >= @startDate
  and date(e.encounter_datetime) <= @endDate
;

update temp_hoja_frontal set lastname = trim(person_family_name(patient_id));
update temp_hoja_frontal set paternal_lastname = trim(substring_index(lastname, ' ', 1));
update temp_hoja_frontal set maternal_lastname = trim(substring(lastname, length(paternal_lastname) + 1)) where lastname != paternal_lastname;
update temp_hoja_frontal set firstname = person_given_name(patient_id);
update temp_hoja_frontal set registration_encounter_id = registration_encounter_id(patient_id);
update temp_hoja_frontal set registration_date = encounter_date(registration_encounter_id);

update temp_hoja_frontal t
inner join obs o on t.registration_encounter_id = o.encounter_id
set t.seguro_popular_obs_group_id = o.obs_group_id
where o.concept_id = @insuranceConcept and o.value_coded = @seguroPopularConcept;

update temp_hoja_frontal set seguro_popular_policy_number = obs_from_group_id_value_text(seguro_popular_obs_group_id, 'PIH', 'Insurance policy number');

update temp_hoja_frontal set birthdate = birthdate(patient_id);
update temp_hoja_frontal set gender = gender(patient_id);

update temp_hoja_frontal set civil_status = obs_value_coded_list(registration_encounter_id, 'PIH', 'CIVIL STATUS', 'es');
update temp_hoja_frontal set occupation = obs_value_coded_list(registration_encounter_id, 'PIH', 'Occupation', 'es');

update temp_hoja_frontal set address = person_address_one(patient_id);
update temp_hoja_frontal set localidad = person_address_city_village(patient_id);
update temp_hoja_frontal set municipio = person_address_county_district(patient_id);
update temp_hoja_frontal set telephone = phone_number(patient_id);

update temp_hoja_frontal set curp = patient_identifier(patient_id, 'c1fe3790-915a-4f03-861f-5e477f36cec0');

select * from temp_hoja_frontal;