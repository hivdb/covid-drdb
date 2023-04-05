INSERT INTO resistance_mutation_attributes
  SELECT gene, position, amino_acid, col_name, col_value FROM candidate_resistance_mutation_attributes rma
  WHERE
    EXISTS (
      SELECT 1 FROM resistance_mutations rm
      WHERE
        rm.gene = rma.gene AND
        rm.position = rma.position AND
        rm.amino_acid = rma.amino_acid
    );

INSERT INTO resistance_mutation_articles
  SELECT gene, position, amino_acid, ref_name, col_type FROM candidate_resistance_mutation_articles a
  WHERE
    EXISTS (
      SELECT 1 FROM resistance_mutations rm
      WHERE
        rm.gene = a.gene AND
        rm.position = a.position AND
        rm.amino_acid = a.amino_acid
    );

