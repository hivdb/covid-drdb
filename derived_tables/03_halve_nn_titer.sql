UPDATE rx_potency
  SET
    potency = LEAST(potency, potency_lower_limit / 2)
  WHERE
    (
      potency_type::text LIKE 'NT%'
      OR
      potency_type::text = 'inhibition'
    )
    AND
    potency <= potency_lower_limit;
