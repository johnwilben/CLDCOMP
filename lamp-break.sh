#!/bin/bash
# ══════════════════════════════════════════════════════════════
#  LAMP Stack Break Script (Troubleshooting Activity)
#  Introduces 5 problems. Students must find and fix all.
# ══════════════════════════════════════════════════════════════

export DEBIAN_FRONTEND=noninteractive

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  💥 LAMP Stack Troubleshooting Challenge"
echo "  Breaking things in 3... 2... 1..."
echo "══════════════════════════════════════════════════════════"
echo ""

systemctl stop apache2 2>/dev/null
echo "  💥 Problem 1 introduced..."

a2dismod php8.3 > /dev/null 2>&1
apt-get remove -y --purge libapache2-mod-php8.3 > /dev/null 2>&1
echo "  💥 Problem 2 introduced..."

systemctl stop mysql 2>/dev/null
echo "  💥 Problem 3 introduced..."

apt-get remove -y --purge php8.3-mysql > /dev/null 2>&1
echo "  💥 Problem 4 introduced..."

a2dismod rewrite > /dev/null 2>&1
echo "  💥 Problem 5 introduced..."

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  💥 5 problems have been introduced to your LAMP stack!"
echo "  Your mission: Find and fix all of them."
echo "  Good luck! 🔧"
echo "══════════════════════════════════════════════════════════"
echo ""
