SELECT d.name, 
       SUM(drug_quantity.value_numeric) AS cantidad, 
       l.name 
   FROM drug d
	LEFT JOIN obs drug_name on d.drug_id = drug_name.value_drug
		and date(drug_name.obs_datetime) BETWEEN @startDate AND @endDate  
   	LEFT JOIN location l
                   ON l.location_id = drug_name.location_id
	LEFT JOIN obs drug_quantity ON drug_name.obs_group_id=drug_quantity.obs_group_id
WHERE d.name LIKE 'CES%' AND d.retired=0
GROUP BY d.drug_id, l.location_id
ORDER by d.name asc;