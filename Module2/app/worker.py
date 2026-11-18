#!/usr/bin/env python3
"""
SuryaLog Cloud -- Background Worker Service (Module 2)
Periodically polls DB summary statistics and updates Redis cache.
"""

import os
import time
import json
import logging
import psycopg
import redis

logging.basicConfig(level=logging.INFO, format="%(asctime)s [WORKER] %(message)s")

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "suryalog")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASSWORD", "postgres")

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
INTERVAL = int(os.getenv("WORKER_INTERVAL_SEC", "30"))

def run_worker_cycle():
    conn_str = f"host={DB_HOST} port={DB_PORT} dbname={DB_NAME} user={DB_USER} password={DB_PASS}"
    try:
        with psycopg.connect(conn_str) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        count(*)::int AS rows,
                        count(DISTINCT plant)::int AS plants,
                        round(sum(energy_kwh), 2)::float AS total_kwh,
                        round(avg(irradiance), 2)::float AS mean_irradiance,
                        (SELECT hour FROM readings ORDER BY energy_kwh DESC, hour ASC LIMIT 1)::int AS peak_hour,
                        round(max(energy_kwh), 2)::float AS peak_kwh
                    FROM readings;
                """)
                row = cur.fetchone()
                if row:
                    summary_data = {
                        "rows": row[0],
                        "plants": row[1],
                        "total_kwh": row[2],
                        "mean_irradiance": row[3],
                        "peak_hour": row[4],
                        "peak_kwh": row[5],
                        "updated_by": "worker",
                        "timestamp": time.time()
                    }
                    r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, socket_timeout=2.0)
                    r.setex("suryalog:summary", 60, json.dumps(summary_data))
                    logging.info("Successfully refreshed Redis cache: total_kwh=%.2f, rows=%d", row[2], row[0])
    except Exception as e:
        logging.warning("Worker cycle failed: %s", e)

if __name__ == "__main__":
    logging.info("Starting SuryaLog Background Worker (interval=%ds)...", INTERVAL)
    while True:
        run_worker_cycle()
        time.sleep(INTERVAL)
