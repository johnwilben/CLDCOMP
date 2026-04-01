#!/bin/bash
echo "══════════════════════════════════════"
echo "  WordPress + RDS Setup"
echo "══════════════════════════════════════"
echo ""

read -p "Enter your RDS Endpoint: " RDS_HOST
read -p "Enter database name [wordpress]: " DB_NAME
DB_NAME="${DB_NAME:-wordpress}"
read -p "Enter database username [admin]: " DB_USER
DB_USER="${DB_USER:-admin}"
read -sp "Enter database password: " DB_PASS
echo ""

if [ -z "$RDS_HOST" ] || [ -z "$DB_PASS" ]; then
  echo "❌ RDS Endpoint and password are required."
  exit 1
fi

echo ""
echo "Testing connection to RDS..."
mysql -h "$RDS_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1;" "$DB_NAME" > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "❌ Cannot connect to RDS. Check your endpoint, credentials, and security group."
  exit 1
fi

echo "✅ Connected to RDS successfully!"
echo ""
echo "Configuring wp-config.php..."

cd /var/www/html
sudo cp wp-config-sample.php wp-config.php

sudo sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sudo sed -i "s/username_here/$DB_USER/" wp-config.php
sudo sed -i "s/password_here/$DB_PASS/" wp-config.php
sudo sed -i "s/localhost/$RDS_HOST/" wp-config.php

SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
if [ -n "$SALT" ]; then
  sudo cp wp-config.php wp-config.php.bak
  sudo python3 -c "
import re
with open('wp-config.php', 'r') as f:
    content = f.read()
content = re.sub(r\"define\( 'AUTH_KEY',.*?;\n\", '', content)
content = re.sub(r\"define\( 'SECURE_AUTH_KEY',.*?;\n\", '', content)
content = re.sub(r\"define\( 'LOGGED_IN_KEY',.*?;\n\", '', content)
content = re.sub(r\"define\( 'NONCE_KEY',.*?;\n\", '', content)
content = re.sub(r\"define\( 'AUTH_SALT',.*?;\n\", '', content)
content = re.sub(r\"define\( 'SECURE_AUTH_SALT',.*?;\n\", '', content)
content = re.sub(r\"define\( 'LOGGED_IN_SALT',.*?;\n\", '', content)
content = re.sub(r\"define\( 'NONCE_SALT',.*?;\n\", '', content)
marker = \"/**#@-*/\"
salt_block = '''$SALT'''
content = content.replace(marker, salt_block + '\n' + marker)
with open('wp-config.php', 'w') as f:
    f.write(content)
" 2>/dev/null
fi

sudo chown www-data:www-data wp-config.php
sudo chmod 640 wp-config.php
sudo systemctl restart apache2

echo ""
echo "══════════════════════════════════════"
echo "  ✅ WordPress is ready!"
echo "  Open http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)/"
echo "  Complete the setup in your browser."
echo "══════════════════════════════════════"
