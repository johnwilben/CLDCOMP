#!/bin/bash
# Midterm Break — Set B: MySQL stopped, PHP-Apache removed, mod_rewrite disabled
echo "💥 Preparing exam environment..."
sudo systemctl stop mysql 2>/dev/null
sudo apt purge -y libapache2-mod-php8.3 >/dev/null 2>&1
sudo a2dismod rewrite >/dev/null 2>&1
sudo systemctl restart apache2 2>/dev/null
echo ""
echo "💥 3 problems have been introduced to your LAMP stack!"
echo "Your mission: Find and fix all of them."
echo "Good luck! 🔧"
