#!/bin/bash
# Midterm Break — Set D: MySQL stopped, PHP-Apache removed, PHP-MySQL removed
echo "💥 Preparing exam environment..."
sudo systemctl stop mysql 2>/dev/null
sudo apt purge -y libapache2-mod-php8.3 >/dev/null 2>&1
sudo apt purge -y php8.3-mysql >/dev/null 2>&1
echo ""
echo "💥 3 problems have been introduced to your LAMP stack!"
echo "Your mission: Find and fix all of them."
echo "Good luck! 🔧"
