#!/bin/bash
set -e

echo "Stopping and removing old Nginx container (if any)..."
sudo docker stop mynginx || true
sudo docker rm mynginx || true

echo "Starting Nginx container..."
sudo docker run -d --name mynginx \
   -p 443:443 \
  -v /home/ubuntu/conf.d:/etc/nginx/conf.d/ \
  -v /home/ubuntu/certs:/etc/ssl \
  nginx
