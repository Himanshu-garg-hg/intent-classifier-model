FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN apt-get update \
 && apt-get install -y gcc libc-dev \
 && pip install --no-cache-dir -r requirements.txt \
 && apt-get remove -y gcc libc-dev \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*
COPY . .
RUN python3 model/train.py
EXPOSE 6000
CMD ["gunicorn", "--workers", "3", "--bind", "127.0.0.1:6000", "app:app"]