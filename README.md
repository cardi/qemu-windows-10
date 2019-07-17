# qemu-windows-10

Some notes and a starter script on getting a Windows 10 guest running on
a Linux (Debian) host using QEMU.

*Note*: Still a work in progress. See [start.sh](./start.sh) for the
script.

## Hardware Requirements

The main thing you need is VT-d support on your processor.

I have a dedicated GPU and HDD for Windows.
If you plan on sharing the GPU or using a filesystem container, tweak
  the configuration as needed.

It's useful to have a separate keyboard/mouse for Windows' exclusive
  use, but not necessary.
If you only have one kb/m, the Windows guest will "take" it while
  it's running, and then "release" it once it's shutdown.
This can be inconvenient if you're still tweaking the config.

## Software Requirements

* Linux kernel 4.1+ (vfio, iommu support)
* `qemu-kvm`
* `ovmf` (latest tarball from Fedora's website?)
* `hugepages`
* [virtio-win.iso][virtio-win.iso]

[virtio-win.iso]: https://fedoraproject.org/wiki/Windows_Virtio_Drivers

Some guides and tutorials will use `virt-manager`.
Since my Linux install is rather lean, I've done all of the
  configuration by hand (and won't cover virt-manager here).

## Software Configuration

*Note*: section is incomplete.

`/etc/default/grub` (then run `update-grub`):
~~~~
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
~~~~

`/etc/modules`:
~~~~
vfio
vfio_iommu_type1
vfio_pci
kvm
kvm_intel
~~~~

Generally your GPU will have two device IDs under `lspci`, the "VGA
Compatible Controller" and an associated "Audio device". Passing both is
useful, especially if you want to use audio passthrough with HDMI or
DisplayPort.

`/etc/modprobe.d/vfio-pci.conf`:
~~~~
options vfio-pci ids=YOUR_IDS_HERE
~~~~

## Configuring the VM

**Configure the options for your VM in [start.sh](./start.sh) before
attempting to run it.**

This script is highly dependent on your hardware and host OS, and it's
advisable to go through it line-by-line to understand what options
you're passing to QEMU.

### USB Devices

The old way of using `-usbdevice` has been deprecated. See the script or
[QEMU/USB Quick Start][qemu-usb-qs] for more details on specifying USB
devices.

Ideally, use the `qemu-xhci` controller device (qemu-2.10+) to minimize
CPU overhead, but the current version on Debian Stretch is qemu-2.8,
requiring the use of `nec-usb-xhci`--not sure of what the performance
impact is.

If you don't specify a USB host controller, QEMU defaults to a slower (I
think) one.

This can be problematic in non-obvious ways: for example, if you wanted
to connect and use an Xbox Controller for Windows, Windows 10 might
recognize and install drivers for the Xbox Controller but won't
initialize it properly (Code 10). This can be resolved by specifying an
XHCI or EHCI controller and attaching it to that bus (on this particular
[Reddit thread](https://old.reddit.com/r/Windows10/comments/7v4jc2/xbox_one_wireless_adapter_for_windows_10_code_10/),
an EHCI/USB-2.0 only controller needed to be specified).

**References**:
* [QEMU/USB Quick Start][qemu-usb-qs]
* [QEMU USB Controllers](https://en.wikibooks.org/wiki/QEMU/Devices/USB/Root)

[qemu-usb-qs]: https://git.qemu.org/?p=qemu.git;a=blob;f=docs/usb2.txt;h=172614d3a7e0566c2cdd988d72a1674b73f879fe;hb=HEAD

## Running the VM

[start.sh](./start.sh)

Run as `root`. There is a way to run it as a less-privileged user, but I
haven't gotten around to configuring that yet.

Load the Windows 10 installation ISO and virtio-win.iso as options
passed to `-cdrom` for the initial install, then comment those lines out
on subsequent reboots (after the Windows installation is complete).

In the Windows 10 install process, you might need to load device drivers
before it recognizes your disks.

## TODO

Sections I haven't quite fully documented.

* hugepages
* file sharing
* BIOS/UEFI boot priority - if you install Windows directly to another
  disk (without using a container), the BIOS/UEFI will detect it as a
  possible boot device and attempt to load it.
* audio

### CPU-pinning with `taskset`

Set aside various cores for QEMU's use.

You'll also want to be mindful of any additional computations on the
host. For example, if you run a heavy job on the host without specifying
which CPUs it should or shouldn't use, you'll start sharing with the
Windows 10 guest, leading to terrible performance on the guest.

See the script for some details.

### Audio

Getting audio working on the guest was a bit tricky. You might face some
issues with scratchy, delayed, or even loss of sound, most of which I
won't cover here since I did not experience it.

There are different ways to do audio:

1. guest passes through audio to host setup: I attempted to set this up,
   but this solution seemed to introduce additional problems. It might
   work well if you have audio working properly on the host OS.
2. PCIe soundcard passthrough: untested.
3. HDMI/DP-passthrough (via graphics card): seems to work well, but I am
   using the DVI output of my graphics card.
4. USB headset or USB sound card passthrough: this worked the best and
   what I currently use.

**Note**: Having multiple sound devices (#3 and #4) seemed to result in
audio intermittently working, with either lots of lag or no sound at
all.

There is some issue with drivers, latency, audio buffers, and timing,
but what I found solved this issue was to have only *one* device enabled
in the start script at one time. In my case, I disabled passing through
the audio device on the graphics card and only passed through the USB
headset: all works well now.

### Force Windows to use MSI on GPU

Increased performance. Some [documentation][vfio-msi].

[vfio-msi]: https://vfio.blogspot.com/2014/09/vfio-interrupts-and-how-to-coax-windows.html

MSI supported, but not enabled:
~~~~
# lspci -v -s 2:00.0
02:00.0 VGA compatible controller: NVIDIA Corporation GP106 [GeForce GTX 1060 3GB] (rev a1) (prog-if 00 [VGA controller])
        ...
        Capabilities: [68] MSI: Enable- Count=1/1 Maskable- 64bit+
        ...
        Kernel driver in use: vfio-pci
        Kernel modules: nouveau
~~~~

MSI supported, and enabled in Windows 10 guest:
~~~~
# lspci -v -s 2:00.0
02:00.0 VGA compatible controller: NVIDIA Corporation GP106 [GeForce GTX 1060 3GB] (rev a1) (prog-if 00 [VGA controller])
        ...
        Capabilities: [68] MSI: Enable+ Count=1/1 Maskable- 64bit+
        ...
        Kernel driver in use: vfio-pci
        Kernel modules: nouveau
~~~~

## Resources

* https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF
* https://davidyat.es/2016/09/08/gpu-passthrough/

## LICENSE

[`CC0-1.0` / CC0-1.0 Universal](./LICENSE)
