#!/bin/bash
# Midterm Break — Set C: Apache stopped, PHP-MySQL removed, mod_rewrite disabled
echo "💥 Preparing exam environment..."
sudo systemctl stop apache2 2>/dev/null
sudo apt purge -y php8.3-mysql >/dev/null 2>&1
sudo a2dismod rewrite >/dev/null 2>&1
echo ""
echo "💥 3 problems have been introduced to your LAMP stack!"
echo "Your mission: Find and fix all of them."
echo "Good luck! 🔧"
