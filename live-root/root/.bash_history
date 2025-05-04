download-pxe-image.sh -d Agama_devel -u https://download.opensuse.org/repositories/systemsmanagement:/Agama:/Devel/images/agama-installer.x86_64-openSUSE_PXE.install.tar -l "Install openSUSE from systemsmanagement:Agama:Devel ($(date "+%F %H:%M"))"
download-pxe-image.sh -d Tumbleweed -u https://download.opensuse.org/tumbleweed/appliances/agama-installer.x86_64-openSUSE_PXE.install.tar -l "Install openSUSE Tumbleweed ($(date "+%F %H:%M"))"
download-pxe-image.sh -d Leap16 -u https://download.opensuse.org/distribution/leap/16.0/installer/agama-installer-Leap.x86_64-Leap-PXE.install.tar -l "Install openSUSE Leap 16.0 ($(date "+%F %H:%M"))"
download-pxe-image.sh -h
less /srv/tftpboot/README.md
