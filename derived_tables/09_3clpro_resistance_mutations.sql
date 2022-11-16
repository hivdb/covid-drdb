SELECT drug_name, abbreviation_name
  INTO TABLE approved_drugs
  FROM compounds
  WHERE abbreviation_name IN ('NTV', 'ENS');

INSERT INTO resistance_mutation_attributes
SELECT
  im.gene,
  position,
  amino_acid,
  'FOLD:' || drug.drug_name AS col_name,
  ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY fold) AS NUMERIC), 1) AS col_value
  FROM isolate_mutations im
    JOIN susc_results s ON
      im.iso_name = s.iso_name
    JOIN isolates iso ON
      im.iso_name = iso.iso_name
    JOIN isolate_pairs ip ON
      ip.gene = '_3CLpro' AND
      s.control_iso_name = ip.control_iso_name AND
      s.iso_name = ip.iso_name
    JOIN rx_compounds rxdrug ON
      s.ref_name=rxdrug.ref_name AND
      s.rx_name=rxdrug.rx_name
    JOIN approved_drugs drug ON
      rxdrug.drug_name = drug.drug_name
    WHERE
      im.gene = '_3CLpro' AND
      ip.num_mutations = 1 AND
      (SELECT COUNT(*)
        FROM rx_compounds rxdrug2
        WHERE
          s.ref_name=rxdrug2.ref_name AND
          s.rx_name=rxdrug2.rx_name
      ) = 1
  GROUP BY im.gene, position, amino_acid, col_name;

INSERT INTO resistance_mutation_attributes
SELECT
  im.gene,
  position,
  amino_acid,
  'FITNESS' AS col_name,
  ROUND(CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY fold) AS NUMERIC), 1) AS col_value
  FROM isolate_mutations im
    JOIN susc_results s ON
      im.iso_name = s.iso_name
    JOIN isolates iso ON
      im.iso_name = iso.iso_name
    JOIN isolate_pairs ip ON
      ip.gene = '_3CLpro' AND
      s.control_iso_name = ip.control_iso_name AND
      s.iso_name = ip.iso_name
    WHERE
      s.rx_type = 'enzyme-kinetics' AND
      im.gene = '_3CLpro' AND
      ip.num_mutations = 1
  GROUP BY im.gene, position, amino_acid, col_name;

INSERT INTO resistance_mutation_attributes
SELECT
  gene, position, amino_acid,
  'INVIVO' AS col_name,
  SUM(count) AS col_value
  FROM invivo_selection_results
  WHERE gene = '_3CLpro'
  GROUP BY gene, position, amino_acid
  ORDER BY gene, position, amino_acid;

INSERT INTO resistance_mutation_attributes
SELECT
  gene, position, amino_acid,
  'INVITRO' AS col_name,
  COUNT(*) AS col_value
  FROM invitro_selection_results
  WHERE gene = '_3CLpro'
  GROUP BY gene, position, amino_acid
  ORDER BY gene, position, amino_acid;

INSERT INTO resistance_mutation_attributes
SELECT
  gene, position, amino_acid,
  'PREVALENCE' AS col_name,
  proportion AS col_value
  FROM amino_acid_prevalence
  WHERE gene = '_3CLpro' AND ref_name = 'Martin21'
  ORDER BY gene, position, amino_acid;

INSERT INTO resistance_mutations
SELECT
  gene, position, amino_acid
FROM resistance_mutation_attributes rma
  WHERE
    gene = '_3CLpro' AND (
      (col_name LIKE 'FOLD:%' AND
       col_value::DECIMAL >= 2.5) OR
      (col_name = 'INVITRO' AND
       col_value::DECIMAL >= 1) OR
      (col_name = 'INVIVO' AND
       col_value::DECIMAL > 1)
    ) AND
    NOT EXISTS (
      SELECT 1
      FROM ignore_mutations igm
      WHERE
        igm.gene = rma.gene AND
        igm.position = rma.position AND
        igm.amino_acid = rma.amino_acid
    )
  GROUP BY gene, position, amino_acid;

INSERT INTO resistance_mutation_attributes
SELECT
  p.gene, p.position, rm.amino_acid,
  'POCKET:' || p.drug_name AS col_name,
  '1' AS col_value
  FROM compound_binding_pockets p
    JOIN resistance_mutations rm ON
      p.gene = rm.gene AND
      p.position = rm.position
    JOIN approved_drugs drug ON
      p.drug_name = drug.drug_name
  WHERE p.gene = '_3CLpro'
  GROUP BY p.gene, p.position, rm.amino_acid, col_name, col_value
  ORDER BY p.gene, p.position, rm.amino_acid, col_name, col_value;


DELETE FROM resistance_mutation_attributes rma
  WHERE
    gene = '_3CLpro' AND
    NOT EXISTS (
      SELECT 1 FROM resistance_mutations rm
      WHERE
        rm.gene = rma.gene AND
        rm.position = rma.position AND
        rm.amino_acid = rma.amino_acid
    );

DROP TABLE approved_drugs;
