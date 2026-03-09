#!/bin/bash
# Run as root

OUTDIR="./preseed-extraction-$(date +%Y%m%d)"
mkdir -p "$OUTDIR"

echo "Extracting debconf selections..."
debconf-get-selections --installer > "$OUTDIR/debconf-installer.txt" 2>/dev/null
debconf-get-selections > "$OUTDIR/debconf-all.txt" 2>/dev/null

echo "Extracting package lists..."
apt-mark showmanual > "$OUTDIR/manual-packages.txt"
dpkg --get-selections > "$OUTDIR/all-packages.txt"

echo "Extracting system config..."
{
    echo "Timezone: $(timedatectl show --property=Timezone --value)"
    echo "Locale: $(cat /etc/default/locale 2>/dev/null || localectl show --property=LANG --value)"
    echo "Hostname: $(hostname)"
    echo "Domain: $(dnsdomainname 2>/dev/null || echo 'none')"
} > "$OUTDIR/system-info.txt"

echo "Disk layout..."
lsblk -f > "$OUTDIR/disk-layout.txt"
fdisk -l >> "$OUTDIR/disk-layout.txt" 2>/dev/null

echo "Network..."
ip addr > "$OUTDIR/network.txt"
cat /etc/network/interfaces >> "$OUTDIR/network.txt" 2>/dev/null

# Copy installer logs if they exist
if [ -d /var/log/installer ]; then
    echo "Copying installer logs..."
    cp -r /var/log/installer "$OUTDIR/"
fi

echo "Done. Check $OUTDIR/"
