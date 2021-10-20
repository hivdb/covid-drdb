UPDATE rx_potency
  SET
    potency = LEAST(potency, potency_lower_limit / 2)
  WHERE
    potency_type::text LIKE 'NT%'
    AND
    potency <= potency_lower_limit;
