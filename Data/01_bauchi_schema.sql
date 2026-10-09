-- =====================================================
-- BAUCHI HEALTH FACILITY DATABASE  (MySQL)
-- Run each PART in order. Source: GRID3 Nigeria, cleaned in Excel
-- =====================================================

-- ---------- PART 1: DATABASE ----------
CREATE DATABASE IF NOT EXISTS bauchi_health CHARACTER SET utf8mb4;
USE bauchi_health;

-- ---------- PART 2: LOOKUP TABLES (the "parent" tables) ----------
CREATE TABLE lga (
    lga_id      INT AUTO_INCREMENT PRIMARY KEY,
    lga_name    VARCHAR(50) NOT NULL UNIQUE
);

-- Ward names repeat across LGAs (e.g. Yola, Zaura), so a ward is unique only WITHIN its LGA
CREATE TABLE ward (
    ward_id     INT AUTO_INCREMENT PRIMARY KEY,
    ward_name   VARCHAR(60) NOT NULL,
    lga_id      INT NOT NULL,
    UNIQUE (lga_id, ward_name),
    FOREIGN KEY (lga_id) REFERENCES lga(lga_id)
);

CREATE TABLE facility_level (
    level_id    INT AUTO_INCREMENT PRIMARY KEY,
    level_name  VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE facility_type_group (
    group_id    INT AUTO_INCREMENT PRIMARY KEY,
    group_name  VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE facility_type (
    type_id     INT AUTO_INCREMENT PRIMARY KEY,
    type_name   VARCHAR(60) NOT NULL UNIQUE,
    group_id    INT NOT NULL,
    FOREIGN KEY (group_id) REFERENCES facility_type_group(group_id)
);

CREATE TABLE ownership (
    ownership_id    INT AUTO_INCREMENT PRIMARY KEY,
    ownership_name  VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE ownership_type (
    ownership_type_id    INT AUTO_INCREMENT PRIMARY KEY,
    ownership_type_name  VARCHAR(40) NOT NULL UNIQUE
);

-- ---------- PART 3: MAIN TABLE (the "child" table) ----------
CREATE TABLE facility (
    facility_id        VARCHAR(20) PRIMARY KEY,
    facility_name      VARCHAR(150) NOT NULL,
    ward_id            INT NOT NULL,
    level_id           INT NOT NULL,
    type_id            INT NOT NULL,
    ownership_id       INT NOT NULL,
    ownership_type_id  INT NOT NULL,
    functional_status  VARCHAR(20) NOT NULL,
    latitude           DECIMAL(9,6) NULL,
    longitude          DECIMAL(9,6) NULL,
    coordinate_status  VARCHAR(20) NOT NULL,
    nhfr_code          VARCHAR(30) NULL,
    gps_accuracy       DECIMAL(8,3) NULL,
    flag_count         TINYINT UNSIGNED NOT NULL,
    FOREIGN KEY (ward_id)           REFERENCES ward(ward_id),
    FOREIGN KEY (level_id)          REFERENCES facility_level(level_id),
    FOREIGN KEY (type_id)           REFERENCES facility_type(type_id),
    FOREIGN KEY (ownership_id)      REFERENCES ownership(ownership_id),
    FOREIGN KEY (ownership_type_id) REFERENCES ownership_type(ownership_type_id)
);

-- ---------- PART 4: STAGING TABLE (a temporary landing area for the CSV) ----------
CREATE TABLE stg_facility (
    facility_id        VARCHAR(20),
    facility_name      VARCHAR(150),
    `level`            VARCHAR(30),
    `type`             VARCHAR(60),
    type_group         VARCHAR(30),
    ownership          VARCHAR(30),
    ownership_type     VARCHAR(40),
    functional         VARCHAR(20),
    lga                VARCHAR(50),
    ward               VARCHAR(60),
    latitude           VARCHAR(20),
    longitude          VARCHAR(20),
    nhfr_code          VARCHAR(30),
    gps_accuracy       VARCHAR(20),
    flag_count         VARCHAR(5),
    coordinate_status  VARCHAR(20)
);

-- >>> STOP HERE. Import bauchi_facilities_clean.csv into stg_facility
-- >>> (MySQL Workbench: right-click stg_facility > Table Data Import Wizard)
-- >>> Then run: SELECT COUNT(*) FROM stg_facility;   -- must return 1787

-- ---------- PART 5: FILL LOOKUP TABLES FROM STAGING ----------
INSERT INTO lga (lga_name)
SELECT DISTINCT lga FROM stg_facility ORDER BY lga;

INSERT INTO ward (ward_name, lga_id)
SELECT DISTINCT s.ward, l.lga_id
FROM stg_facility s
JOIN lga l ON l.lga_name = s.lga;

INSERT INTO facility_level (level_name)
SELECT DISTINCT `level` FROM stg_facility;

INSERT INTO facility_type_group (group_name)
SELECT DISTINCT type_group FROM stg_facility;

INSERT INTO facility_type (type_name, group_id)
SELECT DISTINCT s.`type`, g.group_id
FROM stg_facility s
JOIN facility_type_group g ON g.group_name = s.type_group;

INSERT INTO ownership (ownership_name)
SELECT DISTINCT ownership FROM stg_facility;

INSERT INTO ownership_type (ownership_type_name)
SELECT DISTINCT ownership_type FROM stg_facility;

-- ---------- PART 6: FILL THE FACILITY TABLE ----------
INSERT INTO facility
    (facility_id, facility_name, ward_id, level_id, type_id, ownership_id,
     ownership_type_id, functional_status, latitude, longitude,
     coordinate_status, nhfr_code, gps_accuracy, flag_count)
SELECT
    s.facility_id, s.facility_name, w.ward_id, lv.level_id, t.type_id, o.ownership_id,
    ot.ownership_type_id, s.functional,
    NULLIF(s.latitude, ''), NULLIF(s.longitude, ''),
    s.coordinate_status, NULLIF(s.nhfr_code, ''), NULLIF(s.gps_accuracy, ''),
    s.flag_count
FROM stg_facility s
JOIN lga l              ON l.lga_name = s.lga
JOIN ward w             ON w.ward_name = s.ward AND w.lga_id = l.lga_id
JOIN facility_level lv  ON lv.level_name = s.`level`
JOIN facility_type t    ON t.type_name = s.`type`
JOIN ownership o        ON o.ownership_name = s.ownership
JOIN ownership_type ot  ON ot.ownership_type_name = s.ownership_type;

-- ---------- PART 7: VERIFY ----------
SELECT 'stg_facility' AS tbl, COUNT(*) AS rows_found FROM stg_facility
UNION ALL SELECT 'facility',            COUNT(*) FROM facility
UNION ALL SELECT 'lga',                 COUNT(*) FROM lga
UNION ALL SELECT 'ward',                COUNT(*) FROM ward
UNION ALL SELECT 'facility_type',       COUNT(*) FROM facility_type
UNION ALL SELECT 'facility_type_group', COUNT(*) FROM facility_type_group;
-- Expected: 1787, 1787, 20, 334, 19, 7

-- Facilities per LGA (should add up to 1787)
SELECT l.lga_name, COUNT(*) AS facilities
FROM facility f
JOIN ward w ON w.ward_id = f.ward_id
JOIN lga l  ON l.lga_id = w.lga_id
GROUP BY l.lga_name
ORDER BY facilities DESC;
