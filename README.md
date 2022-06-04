# fedora-bootstap-notes
notes for bootstrapping fedora (e.g. manually installing a minimal fedora setup using live disc WITHOUT going through the limitations imposed by anaconda)

## Structure

Basically, this repo is just going to contain my notes in markdown (.md) format. The notes will definitely have all the commands I'm using (as my for my own reference as for others) and I may add some bash scripts later.

I am mostly testing test in virt-manager on a Fedora host. And will be doing this in stages, starting from a very basic setup and adding more complexity with each successive test.

My goal is to achieve a system with the following: 

* Notes for both UEFI and Legacy BIOS setups.
* Btrs root partition with subvolumes, possibly with snapshots (need to research further before I decide)
* LUKS2-encryption for the root partition
* Multi-boot via the use of Btrfs subvolumes (e.g. subvolumes for `@fedora-root`, `@arch-root`, etc)
* Explore usage of alternate bootloaders, specifically rEFIned and systemd-boot

Note: That currently these are just *goals* that I would like to achieve; I do **not** have this working via bootstrap yet.


## Description

**All commands below assume that this is running in a VM. You should pratice in a VM first, make your *own* carefully reviewed notes, and understand all commands before running these commands against a real, baremetal system. Backups are YOUR responsibility. These notes are for *my* reference only so don't blame me if you mess up your system because you ran something you didn't understand. My notes are provided AS-IS with no warranty whatsoever, either express or implied.**

You have been warned. ;-)


| Setup name                       | Status | fw    | fs | Subvol | Bootmenu   | LUKS | Swap | Multi-OS | Brief Description |
|:--------------------------------:|:------:|:---------:|:------:|:------:|:------------:|:----:|:----:|:--------:|:-----------------:|
| [reckzero-uefi-ext4-bootstrap-setup.md](./reckzero-uefi-ext4-bootstrap-setup.md) | Retest | UEFI | ext4 | N/A |  GRUB2        | no   | yes  | no       | Following steps from Animortis/ReckZero video |
| [bios-001_btrfs-no-subvols.md](./bios-001_btrfs-no-subvols.md) | Passed | BIOS | btrfs  | none | GRUB2        | no   | no  | no       | focus on scripting prompts + btrfs |
| [uefi-001_btrfs-no-subvols](./uefi-001_btrfs-no-subvols)   | Passed | UEFI | btrfs  | none | GRUB2        | no   | no  | no       | focus on scripting prompts + btrfs |


## Virt-manager configuration

Host:

* CPU: AMD FX-9590 with 8-cores
* Memory: 32 GiB RAM
* OS: Fedora 35
* I had updated virt-manager to use user-space\* (e.g. `qemu://session`) instead of letting it default to running under root.

\* In gtk-based desktops (Gnome/Cinnamon/Xfce/Mate), you can do this by apply the following settings:

    gsettings set org.virt-manager.virt-manager.connections uris "['qemu:///session']"
    gsettings set org.virt-manager.virt-manager.connections autoconnect "['qemu:///session']"
    gsettings set org.virt-manager.virt-manager xmleditor-enabled true
    gsettings set org.virt-manager.virt-manager system-tray true

My guest VMs were created in virt-manager with the following attributes:

* Memory: 4096 bytes (e.g. 4 GiB)
* CPUs: 2 (e.g. 2 cores)
* 20-40 GiB virtual HDD space, depending on the test
* UEFI\* / Q35 chipset (I did not use the secure boot option for this iteration).
* defaults for everything else

\* By default virt-manager creates all VMs using legacy bios firmware. You can only change this from the virt-manager GUI during the creation phase by selecting the option to customize

To use UEFI in virt-manager, you must check the box for "Customize configuration before install" on the final step before before clicking the "Finish" button. If you've checked the box, then after clicking "Finish" it should take you to the Overview tab for the configuration. The very last option on this tab should be a dropdown labeled "firmware". I selected `UEFI x86_64: /usr/share/edk2/ovmf/OVMF_CODE.fd` from this dropdown then hit the "Begin Installation" button in the top-left corner. If you want secure boot, choose the other UEFI option.

If you have already created a VM and either were not aware of this option or forget to set it before you started the VM, then there is no way to change the firmware from the GUI that I'm aware of. You will instead need to completely shut-off / stop the VM then use the terminal to edit the firmware. If you need to do so, then following instructions [here](https://unix.stackexchange.com/questions/612813/virt-manager-change-firmware-after-installation), you can (again VM should be OFF):

1. Find your vm's xml file (e.g. under `~/.config/libvirt/qemu/VM_NAME.xml` if running under user-space or `/etc/libvirt/qemu/VM_NAME.xml` if running under root).

2. Open the appropriate xml file in an editor and add the following as child elements under the `<os>` section, replacing <YOUR_NAME> and <VM_NAME> with the appropriate values:

    <loader readonly='yes' type='pflash'>/usr/share/edk2/ovmf/OVMF_CODE.fd</loader>
    <nvram>/home/<YOUR_NAME>/.config/libvirt/qemu/nvram/<VM_NAME>_VARS.fd</nvram>
 
3. The file refered to in `<nvram>` does not have to exist; it will be created. If running under root, this path should be `/etc/libvirt/qemu/nvram/<VM_NAME>_VARS.fd` instead



## Credits / References

Links to info I used to get started. I had seen a few comments online referring to running `dnf --releasever=XX --installroot=/mnt groupinstall core` but I'm reserving this for pages that had more significant and detailed info than that.

If you are new to this, I highly recommend Animortis Productions' youtube video as it will give you a nice step-by-step for a simple setup and let you get a better understanding of the process before jumping into more complex setups. I have the commands I used for following that the video available in the file: [000-reckzero-bootstrap-setup.md](./reckzero-uefi-ext4-bootstrap-setup.md)


1. Youtube: [Fedora 36 Bootstrap Installation](https://www.youtube.com/watch?v=hjR37L2xC6g), by Animortis Productions, published 2022-May-21.
2. Reddit: [/u/ReckZero](https://www.reddit.com/user/ReckZero)'s [Fedora commandline bootstrap installation](https://www.reddit.com/r/Fedora/comments/uub5b8/fedora_linux_commandline_bootstrap_installation/) post, created 2022-May-21. This mostly is just a post by the video author linking to the youtube video above. Adding in case the reddit thread ends up getting any useful comments later.
