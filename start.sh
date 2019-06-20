#!/bin/bash

# start.sh
# enable or disable OPTS as needed

OPTS=""
OPTS="$OPTS -serial none -parallel none"
OPTS="$OPTS -nodefaults"
OPTS="$OPTS -name windows"
OPTS="$OPTS -rtc clock=host,base=localtime"
# Basic CPU settings.
#OPTS="$OPTS -cpu host,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,hv_vendor_id=Nvidia43FIX"
# remove hv_time to see if anything happens
#OPTS="$OPTS -cpu host,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_vendor_id=Nvidia43FIX"
OPTS="$OPTS -cpu host,kvm=off"
OPTS="$OPTS -smp 8,sockets=1,cores=4,threads=2"
# Enable KVM full virtualization support.
OPTS="$OPTS -enable-kvm"
# Assign memory to the VM. Hugepages requires additional configuration.
OPTS="$OPTS -m 16G"
OPTS="$OPTS -mem-path /dev/hugepages"
OPTS="$OPTS -mem-prealloc"
# VFIO GPU and GPU sound passthrough.
OPTS="$OPTS -device vfio-pci,host=02:00.0,multifunction=on"
OPTS="$OPTS -device vfio-pci,host=02:00.1"
# Supply OVMF (general UEFI bios, needed for EFI boot support with GPT disks).
OPTS="$OPTS -drive if=pflash,format=raw,readonly,file=/usr/share/OVMF/OVMF_CODE.fd"
OPTS="$OPTS -drive if=pflash,format=raw,readonly,file=/usr/share/OVMF/OVMF_VARS.fd"

# Load our created VM image as a harddrive.
#
# NOTE: Giving the VM *raw* disk access can lead to unintended things
# happening. Do this only if you're giving the VM dedicated and
# exclusive access to the HDD.
#
OPTS="$OPTS -device virtio-scsi-pci,id=scsi"
OPTS="$OPTS -drive file=/dev/disk/by-id/ata-YOUR_DRIVE_HERE,cache=none,if=virtio,format=raw"

# Load our OS setup image e.g. ISO file.
#OPTS="$OPTS -cdrom $(pwd)/en_windows_10_education_version_1607_updated_jul_2016_x64_dvd_9055880.iso"
# load virtio drivers
#OPTS="$OPTS -cdrom $(pwd)/virtio-win.iso"
# Use the following emulated video device (use none for disabled).
OPTS="$OPTS -vga none"
# running from the shell
OPTS="$OPTS -nographic"
# Redirect QEMU's console input and output.
OPTS="$OPTS -monitor stdio"

# (qemu-2.10+) Use QEMU's XHCI host adapter support for USB 1.1, 2, 3
# This has the added benefit of not requiring the user to specify the
# bus.
# See https://git.qemu.org/?p=qemu.git;a=blob;f=docs/usb2.txt;h=172614d3a7e0566c2cdd988d72a1674b73f879fe;hb=HEAD
#OPTS="$OPTS -device qemu-xhci"

# Otherwise, use the other XHCI controller (USB 1.1, 2, 3) if you're
# running qemu < 2.10:
# https://en.wikibooks.org/wiki/QEMU/Devices/USB/Root
OPTS="$OPTS -device nec-usb-xhci,id=xhci"

# Or if you need USB 2.0 support only
#OPTS="$OPTS -device usb-ehci,id=ehci"

# Passthrough USB devices.
OPTS="$OPTS -usb"
# USB mouse
OPTS="$OPTS -device usb-host,bus=xhci.0,vendorid=0xdead,productid=0xbeef"
# USB keyboard
OPTS="$OPTS -device usb-host,bus=xhci.0,vendorid=0xdead,productid=0xbeef"

# Network configuration
#
# See qemu documentation for more details, but '-net user' will put the
# VM in its own subnet that only the host can access. The Windows VM
# will be able to initiate communications on the LAN and WAN.
#
# Passing the 'smb=/path/' option will start QEMU's Samba server on the
# host that the guest can access. It does have read/write access to the
# shared folder (depending on the permissions or mount options you've
# set).  If you need a more complex configuration, then you'll probably
# want to set up your own Samba server.
#
#OPTS="$OPTS -net nic -net user"
OPTS="$OPTS -net nic -net user,smb=/shared/"

# first two options are related to audio configuration
# 'taskset' pins qemu to certain CPUs for more consistent performance
# (otherwise qemu seems switch to whichever cores it feels like).
QEMU_AUDIO_DRV=pa QEMU_PA_SAMPLES=128 taskset -c 21-31 qemu-system-x86_64 $OPTS
