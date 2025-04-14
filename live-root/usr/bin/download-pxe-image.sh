#! /bin/bash

# This script downloads and installs a PXE image.

usage () {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -d <dir>   - directory where to unpack the archive"
  echo "  -u <url>   - PXE image URL (a tar archive)"
  echo "  -l <label> - PXE boot menu label"
  echo "  -h         - print this help"
}

# process command line arguments
while getopts ":d:hl:u:" opt; do
  case ${opt} in
    d)
      dir="${OPTARG}"
      ;;
    h)
      usage
      exit 0
      ;;
    l)
      label="${OPTARG}"
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

prefix="/srv/tftpboot/"
path="$prefix$dir"

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
  bootparams=$(echo "$bootparams" | sed -e "s#http://example\.com/image\.xz#http://pxe-server/$dir/$image#" )
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

bios_menu="/srv/tftpboot/pxelinux.cfg/default"
echo "Updating BIOS boot menu ($bios_menu)"

sed -e "s#%KERNEL%#$dir/$kernel#" -e "s#%INITRD%#$dir/$initrd#"  -e "s#%BOOTPARAMS%#$bootparams#"  \
  -e "s#%LABEL%#$label#"  -e "s#%DIR%#$dir#" /srv/tftpboot/pxelinux.cfg/menu.template >> \
  "$bios_menu"

uefi_menu="/srv/tftpboot/grub.cfg"
echo "Updating UEFI boot menu ($uefi_menu)"
sed -e "s#%KERNEL%#$dir/$kernel#" -e "s#%INITRD%#$dir/$initrd#"  -e "s#%BOOTPARAMS%#$bootparams#"  \
  -e "s#%LABEL%#$label#"  -e "s#%DIR%#$dir#" /srv/tftpboot/menu.template >> \
  "$uefi_menu"
