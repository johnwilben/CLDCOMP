#!/bin/bash
# ══════════════════════════════════════════════════════════════
#  LAMP Stack Break Script (Troubleshooting Activity)
#  Introduces 5 problems. Students must find and fix all.
# ══════════════════════════════════════════════════════════════

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  💥 LAMP Stack Troubleshooting Challenge"
echo "  Breaking things in 3... 2... 1..."
echo "══════════════════════════════════════════════════════════"
echo ""

# Problem 1: Stop Apache
systemctl stop apache2 2>/dev/null
echo "  💥 Problem 1 introduced..."

# Problem 2: Remove libapache2-mod-php (raw PHP code in browser)
a2dismod php8.3 > /dev/null 2>&1
apt-get remove -y libapache2-mod-php8.3 > /dev/null 2>&1
echo "  💥 Problem 2 introduced..."

# Problem 3: Stop MySQL
systemctl stop mysql 2>/dev/null
echo "  💥 Problem 3 introduced..."

# Problem 4: Remove php-mysql module
apt-get remove -y php8.3-mysql > /dev/null 2>&1
echo "  💥 Problem 4 introduced..."

# Problem 5: Disable mod_rewrite
a2dismod rewrite > /dev/null 2>&1
echo "  💥 Problem 5 introduced..."

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  💥 5 problems have been introduced to your LAMP stack!"
echo "  Your mission: Find and fix all of them."
echo "  Good luck! 🔧"
echo "══════════════════════════════════════════════════════════"
echo ""
