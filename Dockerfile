FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN pip install --no-cache-dir "zensical>=0.0.30,<0.1" livereload

COPY serve.py /app/serve.py

EXPOSE 8000
CMD ["python", "serve.py"]
