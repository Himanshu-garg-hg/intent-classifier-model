#!/bin/bash

# Create directory
set -e
export app_dir=/home/intent_app
mkdir -p $app_dir
cd $app_dir

# update packages
apt update -y
apt install -y git python3 python3-venv nginx python3-pip

# Git clone code
git clone https://github.com/iam-veeramalla/Intent-classifier-model.git


# python venv set up
cd Intent-classifier-model
python3 -m venv .venv
source .venv/bin/activate

# Dependencies install
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt

# train model
python model/train.py

# WSGI setup --> as systemd service
cat > /etc/systemd/system/intent-app-gunicorn.service << 'EOF'
[Unit]
Description=Gunicorn service for Flask App
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/intent_app/Intent-classifier-model
Environment="PATH=/home/intent_app/Intent-classifier-model/.venv/bin"
ExecStart=/home/intent_app/Intent-classifier-model/.venv/bin/gunicorn --workers 3 --bind 127.0.0.1:6000 wsgi:app

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# configure nginx reverse proxy (default config will be overwritten)
cat >/etc/nginx/conf.d/intent_app.conf <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:6000/predict;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_read_timeout 120s;
    }
}
EOF

# Remove default site if present to avoid duplicate default_server collision
if [ -L /etc/nginx/sites-enabled/default ] || [ -f /etc/nginx/sites-enabled/default ]; then
  rm -f /etc/nginx/sites-enabled/default || true
fi

# start & enable services
systemctl daemon-reload
systemctl enable intent-app-gunicorn
systemctl start intent-app-gunicorn
systemctl enable nginx
systemctl restart nginx