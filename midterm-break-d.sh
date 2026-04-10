#!/bin/bash
echo "💥 Preparing exam environment..."
sudo systemctl stop mysql 2>/dev/null
sudo a2dismod php8.3 >/dev/null 2>&1
sudo rm -f /etc/apache2/mods-enabled/php8.3.* 2>/dev/null

sudo dpkg --remove --force-depends php8.3-mysql >/dev/null 2>&1
echo ""
echo "💥 3 problems have been introduced to your LAMP stack!"
echo "Your mission: Find and fix all of them."
echo "Good luck!"
