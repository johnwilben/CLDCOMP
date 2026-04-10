#!/bin/bash
echo "💥 Preparing exam environment..."
sudo systemctl stop apache2 2>/dev/null
sudo rm -f /usr/lib/php/*/mysqli.so 2>/dev/null
sudo phpdismod mysqli >/dev/null 2>&1
sudo a2dismod rewrite >/dev/null 2>&1
echo ""
echo "💥 3 problems have been introduced to your LAMP stack!"
echo "Your mission: Find and fix all of them."
echo "Good luck!"
