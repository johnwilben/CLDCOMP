#!/bin/bash
echo "💥 Preparing exam environment..."
echo -n "  [1/3] "
sudo systemctl stop apache2 2>/dev/null
echo "done"
echo -n "  [2/3] "
sudo apt purge -y php8.3-mysql >/dev/null 2>&1
echo "done"
echo -n "  [3/3] "
sudo a2dismod rewrite >/dev/null 2>&1
echo "done"
echo ""
echo "💥 3 problems have been introduced to your LAMP stack!"
echo "Your mission: Find and fix all of them."
echo "Good luck!"
