CREATE VIEW IF NOT EXISTS mab_view
AS
SELECT
    r.ref_name AS ref_name,
    r.rx_name AS rx_name,
    r.ab_name AS ab_name,
    ab.synonyms AS synonyms,
    ab.availability,
    ab.pdb_id,
    ab.target,
    ab.class,
    ab.epitope,
    ab.institute,
    ab.origin
FROM
    rx_antibodies AS r,
    (
SELECT
    a.ab_name,
    s.synonyms,
    a.availability,
    t.pdb_id,
    t.target,
    t.class,
    e.epitope,
    a.institute,
    a.origin
FROM
    antibodies a
    LEFT JOIN
    (
SELECT
    DISTINCT *
FROM
    antibody_targets
WHERE
    ab_name NOT IN (
        SELECT
            ab_name
        FROM
            antibody_targets
        WHERE
            pdb_id IS NOT NULL
        )

UNION

SELECT
    DISTINCT *
FROM
    antibody_targets
WHERE
    pdb_id IS NOT null
) t
    ON
        a.ab_name = t.ab_name
    LEFT JOIN
    (
SELECT
    ab_name,
    GROUP_CONCAT(position, '+') AS epitope
FROM
    antibody_epitopes
GROUP BY
    ab_name
) e
    ON
        a.ab_name = e.ab_name
    LEFT JOIN
    (
SELECT
    ab_name,
    GROUP_CONCAT(synonym, ';') AS synonyms
FROM
    antibody_synonyms
GROUP BY
    ab_name
) s
    ON
        a.ab_name = s.ab_name
) AS ab
ON r.ab_name = ab.ab_name
GROUP BY r.ref_name, r.rx_name
HAVING count(r.ab_name) = 1

UNION

SELECT
    a.ref_name,
    a.rx_name,
    a.ab_name || '/' || b.ab_name AS ab_name,
    NULL AS synonyms,
    CASE
        WHEN a.availability == b.availability THEN
            a.availability
        ELSE
            NULL
    END availability,
    NULL AS pdb_id,
    NULL AS target,
    NULL AS class,
    NULL AS epitope,
    CASE
        WHEN a.institute == b.institute THEN
            a.institute
        ELSE
            NULL
    END institute,
    CASE
        WHEN a.origin == b.origin THEN
            a.origin
        ELSE
            NULL
    END origin
FROM
    (SELECT
        a.*,
        b.availability,
        b.institute,
        b.origin
    FROM
        rx_antibodies a,
        antibodies b
    ON
        a.ab_name = b.ab_name
    ) a,
    (SELECT
        a.*,
        b.availability,
        b.institute,
        b.origin
    FROM
        rx_antibodies a,
        antibodies b
    ON
        a.ab_name = b.ab_name
    ) b
WHERE
    a.ref_name = b.ref_name and
    a.rx_name = b.rx_name and
    a.ab_name != b.ab_name and
    a.ab_name < b.ab_name
