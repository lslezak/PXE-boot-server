# PXE boot server

This boot server supports booting via PXE for both classic BIOS and UEFI
firmware. Currently it supports only booting the x86_64 machines, other
architectures are not supported.

## Network configuration

To avoid collision with existing DHCP servers the PXE boot server service
is started only on the network interfaces NOT configured by DHCP.

If there is a network interface configured with DHCP then it is used for
forwarding the requests from the not configured interfaces. The PXE boot server
works as a router.

## Files

This directory contains the basic structure required for booting via the PXE
boot protocol.

## Persistent storage

The PXE images are by default stored in RAM disk. The advantage is that it does
not require any additional configuration, disadvantage is that you need quite a
lot of RAM to store the images and the downloaded images are lost after power
off or reboot.

If you want to store the PXE images on a disk them manually mount it to the
`/srv/tftpboot` mount point:

```sh
mount /dev/sda1 /srv/tftpboot
```

If you want to use a subdirectory them mount the disk elsewhere and bind-mount
it to `/srv/tftpboot`.

```sh
mount /dev/sda1 /mnt
mount --bind /mnt/... /srv/tftpboot
```

After mounting the disk for the first time you have to create the basic boot
structure and the initial boot menu in `/srv/tfptboot`.

```sh
download-pxe-image.sh -i
```

## Downloading PXE images

For downloading and integrating the PXE images from OBS use the included
`download-pxe-image.sh` script.

It needs three arguments:

- `-u` sets the download URL for the image
- `-l` sets the boot menu label
- `-d` sets the subdirectory under `/srv/stftpboot` where to store the image

Examples:

```sh
# download the official openSUSE Leap 16.0 image
download-pxe-image.sh -d Leap16 -u https://download.opensuse.org/distribution/leap/16.0/installer/agama-installer-Leap.x86_64-Leap-PXE.install.tar -l "Install openSUSE Leap 16.0 ($(date "+%F %H:%M"))"

# download the official openSUSE Tumbleweed image
download-pxe-image.sh -d Tumbleweed -u https://download.opensuse.org/tumbleweed/appliances/agama-installer.x86_64-openSUSE_PXE.install.tar -l "Install openSUSE Tumbleweed ($(date "+%F %H:%M"))"

# download the latest Agama development image
download-pxe-image.sh -d Agama_devel -u https://download.opensuse.org/repositories/systemsmanagement:/Agama:/Devel/images/agama-installer.x86_64-openSUSE_PXE.install.tar -l "Install openSUSE (systemsmanagement:Agama:Devel ($(date "+%F %H:%M"))"
```

The commands are available in the bash history, just press the arrow up key to
see them.

## Links

For more details see the [documentation](https://github.com/lslezak/PXE-boot-server).
