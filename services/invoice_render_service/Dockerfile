FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libreoffice-calc \
    libreoffice-core \
    libreoffice-writer \
    libreoffice-java-common \
    default-jre-headless \
    fonts-dejavu \
    fonts-liberation \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY services/invoice_render_service/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY services/invoice_render_service/app.py ./app.py
COPY assets/templates/invoice_table_template.xlsx /app/assets/templates/invoice_table_template.xlsx

ENV INVOICE_TEMPLATE_PATH=/app/assets/templates/invoice_table_template.xlsx
ENV PORT=8080

CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT}"]
