CREATE VIEW IF NOT EXISTS susc_results_50_view
AS
SELECT
    *
FROM
    susc_results
WHERE
    potency_type IN ('IC50', 'NT50')
;

CREATE VIEW IF NOT EXISTS susc_results_wt_view
AS
SELECT
    *
FROM
    susc_results susc,
    isolate_wildtype_view wt
WHERE
    susc.control_iso_name = wt.iso_name
;

CREATE VIEW IF NOT EXISTS susc_results_50_wt_view
AS
SELECT
    *
FROM
    susc_results_50_view susc,
    isolate_wildtype_view wt
WHERE
    susc.control_iso_name = wt.iso_name
;


CREATE VIEW IF NOT EXISTS susc_results_cp_50_wt_view
AS
SELECT
    *
FROM
    susc_results_50_wt_view susc,
    rx_conv_plasma rx
WHERE
    susc.ref_name = rx.ref_name
    AND
    susc.rx_name = rx.rx_name
;

CREATE VIEW IF NOT EXISTS susc_results_mab_50_wt_view
AS
SELECT
    *
FROM
    susc_results_50_wt_view susc,
    rx_mab_view rx
WHERE
    susc.ref_name = rx.ref_name
    AND
    susc.rx_name = rx.rx_name
;


CREATE VIEW IF NOT EXISTS susc_results_vp_50_wt_view
AS
SELECT
    *
FROM
    susc_results_50_wt_view susc,
    rx_vacc_plasma rx,
    vaccines vac
WHERE
    susc.ref_name = rx.ref_name
    AND
    susc.rx_name = rx.rx_name
    AND
    rx.vaccine_name = vac.vaccine_name
;


CREATE VIEW IF NOT EXISTS susc_results_aggr_view
AS
SELECT
    *
FROM
    susc_results a
WHERE
    EXISTS (
        SELECT 1
        FROM susc_results b
        WHERE
            a.ref_name = b.ref_name
            AND
            a.rx_name = b.rx_name
            AND
            a.iso_name = b.iso_name
            AND
            a.control_iso_name = b.control_iso_name
            AND
            b.cumulative_count > 1
    )
;


CREATE VIEW IF NOT EXISTS susc_results_aggr_50_view
AS
SELECT
    *
FROM
    susc_results_aggr_view a
WHERE
    potency_type IN ('IC50', 'NT50')
;

CREATE VIEW IF NOT EXISTS susc_results_aggr_wt_view
AS
SELECT
    *
FROM
    susc_results_aggr_view susc,
    isolate_wildtype_view wt
WHERE
    susc.control_iso_name = wt.iso_name
;

CREATE VIEW IF NOT EXISTS susc_results_aggr_50_wt_view
AS
SELECT
    *
FROM
    susc_results_aggr_50_view susc,
    isolate_wildtype_view wt
WHERE
    susc.control_iso_name = wt.iso_name
;

CREATE VIEW IF NOT EXISTS susc_results_indiv_view
AS
SELECT
    *
FROM
    susc_results a
WHERE
    NOT EXISTS (
        SELECT 1
        FROM susc_results b
        WHERE
            a.ref_name = b.ref_name
            AND
            a.rx_name = b.rx_name
            AND
            a.iso_name = b.iso_name
            AND
            a.control_iso_name = b.control_iso_name
            AND
            b.cumulative_count > 1
    )
;


CREATE VIEW IF NOT EXISTS susc_results_indiv_50_view
AS
SELECT
    *
FROM
    susc_results_indiv_view a
WHERE
    potency_type IN ('IC50', 'NT50')
;

CREATE VIEW IF NOT EXISTS susc_results_indiv_wt_view
AS
SELECT
    *
FROM
    susc_results_indiv_view susc,
    isolate_wildtype_view wt
WHERE
    susc.control_iso_name = wt.iso_name
;

CREATE VIEW IF NOT EXISTS susc_results_indiv_50_wt_view
AS
SELECT
    *
FROM
    susc_results_indiv_50_view susc,
    isolate_wildtype_view wt
WHERE
    susc.control_iso_name = wt.iso_name
;
