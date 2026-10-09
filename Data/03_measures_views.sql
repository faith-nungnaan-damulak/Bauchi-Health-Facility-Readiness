-- =====================================================
-- STAGE 3B: MEASURES (SQL VIEWS)  (MySQL)
-- A view is a saved query. Each one below is a "measure" you can
-- select from like a table, and Power BI can import them directly.
-- Run the whole file in order (later views use earlier ones).
-- =====================================================
USE bauchi_health;

-- MEASURE 1: readiness score for every visit
-- readiness_score_pct = items present / items checked x 100
CREATE VIEW vw_visit_score AS
SELECT
    v.visit_id,
    v.facility_id,
    v.visit_round,
    v.visit_date,
    SUM(r.is_present)                                   AS items_present,
    COUNT(*)                                            AS items_checked,
    ROUND(100.0 * SUM(r.is_present) / COUNT(*), 1)      AS readiness_score_pct,
    CASE
        WHEN 100.0 * SUM(r.is_present) / COUNT(*) >= 75 THEN 'Ready'
        WHEN 100.0 * SUM(r.is_present) / COUNT(*) >= 50 THEN 'Partly ready'
        ELSE 'Not ready'
    END                                                 AS readiness_band
FROM monitoring_visit v
JOIN visit_indicator_result r ON r.visit_id = v.visit_id
GROUP BY v.visit_id, v.facility_id, v.visit_round, v.visit_date;

-- MEASURE 2: score per domain for every visit
CREATE VIEW vw_visit_domain_score AS
SELECT
    r.visit_id,
    d.domain_name,
    ROUND(100.0 * SUM(r.is_present) / COUNT(*), 1) AS domain_score_pct
FROM visit_indicator_result r
JOIN indicator i        ON i.indicator_id = r.indicator_id
JOIN indicator_domain d ON d.domain_id = i.domain_id
GROUP BY r.visit_id, d.domain_name;

-- MEASURE 3: medicine stockouts per visit
-- stockout_count = essential medicines missing on the day of the visit (max 3)
CREATE VIEW vw_visit_stockout AS
SELECT
    r.visit_id,
    SUM(CASE WHEN r.is_present = 0 THEN 1 ELSE 0 END)       AS stockout_count,
    CASE WHEN SUM(CASE WHEN r.is_present = 0 THEN 1 ELSE 0 END) > 0
         THEN 1 ELSE 0 END                                  AS has_stockout
FROM visit_indicator_result r
JOIN indicator i        ON i.indicator_id = r.indicator_id
JOIN indicator_domain d ON d.domain_id = i.domain_id
WHERE d.domain_name = 'Essential Medicines'
GROUP BY r.visit_id;

-- MEASURE 4: each monitored facility's LATEST visit, with score and stockouts
CREATE VIEW vw_facility_latest AS
SELECT
    f.facility_id,
    f.facility_name,
    t.group_name         AS type_group,
    own.ownership_name   AS ownership,
    l.lga_name,
    w.ward_name,
    s.visit_round        AS latest_round,
    s.visit_date         AS latest_visit_date,
    s.readiness_score_pct,
    s.readiness_band,
    o.stockout_count,
    o.has_stockout
FROM vw_visit_score s
JOIN facility f             ON f.facility_id = s.facility_id
JOIN ward w                 ON w.ward_id = f.ward_id
JOIN lga l                  ON l.lga_id = w.lga_id
JOIN facility_type ft       ON ft.type_id = f.type_id
JOIN facility_type_group t  ON t.group_id = ft.group_id
JOIN ownership own          ON own.ownership_id = f.ownership_id
JOIN vw_visit_stockout o    ON o.visit_id = s.visit_id
WHERE s.visit_round = (SELECT MAX(s2.visit_round)
                       FROM vw_visit_score s2
                       WHERE s2.facility_id = s.facility_id);

-- MEASURE 5: facility improvement from first to latest visit
CREATE VIEW vw_facility_change AS
SELECT
    a.facility_id,
    a.readiness_score_pct                        AS first_score,
    b.readiness_score_pct                        AS latest_score,
    ROUND(b.readiness_score_pct - a.readiness_score_pct, 1) AS score_change
FROM vw_visit_score a
JOIN vw_visit_score b ON b.facility_id = a.facility_id
WHERE a.visit_round = 1
  AND b.visit_round = (SELECT MAX(x.visit_round)
                       FROM vw_visit_score x
                       WHERE x.facility_id = a.facility_id);

-- MEASURE 6: one summary row per LGA
-- coverage_pct = monitored facilities / all facilities in the LGA
CREATE VIEW vw_lga_summary AS
SELECT
    l.lga_name,
    tot.total_facilities,
    COUNT(m.facility_id)                                        AS monitored_facilities,
    ROUND(100.0 * COUNT(m.facility_id) / tot.total_facilities, 1) AS coverage_pct,
    ROUND(AVG(m.readiness_score_pct), 1)                        AS avg_readiness_pct,
    ROUND(100.0 * SUM(CASE WHEN m.readiness_band = 'Ready' THEN 1 ELSE 0 END)
          / COUNT(m.facility_id), 1)                            AS pct_ready,
    ROUND(100.0 * SUM(m.has_stockout) / COUNT(m.facility_id), 1) AS stockout_rate_pct
FROM lga l
JOIN (SELECT w.lga_id, COUNT(*) AS total_facilities
      FROM facility f JOIN ward w ON w.ward_id = f.ward_id
      GROUP BY w.lga_id) tot ON tot.lga_id = l.lga_id
LEFT JOIN vw_facility_latest m ON m.lga_name = l.lga_name
GROUP BY l.lga_name, tot.total_facilities;

-- MEASURE 7: average readiness by LGA and visit round (for the trend chart)
CREATE VIEW vw_lga_round_trend AS
SELECT
    l.lga_name,
    s.visit_round,
    ROUND(AVG(s.readiness_score_pct), 1) AS avg_readiness_pct,
    COUNT(*)                             AS visits
FROM vw_visit_score s
JOIN facility f ON f.facility_id = s.facility_id
JOIN ward w     ON w.ward_id = f.ward_id
JOIN lga l      ON l.lga_id = w.lga_id
GROUP BY l.lga_name, s.visit_round;

-- ---------- CHECKS ----------
-- SELECT * FROM vw_lga_summary ORDER BY avg_readiness_pct DESC;
-- SELECT type_group, COUNT(*) n, ROUND(AVG(readiness_score_pct),1) avg_score
--   FROM vw_facility_latest GROUP BY type_group;
