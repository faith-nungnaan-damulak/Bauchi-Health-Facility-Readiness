-- =====================================================
-- STAGE 4A: FLAT DIMENSION VIEWS FOR POWER BI  (MySQL)
-- These join the lookup tables so Power BI gets ONE clean facility table
-- and ONE clean indicator table (a simple "star" model).
-- =====================================================
USE bauchi_health;

CREATE VIEW vw_dim_facility AS
SELECT
    f.facility_id,
    f.facility_name,
    w.ward_name,
    l.lga_name,
    lv.level_name,
    t.type_name,
    g.group_name        AS type_group,
    o.ownership_name,
    ot.ownership_type_name,
    f.functional_status,
    f.latitude,
    f.longitude,
    f.coordinate_status,
    f.nhfr_code,
    f.gps_accuracy,
    f.flag_count
FROM facility f
JOIN ward w                 ON w.ward_id = f.ward_id
JOIN lga l                  ON l.lga_id = w.lga_id
JOIN facility_level lv      ON lv.level_id = f.level_id
JOIN facility_type t        ON t.type_id = f.type_id
JOIN facility_type_group g  ON g.group_id = t.group_id
JOIN ownership o            ON o.ownership_id = f.ownership_id
JOIN ownership_type ot      ON ot.ownership_type_id = f.ownership_type_id;

CREATE VIEW vw_dim_indicator AS
SELECT
    i.indicator_id,
    i.indicator_name,
    d.domain_name
FROM indicator i
JOIN indicator_domain d ON d.domain_id = i.domain_id;

-- CHECKS
-- SELECT COUNT(*) FROM vw_dim_facility;   -- expect 1787
-- SELECT COUNT(*) FROM vw_dim_indicator;  -- expect 18
