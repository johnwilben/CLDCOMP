#!/bin/bash
# ══════════════════════════════════════════════════════════════
#  Exam Prep Script — Run BEFORE students start the exam
#  Introduces 3 LAMP issues they must fix before installing WP
#  Usage: sudo bash exam-break.sh
# ══════════════════════════════════════════════════════════════

# Problem 1: Stop Apache
systemctl stop apache2 2>/dev/null

# Problem 2: Remove php-mysql
apt-get remove -y php8.3-mysql > /dev/null 2>&1

# Problem 3: Change ownership to root
chown -R root:root /var/www/html 2>/dev/null

echo "Exam environment ready."
