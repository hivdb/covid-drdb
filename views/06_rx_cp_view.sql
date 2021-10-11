CREATE VIEW IF NOT EXISTS rx_conv_plasma_wt_infect_view
AS
SELECT
    *
FROM
    rx_conv_plasma
WHERE
    infected_iso_name IN (
        SELECT iso_name FROM isolate_wildtype_view
    )
    OR
    infected_iso_name IS NULL
;

CREATE VIEW IF NOT EXISTS rx_conv_plasma_infect_var_view
AS
SELECT
    rx.*,
    iso.var_name,
    iso.as_wildtype
FROM
    rx_conv_plasma rx
LEFT JOIN
    isolate_variant_view iso
ON
    rx.infected_iso_name = iso.iso_name
;
