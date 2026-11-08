import os
import psycopg
from fastapi import FastAPI, HTTPException

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/db-health")
def db_health():
    try:
        with psycopg.connect(
                host=os.getenv("DB_HOST", "postgres"),
                dbname=os.getenv("DB_NAME", "appdb"),
                user=os.getenv("DB_USER", "appuser"),
                password=os.environ["DB_PASSWORD"],
                connect_timeout=3,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
        return {"database": "ok"}
    except Exception:
        raise HTTPException(status_code=503, detail="database unavailable")
