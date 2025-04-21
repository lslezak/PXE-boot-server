#!/bin/bash

set -ex

# KIWI functions
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

# greeting
echo "Configure image: [$kiwi_iname]..."

# setup baseproduct link
suseSetupProduct

# activate services
systemctl enable NetworkManager.service
systemctl enable NetworkManager-wait-online.service
systemctl enable welcome-ssh-issue.service
systemctl enable welcome-issue.service
systemctl enable avahi-daemon.service
systemctl enable checkmedia.service
systemctl enable darkhttpd.service
systemctl enable live-password.service
systemctl enable live-root-shell.service
systemctl enable pxe-hostname.service
systemctl enable pxe-server.service
systemctl enable sshd.service
systemctl enable resize-run.service
systemctl enable zramswap

systemctl set-default multi-user.target

# configure the HTTP server
sed -i -e 's%^DARKHTTPD_PARAMS=.*$%DARKHTTPD_PARAMS="/srv/tftpboot/ --port 80 --syslog"%' /etc/sysconfig/darkhttpd

################################################################################
# Reducing the used space
#

# remove the GPU drivers, not needed when running in text mode only,
# the related firmware is deleted by the script below
rm -rf /usr/lib/modules/*/kernel/drivers/gpu

# remove WiFi drivers
rm -rf /usr/lib/modules/*/kernel/drivers/net/wireless
# remove Bluetooth drivers
rm -rf /usr/lib/modules/*/kernel/drivers/bluetooth
rm -rf /usr/lib/modules/*/kernel/net/bluetooth

################################################################################
# Generic cleanup in all images

# Clean-up logs
rm /var/log/zypper.log /var/log/zypp/history

# delete unused translations (MO files)
find /usr/share/locale -name "*.mo" -delete
du -h -s /usr/{share,lib}/locale/

# remove documentation
du -h -s /usr/share/doc/packages/
rm -rf /usr/share/doc/packages/*
# remove man pages
du -h -s /usr/share/man
rm -rf /usr/share/man/*

# driver and firmware cleanup
# Note: openSUSE Tumbleweed Live completely removes firmware for some server
# network cars, because you very likely won't run TW KDE Live on a server.
# But for Agama installer it makes more sense to run on server. So we keep it
# and remove the drivers for sound cards and TV cards instead. Those do not
# make sense on a server.
du -h -s /lib/modules /lib/firmware

# remove the multimedia drivers
# set DEBUG=1 to print the deleted drivers
/tmp/driver_cleanup.rb --delete
# remove the script and data, not needed anymore
rm /tmp/driver_cleanup.rb /tmp/module.list*

# # remove the unused firmware (not referenced by kernel drivers)
# /tmp/fw_cleanup.rb --delete
# # remove the script, not needed anymore
rm /tmp/fw_cleanup.rb
# du -h -s /lib/modules /lib/firmware

# remove Ruby, needed only for the cleanup scripts above, not needed in the Live system
rpm -qa | grep ruby | xargs rpm -e

rpm -qa | grep python | xargs rpm -e --nodeps

################################################################################
# The rest of the file was copied from the openSUSE Tumbleweed Live ISO
# https://build.opensuse.org/projects/openSUSE:Factory:Live/packages/livecd-tumbleweed-kde/files/config.sh?expand=1
#

# Stronger compression for the initrd
echo 'compress="xz -9 --check=crc32 --memlimit-compress=50%"' >> /etc/dracut.conf.d/less-storage.conf

# delete some AMD GPU firmware
rm -rf /lib/firmware/amdgpu/{gc_,isp,psp}*

# Decompress kernel modules, better for squashfs (boo#1192457)
find /lib/modules/*/kernel -name '*.ko.xz' -exec xz -d {} +
find /lib/modules/*/kernel -name '*.ko.zst' -exec zstd --rm -d {} +
for moddir in /lib/modules/*; do
  depmod "$(basename "$moddir")"
done

# Reuse what the macro does
rpm --eval "%fdupes /usr/share/licenses" | sh

# Not needed, boo#1166406
rm -f /boot/vmlinux*.[gx]z
rm -f /lib/modules/*/vmlinux*.[gx]z

# Remove generated files (boo#1098535)
rm -rf /var/cache/zypp/* /var/lib/zypp/AnonymousUniqueId /var/lib/systemd/random-seed
