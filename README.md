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

Getting audio was a bit tricky. You might face some issues with
scratchy, delayed, or even loss of sound.

I haven't quite figured out what made my setup work, but I've
experimented with audio through HDMI/DP-passthrough and USB headsets.

Both seem to work reasonably well.

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