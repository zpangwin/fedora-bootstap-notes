# Description

This is basically my just tweaking the install I had done in [reckzero-uefi-ext4-bootstrap-setup.md](./reckzero-uefi-ext4-bootstrap-setup.md) . In this iteration, I was focusing mostly on writing scriptlets/one-liners/etc to reduce time spent typing responses into prompts and semi-automate the bootstrap process. After I get things working the way I want, I might finalize these into scripts and add links but for now, they're copy/paste.

One of my goals is also to eventually tweak the instructions from the install to get as close as possible to a minimal install done normally with Anaconda from the ["Everything" netinstall iso](https://alt.fedoraproject.org/).


## Virt-manager configuration

Host:

* CPU: AMD FX-9590 with 8-cores
* Memory: 32 GiB RAM
* OS: Fedora 35

My guest VMs were created in virt-manager with the following attributes:

* Memory: 4096 bytes (e.g. 4 GiB)
* CPUs: 2 (e.g. 2 cores)
* 20 GiB virtual HDD space
* UEFI\* / Q35 chipset (I did not use the secure boot option for this iteration).
* defaults for everything else

\* By default virt-manager creates all VMs using legacy bios firmware. You can only change this from the virt-manager GUI during the creation phase by selecting the option to customize

To use UEFI in virt-manager, you must check the box for "Customize configuration before install" on the final step before before clicking the "Finish" button. If you've checked the box, then after clicking "Finish" it should take you to the Overview tab for the configuration. The very last option on this tab should be a dropdown labeled "firmware". I selected `UEFI x86_64: /usr/share/edk2/ovmf/OVMF_CODE.fd` from this dropdown then hit the "Begin Installation" button in the top-left corner.

If you have already created a VM and either were not aware of this option or forget to set it before you started the VM, then there is no way to change the firmware from the GUI that I'm aware of. You will instead need to completely shut-off / stop the VM then use the terminal to edit the firmware.


## Changes from ReckZero version

1. Removed swap partition; I consider these option since Anaconda with Automatic partitioning doesn't create them.
2. I will be using the btrfs filesystem instead of ext4 for the root partition. However, I will not be using any named subvolumes in this iteration (or technically speaking, I am using an unnamed subvolume, e.g. `subvol=/`).
3. Since I plan on eventually duplicating "Anaconda with Automatic partitioning", I will be creating a `/boot` partition as a placeholder. This partition is *NOT* strictly required, nor actually even used by this particular iteration.
4. Since I have more installs to do, I won't be installing a desktop in all of the tests. I will only be confirming that I can boot into a minimal install and login with both root and a "test" account.
5. I will be attempting to reduce prompts as much as possible so you will see me piping responses to various commands like `fdisk` and `passwd` as well as using flags like `dnf install -y` or `rm -rf` to avoid prompts.

**All commands below assume that this is running in a VM. You should pratice in a VM first, make your *own* carefully reviewed notes, and understand all commands before running these commands against a real, baremetal system. Backups are YOUR responsibility. These notes are for *my* reference only so don't blame me if you mess up your system because you ran something you didn't understand. My notes are provided AS-IS with no warranty whatsoever, either express or implied.**

You have been warned. ;-)


## UEFI partitioning setup:

* `fdisk /dev/vda` with gpt label (`g` in `fdisk`)
* /dev/vda1: 512 MB partition as EFI (`t` in `fdisk`, then type of `1`) => `/boot/efi`
* /dev/vda2: 8 GB partition as swap (`t` in `fdisk`, then type of `19`)
* /dev/vda3: remaining space as btrfs partition

## Commands

Pre-chroot

    su -
    setenforce 0;
    alias l='ls -acl'; alias up='cd ..'; alias up2='cd ../..'; alias q='exit';
    printf '%s\n%s\n%s\n%s\n%s\n%s\n' 'd' '3' 'd' '2' 'd' 'w' | fdisk /dev/vda; wipefs --all /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n' 'g' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n\n%s\n%s\n%s\n' 'n' '1' '+512M' 'Y' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n%s\n' 't' '1' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n\n%s\n%s\n%s\n' 'n' '2' '+8G' 'Y' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n%s\n%s\n' 't' '2' '19' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n\n\n%s\n%s\n' 'n' '3' 'Y' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;

    mkfs.vfat /dev/vda1;
    mkswap /dev/vda2;
    mkfs.btrfs --force /dev/vda3;
    mount /dev/vda3 /mnt;
    mkdir -p /mnt/boot/efi;
    mount /dev/vda1 /mnt/boot/efi;
    dnf --releasever=36 --installroot=/mnt -y groupinstall core;
    for dir in sys dev proc ; do mount --rbind /$dir /mnt/$dir && mount --make-rslave /mnt/$dir ; done;
    rm -f /mnt/etc/resolv.conf;
    cp /etc/resolv.conf /mnt/etc/;
    systemd-firstboot --root=/mnt --timezone=America/New_York --hostname=fed-strap --setup-machine-id;
    printf '%s\n%s\n%s\n%s\n' "alias l='ls -acl'" "alias up='cd ..'" "alias up2='cd ../..'" "alias q='exit'" >> /mnt/root/.bashrc
    printf '%s\n%s\n%s\n' "alias pg='pgrep -ifa'" "alias pk='pkill -9 -if'" "alias e='echo'" >> /mnt/root/.bashrc
    chroot /mnt /bin/bash

Inside Chroot

    dnf install -y glibc-langpack-en; systemd-firstboot --locale=en_US.UTF-8;
    useradd --shell /bin/bash test; usermod -aG wheel test;
    passwd test
    passwd
    printf '%s  /  btrfs  subvol=%s,compress=zstd:1 0 0\n' "$(blkid -s UUID -o value /dev/vda3)" "/" >> /etc/fstab;
    printf '%s  /boot/efi  vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro 0 0\n' "$(blkid -s UUID -o value /dev/vda1)" >> /etc/fstab;
    echo "tmpfs /tmp tmpfs rw,seclabel,nosuid,nodev,inode64 0 0" >> /etc/fstab;
    printf '%s  swap swap defaults 0 0\n' "$(blkid -s UUID -o value /dev/vda2)" >> /etc/fstab;
    clear;echo "-------------------"; cat /etc/fstab;
    dnf install -y btrfs-progs e2fsprogs vim;
    dnf install -y kernel grub2-efi-x64 grub2-efi-x64-modules shim;
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux;
    grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg;
    dracut --regenerate-all --force;
    systemctl enable NetworkManager;
    systemctl disable NetworkManager-wait-online.service;
    systemctl mask lvm2-monitor.service systemd-udev-settle.service;
    restorecon -R /boot /etc /home /opt /root /usr /var;
    exit;

Fstab contents

    UUID=(uuid of vda3 aka os part)  /          ext4  rw,seclabel,relatime 0 0
    UUID=(uuid of vda1 aka efi part) /boot/eti  vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro 0 0
    tmpfs /tmp tmpfs rw,seclabel,nosuid,nodev,inode64 0 0
    UUID=(uuid of vda2 aka swap part) swap swap defaults 0 0

can now reboot. after reboot, login as root:

    getenforce
    // showed as Enforcing
    // weird that /etc/sysconfig/selinux was ignored but I was going to turn it back on anyway
    dnf groupinstall -y 'Xfce Desktop';
    reboot now;

status:

* no issues booting to minimal install after bootstrap
* selinux seems to be running fine
* installing xfce took forever... I know I'm on vpn but still
* no issues booting to / logging into xfce desktop after it eventually finished installing.
