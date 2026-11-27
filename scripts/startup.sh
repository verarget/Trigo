#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y nginx stress-ng

HOSTNAME=$(hostname)

cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Google Cloud Autoscaling</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: #0f172a;
            color: white;
            text-align: center;
            padding: 80px;
        }
        .card {
            background: #1e293b;
            padding: 40px;
            border-radius: 12px;
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>Google Cloud Platform</h1>
        <h2>Managed Instance Group</h2>
        <p>Instancia: $HOSTNAME</p>
        <p>Autoscaling CPU: 70%</p>
        <p>Status: Online</p>
    </div>
</body>
</html>
EOF

systemctl enable nginx
systemctl restart nginx