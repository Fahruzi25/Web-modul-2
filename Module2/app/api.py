#!/usr/bin/env python3
"""
SuryaLog Cloud -- REST API Service (Module 2)
Provides endpoints:
  - GET /healthz   -> Health check (db & redis readiness)
  - GET /summary   -> Summary metrics (reads from DB or Redis cache)
  - GET /readings  -> Plant readings list
  - POST /ingest   -> Ingest plant reading record
"""

import os
import json
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

import psycopg
import redis

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "suryalog")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASSWORD", "postgres")

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

def get_db_connection():
    conn_str = f"host={DB_HOST} port={DB_PORT} dbname={DB_NAME} user={DB_USER} password={DB_PASS}"
    return psycopg.connect(conn_str)

def get_redis_client():
    return redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, socket_timeout=2.0)

class SuryaLogHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        logging.info("%s - - [%s] %s", self.client_address[0], self.log_date_time_string(), format % args)

    def send_json(self, status_code, data):
        body = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed_url = urlparse(self.path)
        path = parsed_url.path

        if path == "/healthz":
            db_ok = False
            redis_ok = False
            try:
                with get_db_connection() as conn:
                    with conn.cursor() as cur:
                        cur.execute("SELECT 1")
                        db_ok = True
            except Exception as e:
                logging.warning("Health check DB fail: %s", e)

            try:
                r = get_redis_client()
                if r.ping():
                    redis_ok = True
            except Exception as e:
                logging.warning("Health check Redis fail: %s", e)

            status = 200 if (db_ok or redis_ok) else 503
            self.send_json(status, {
                "status": "ok" if db_ok else "degraded",
                "database": db_ok,
                "cache": redis_ok
            })

        elif path == "/summary":
            # Try cache first
            try:
                r = get_redis_client()
                cached = r.get("suryalog:summary")
                if cached:
                    data = json.loads(cached.decode("utf-8"))
                    data["cached"] = True
                    return self.send_json(200, data)
            except Exception as e:
                logging.info("Redis cache miss or error: %s", e)

            # Query DB
            try:
                with get_db_connection() as conn:
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
                                "cached": False
                            }
                            # Cache result for 60s
                            try:
                                r = get_redis_client()
                                r.setex("suryalog:summary", 60, json.dumps(summary_data))
                            except Exception:
                                pass
                            return self.send_json(200, summary_data)
                        else:
                            return self.send_json(404, {"error": "No readings found"})
            except Exception as e:
                logging.error("DB Query error: %s", e)
                return self.send_json(500, {"error": str(e)})

        elif path == "/readings":
            try:
                with get_db_connection() as conn:
                    with conn.cursor() as cur:
                        cur.execute("""
                            SELECT plant, hour, ts::text, energy_kwh::float, irradiance::float
                            FROM readings
                            ORDER BY hour ASC, plant ASC
                            LIMIT 50;
                        """)
                        rows = cur.fetchall()
                        readings = [
                            {"plant": r[0], "hour": r[1], "ts": r[2], "energy_kwh": r[3], "irradiance": r[4]}
                            for r in rows
                        ]
                        return self.send_json(200, {"readings": readings, "count": len(readings)})
            except Exception as e:
                return self.send_json(500, {"error": str(e)})

        else:
            self.send_json(404, {"error": "Not Found"})

    def do_POST(self):
        if self.path == "/ingest":
            content_len = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_len)
            try:
                payload = json.loads(body.decode("utf-8"))
                plant = payload["plant"]
                hour = int(payload["hour"])
                energy_kwh = float(payload["energy_kwh"])
                irradiance = float(payload["irradiance"])

                with get_db_connection() as conn:
                    with conn.cursor() as cur:
                        cur.execute("""
                            INSERT INTO readings (plant, hour, ts, energy_kwh, irradiance)
                            VALUES (%s, %s, NOW(), %s, %s)
                            ON CONFLICT (plant, hour) DO UPDATE
                            SET energy_kwh = EXCLUDED.energy_kwh, irradiance = EXCLUDED.irradiance;
                        """, (plant, hour, energy_kwh, irradiance))
                        conn.commit()

                # Invalidate cache
                try:
                    get_redis_client().delete("suryalog:summary")
                except Exception:
                    pass

                self.send_json(201, {"status": "ingested", "plant": plant, "hour": hour})
            except Exception as e:
                self.send_json(400, {"error": str(e)})
        else:
            self.send_json(404, {"error": "Not Found"})

def run_server(port=8080):
    server_address = ("", port)
    httpd = HTTPServer(server_address, SuryaLogHandler)
    logging.info("Starting SuryaLog API server on port %d...", port)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
    logging.info("Server stopped.")

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    run_server(port)
