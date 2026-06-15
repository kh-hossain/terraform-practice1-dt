FROM python:3.9-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN useradd --create-home --shell /usr/sbin/nologin appuser

COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY . .

ENV ENVIRONMENT=PROD
ENV HOST=0.0.0.0
ENV PORT=8000
ENV REDIS_PORT=6379
ENV REDIS_DB=0

EXPOSE 8000

USER appuser

CMD ["python", "hello.py"]