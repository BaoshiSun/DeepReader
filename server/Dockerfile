FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --create-home reader && mkdir /app/data /app/certs && chown reader /app/data
COPY app.py ledger.py ./
USER reader
EXPOSE 8000
CMD ["uvicorn", "app:production_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--limit-concurrency", "50", "--timeout-keep-alive", "5", "--no-access-log", "--no-proxy-headers"]
