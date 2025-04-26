#! /bin/bash

# This script downloads and installs a PXE image.

set -e

usage () {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -i         - initialize the root directory, create the required boot files"
  echo "  -r <root>  - Root directory (default: /srv/tftpboot)"
  echo "  -d <dir>   - subdirectory where to unpack the archive (relative to root dir)"
  echo "  -u <url>   - download URL for the PXE image (a tar archive)"
  echo "  -l <label> - PXE boot menu label"
  echo "  -s <url>   - Prefix for the image download location (default: http://pxe-server),"
  echo "               the -d <dir> value is appended"
  echo "  -h         - print this help"
}

# process command line arguments
while getopts ":d:hil:r:s:u:" opt; do
  case ${opt} in
    d)
      dir="${OPTARG}"
      ;;
    h)
      usage
      exit 0
      ;;
    i)
      init="1"
      ;;
    l)
      label="${OPTARG}"
      ;;
    r)
      root="${OPTARG}"
      ;;
    s)
      server="${OPTARG}"
      ;;
    u)
      url="${OPTARG}"
      ;;
    :)
      echo "ERROR: Missing argument for option -${OPTARG}"
      echo
      usage
      exit 1
      ;;
    ?)
      echo "ERROR: Invalid option -${OPTARG}"
      echo
      usage
      exit 1
      ;;
  esac
done

if [ -z "$root" ]; then
  root="/srv/tftpboot"
fi

if [ -z "$server" ]; then
  server="http://pxe-server"
fi

bios_menu="$root/pxelinux.cfg/default"
uefi_menu="$root/grub.cfg"

if [ -n "$init" ]; then
  # check if the needed files are present
  if [ ! -e /usr/share/syslinux/pxelinux.0 ] || [ ! -e /usr/share/syslinux/menu.c32 ] || [ ! -e /usr/share/syslinux/chain.c32 ]; then
    echo "Error: Missing syslinux files, make sure the \"syslinux\" package is installed"
    exit 1
  fi

  if [ ! -e /usr/share/efi/x86_64/shim.efi ]; then
    echo "Error: Missing shim.efi file, make sure the \"shim\" package is installed"
    exit 1
  fi

  if [ ! -e /usr/share/grub2/x86_64-efi/grub.efi ]; then
    echo "Error: Missing grub.efi file, make sure the \"grub2-x86_64-efi\" package is installed"
    exit 1
  fi

  # create the target directory
  echo "Initializing boot configuration at $root ..."
  mkdir -p "$root/pxelinux.cfg"

  # link the PXE boot files from the syslinux package (BIOS boot)
  ln -s /usr/share/syslinux/{pxelinux.0,menu.c32,chain.c32} "$root"

  # link the PXE boot files from the shim and grub package (UEFI boot)
  ln -s /usr/share/efi/x86_64/shim.efi "$root/bootx64.efi"
  ln -s /usr/share/grub2/x86_64-efi/grub.efi "$root"

  # create initial bootloader configurations
  cat << EOF > "$bios_menu"
default menu.c32
timeout 120

MENU TITLE PXE boot menu

LABEL local
  MENU LABEL Boot from local hard drive
  localboot 0

LABEL chainlocal
	MENU LABEL Chain boot to local hard drive
	KERNEL chain.c32
	APPEND hd0

EOF

  cat << EOF > "$uefi_menu"
gfxmode=auto
timeout=120
default=1

locale_dir=grub.locale
lang=en_US

menuentry "UEFI firmware settings" {
  fwsetup --is-supported
  if [ "\$?" = 0 ]; then
    fwsetup
  else
    echo "Your firmware doesn't support setup menu entry from a boot loader"
    echo "Press any key to return ..."
    read
  fi
}

menuentry "Boot from local hard drive" --class opensuse --class gnu-linux --class gnu --class os {
  if search --no-floppy --file /efi/boot/fallback.efi --set ; then
    for os in opensuse sles ; do
      if [ -f /efi/\$os/grub.efi ] ; then
        chainloader /efi/\$os/grub.efi
        boot
      fi
    done
  fi
  exit
}

EOF

  # only initialization was requested, finish the script
  if [ -z "$url" ]; then
    exit 0
  fi
fi

if [ -z "$dir" ]; then
  echo "ERROR: Missing -d option, specify a subdirectory in $root"
  exit 1
fi

if [ -z "$url" ]; then
  echo "ERROR: Missing -u option, specify the image URL"
  exit 1
fi

path="$root/$dir"

if [ -e "$path" ]; then
  echo "ERROR: Path $path already exists, exiting to avoid overwriting files"
  exit 1
fi

mkdir -p "$path"

curl -L "$url" | tar -x -C "$path"

kernel=$(find "$path" -type f -name "pxeboot.*.kernel" -printf "%P\n" | head -n1)
if [ -z "$kernel" ]; then
  echo "ERROR: Kernel image not found"
  exit 1
fi

initrd=$(find "$path" -type f -name "pxeboot.*.initrd" -printf "%P\n" | head -n1)
if [ -z "$initrd" ]; then
  echo "ERROR: Initrd image not found"
  exit 1
fi

image=$(find "$path" -type f -name "*.xz" -printf "%P\n" | head -n1)
if [ -z "$image" ]; then
  echo "ERROR: PXE root image not found"
  exit 1
fi

bootparams=$(find "$path" -type f -name "*.append" | head -n1)
if [ -z "$bootparams" ]; then
  echo "ERROR: Boot options file not found"
  exit 1
else
  bootparams=$(cat "$bootparams")
fi

if [ -z "$bootparams" ]; then
  echo "ERROR: Boot options file is empty"
  exit 1
else
  # replace the example image URL with the real server URL
  # the "pxe-server" DNS name is configured in /etc/NetworkManager/dnsmasq-shared.d/pxe-server.conf
  bootparams="${bootparams//http:\/\/example.com\/image.xz/$server\/$dir\/$image}"
fi

echo
echo "PXE Boot configuration:"
echo "-----------------------"
echo "Location:     $path"
echo "Kernel:       $kernel"
echo "Initrd:       $initrd"
echo "Root image:   $image"
echo "Boot options: $bootparams"
echo

echo "Updating BIOS boot menu ($bios_menu)"
sed -e "s#%KERNEL%#$dir/$kernel#" -e "s#%INITRD%#$dir/$initrd#"  -e "s#%BOOTPARAMS%#$bootparams#"  \
  -e "s#%LABEL%#$label#"  -e "s#%DIR%#$dir#" << EOF >> "$bios_menu"
LABEL %DIR%
  MENU LABEL %LABEL%
  KERNEL %KERNEL%
  INITRD %INITRD%
  APPEND %BOOTPARAMS%


EOF

echo "Updating UEFI boot menu ($uefi_menu)"
sed -e "s#%KERNEL%#$dir/$kernel#" -e "s#%INITRD%#$dir/$initrd#"  -e "s#%BOOTPARAMS%#$bootparams#"  \
  -e "s#%LABEL%#$label#"  -e "s#%DIR%#$dir#" << EOF >> "$uefi_menu"
menuentry '%LABEL%' {
  set gfxpayload=keep
  echo 'Loading kernel ...'
  linuxefi %KERNEL% %BOOTPARAMS%
  echo 'Loading initrd ...'
  initrdefi %INITRD%
}


EOF
