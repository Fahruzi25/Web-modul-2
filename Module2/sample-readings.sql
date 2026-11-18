-- ===========================================================================
-- SuryaLog Cloud -- Module 2 seed data (FIXED, committed, no RNG)
-- 10 plants (P01..P10) x 24 hourly readings for one day = 240 rows.
-- Deterministic: every value comes from a fixed hourly profile, identical
-- across plants, so the /summary aggregates are exact and stable.
--
-- Load: Auto-loaded by Postgres docker-entrypoint-initdb.d mount
--
-- Expected /summary result over this seed:
--   rows            = 240
--   plants          = 10
--   total_kwh       = 231.20   (10 plants x 23.12 kWh/day)
--   mean_irradiance = 1.83     (avg over all 240 rows; night hours are 0)
--   peak_hour       = 12
--   peak_kwh        = 3.42
-- ===========================================================================

DROP TABLE IF EXISTS readings;

CREATE TABLE readings (
    plant       text                 NOT NULL,
    hour        int                  NOT NULL,
    ts          timestamptz          NOT NULL,
    energy_kwh  numeric(6,2)         NOT NULL,
    irradiance  numeric(6,2)         NOT NULL,
    PRIMARY KEY (plant, hour)
);

-- One INSERT ... SELECT: fully deterministic, pure SQL.
-- energy_kwh follows a fixed bell-shaped day; irradiance = energy_kwh * 1.90.
INSERT INTO readings (plant, hour, ts, energy_kwh, irradiance)
SELECT
    'P' || lpad(p::text, 2, '0')                                   AS plant,
    h                                                              AS hour,
    timestamptz '2025-06-01 00:00:00+07' + (h || ' hours')::interval AS ts,
    prof.kwh                                                       AS energy_kwh,
    round(prof.kwh * 1.90, 2)                                      AS irradiance
FROM generate_series(1, 10) AS p
CROSS JOIN generate_series(0, 23) AS h
CROSS JOIN LATERAL (
    SELECT CASE h
        WHEN  6 THEN 0.15 WHEN  7 THEN 0.55 WHEN  8 THEN 1.20 WHEN  9 THEN 2.00
        WHEN 10 THEN 2.75 WHEN 11 THEN 3.20 WHEN 12 THEN 3.42 WHEN 13 THEN 3.20
        WHEN 14 THEN 2.75 WHEN 15 THEN 2.00 WHEN 16 THEN 1.20 WHEN 17 THEN 0.55
        WHEN 18 THEN 0.15 ELSE 0.00
    END AS kwh
) AS prof;

-- Sanity checks (psql prints these; they must match the header comment).
SELECT count(*)                    AS rows,
       count(DISTINCT plant)       AS plants,
       round(sum(energy_kwh), 2)   AS total_kwh,
       round(avg(irradiance), 2)   AS mean_irradiance,
       round(max(energy_kwh), 2)   AS peak_kwh
FROM readings;
