SELECT d.name                        "Medicamento",
       SUM(disp_quant.value_numeric) "Cantidad",
       l.name                        "Clinica"
FROM obs disp_quant
         INNER JOIN obs disp_drug
                    ON disp_drug.obs_group_id = disp_quant.obs_group_id
                        AND disp_drug.concept_id = concept_from_mapping('PIH', 'medication orders')
         INNER JOIN drug d
                    ON disp_drug.value_drug = d.drug_id
         LEFT JOIN location l
                   ON l.location_id = disp_drug.location_id
WHERE disp_quant.concept_id = concept_from_mapping('CIEL', '1443')
  AND date (disp_quant.obs_datetime) >= @startDate
  AND date (disp_quant.obs_datetime) <= @endDate
  AND d.name LIKE 'CES: %'
GROUP BY d.drug_id;