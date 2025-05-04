# PXE boot server

This repository contains sources for a simple PXE boot server Live ISO.

The purpose of this Live ISO is to allow testing of the [Agama
installer](https://github.com/agama-project/agama) PXE images in an easy way.

## Live ISO download

The Live ISO is built in the
[home:lslezak:pxe-boot-server](
https://build.opensuse.org/package/show/home:lslezak:pxe-boot-server/pxe-boot-server)
OBS project. The built Live ISO can be downloaded from [this OBS repository](
https://download.opensuse.org/repositories/home:/lslezak:/pxe-boot-server/images/iso/).

## Usage

The Live ISO can be booted in a virtual machine or bare metal. The PXE boot
images are by default stored in RAM. But it is possible to [manually switch]()
to a disk.

## Minimal requirements

- Network card (even virtual) connected to a network without any existing DHCP
  server
- At least 1 or 2 GB RAM (depends on the size of the served PXE images, when
  using a persistent storage it should work even with 512MB RAM)

### Required network configuration

The most tricky part about the PXE boot is that it requires support on the DHCP
server.

In most cases the DHCP server does not support that (e.g. most of the home Wifi
routers) or you do not have permission for that (company network) or there
already is a boot server (server room).

So the solution is to run your own DHCP server in an isolated network (physical
or virtual).

## Example usage

Using an isolated network is usually simple with virtual machines.

### VirtualBox

Here is a documentation for VirtualBox virtualization but you can use a similar
approach for other systems as well.

#### PXE boot server VM

1. Create a Linux virtual machine, attach the PXE boot live ISO into the
   virtual CD drive. Make sure it has at least 1 GB RAM.
2. Go to the network configuration and in the "Attached to" list select the
   "Internal network" option. Put a network name to the "Name" field. You can
   keep the "intnet" default if it is not used yet, otherwise use a different
   name.
3. It is recommended to add a second network adapter, this time attached as
   "Bridged adapter" or "NAT". The network traffic from the internal network
   will be routed to this adapter and the PXE clients will have internet
   connection. Otherwise you have to configure an installation server in the
   internal network.
4. Start the VM, the boot server will be started at the internal network
   adapter.

#### PXE boot client VM

1. Create a Linux virtual machine.
2. In the system settings enable booting from network and move it to the first
   position so the boot from network is preferred.
3. Go to the network configuration and in the "Attached to" list select the
   "Internal network" option, in the "Name" field use the same network name as
   in the boot server.
4. Unfortunately not all emulated network cards support network boot, go to the
   "Advanced" section and select any Intel network card for emulation, those
   work fine. If you enable EFI mode you can also use the Virtio adapter (but is
   not supported in classic BIOS boot).
5. Boot the machine, in BIOS mode it should boot from the PXE server, in EFI
   mode you might need to go to the "Boot manager" EFI menu and select the "UEFI
   PXEv4" option.

## Managing the boot server

You can manage the boot server locally or remotely.

### Local login

You can login as root on the console with the printed random password.

It is possible to set the root password using the `live.passord=<password>` boot
option or you can set the password interactively during boot using the
`live.password_dialog=1` or `live.password_systemd=1` boot options.

### Root console

A root shell is running at the `tty8` console, you can switch to it with
`Alt+F8` keyboard shortcut.

### SSH login

The SSH access is enabled, the mDNS name is set to `pxe-server` so if your
client enables mDNS you can login with `ssh root@pxe-server.local`.

## Downloading PXE images

The boot server contains a helper script `download-pxe-image.sh` which can
automate downloading and integrating the PXE boot images built by [openSUSE
Build Service](openSUSE Build Service) (OBS).

See more details in [separate documentation](
live-root/srv/tftpboot/README.md#downloading-pxe-images).

## Using the QEMU built-in boot server

```sh
# create a directory for storing the PXE images
mkdir tftpboot
# initialize the content, create initial boot menu
download-pxe-image.sh -i -r tftpboot

# in a separate terminal start HTTP server for downloading the root images,
# darkhttpd is just an example, you might use a different server or even
# a different protocol (like FTP)
darkhttpd tftpboot --port 8080

# download the openSUSE Tumbleweed PXE image
# -s sets download server for the root image
# use the same port as for the HTTP server above
download-pxe-image.sh -r tftpboot -s http://10.0.2.2:8080 -d Tumbleweed -u https://download.opensuse.org/tumbleweed/appliances/agama-installer.x86_64-openSUSE_PXE.install.tar -l "Install openSUSE Tumbleweed ($(date "+%F %H:%M"))"

# create a disk image
qemu-img create -f qcow2 disk.qcow2 16G
# start VM, boot from the embedded PXE server
qemu-kvm -cpu host -m 4G -hda disk.qcow2 -net nic -net user,tftp=tftpboot,bootfile=pxelinux.0 -boot n
```

See some more [examples](live-root/root/.bash_history) for downloading the PXE
images.

### Alternatives for the HTTP server

The HTTP server is not required for downloading the root image, it it possible
to use any protocol supported by curl.

#### Samba

QEMU has a [built-in Samba
server](https://wiki.archlinux.org/title/QEMU#QEMU's_built-in_SMB_server) and
curl supports downloading from a SMB share so in theory the HTTP server should
not be needed and it should be possible to serve the root image via a Samba
share. However, for some reason this did not work for me in openSUSE Leap 15.6,
the Samba server was not started. 😟

#### TFTP

The root image can downloaded using the TFTP protocol in the same way as the
kernel image or initd. But it is very slow. The TFTP protocol was designed to be
very simple (as the name suggests), it was not intended for downloading huge
files.

While downloading an image via HTTP takes just few seconds in local network,
using TFTP the same image will take 4-5 minutes to download.

It is possible to increase the download block size for more effective download,
but it will still take about 2 minutes.

If you really want to use the TFTP protocol for downloading the root image the
use the `-s tftp://10.0.2.2` option to specify the protocol and the server and
use `-b systemd.default_device_timeout_sec=300
rd.kiwi.install.pxe.curl_options=--tftp-blksize,65000` to increase the systemd
timeout and the transfer block size.

## Implementation details

*TBD*

### Network configuration

*TBD*

### Boot server configuration

*TBD*
