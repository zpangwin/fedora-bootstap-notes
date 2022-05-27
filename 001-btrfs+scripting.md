# Description

This is basically my just tweaking the install I had done in [000-reckzero-bootstrap-setup.md](./000-reckzero-bootstrap-setup.md). In this iteration, I was focusing mostly on writing scriptlets/one-liners/etc to reduce time spent typing responses into prompts and semi-automate the bootstrap process. After I get things working the way I want, I might finalize these into scripts and add links but for now, they're copy/paste.

I didn't allocate as much RAM to my VM so I'm onlu giving 4G RAM to swap instead of the 12GB used in the video.

Finally, I want to end up with btrfs and I figured that would be a pretty small change so I made that switch too. Currently, I'm just using an unnamed / default subvolume (e.g. `subvol=/`); nothing fancy.

As in the original video will setup a basic (no desktop) Fedora install, then from there install Xfce and boot to desktop. Mostly the same as the original except my user is named "test" instead. :-)


## UEFI partitioning setup:

* `fdisk /dev/vda` with gpt label (`g` in `fdisk`)
* /dev/vda1: 512 MB partition as EFI (`t` in `fdisk`, then type of `1`) => `/boot/efi`
* /dev/vda2: 4 GB partition as swap (`t` in `fdisk`, then type of `19`)
* /dev/vda3: remaining space as btrfs partition

## Commands

Pre-chroot

    su -
    setenforce 0;
    test -d /sys/firmware/efi && echo 'uefi' || echo 'bios';
    alias l='ls -acl'; alias up='cd ..'; alias up2='cd ../..'; alias q='exit';
    printf '%s\n%s\n%s\n%s\n%s\n%s\n' 'd' '3' 'd' '2' 'd' 'w' | fdisk /dev/vda; wipefs --all /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n' 'g' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n\n%s\n%s\n%s\n' 'n' '1' '+512M' 'Y' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n%s\n' 't' '1' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n\n%s\n%s\n%s\n' 'n' '2' '+4G' 'Y' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n%s\n%s\n' 't' '2' '19' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n\n\n%s\n%s\n' 'n' '3' 'Y' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;

    mkfs.vfat /dev/vda1;
    mkswap /dev/vda2;
    mkfs.btrfs --force /dev/vda3;
    mount /dev/vda3 /mnt;
    mkdir -p /mnt/boot/efi /mnt/home;
    mount /dev/vda1 /mnt/boot/efi;
    dnf --releasever=36 --installroot=/mnt -y groupinstall core;
    for dir in sys dev proc ; do mount --rbind /$dir /mnt/$dir && mount --make-rslave /mnt/$dir ; done;
    /usr/bin/cp --remove-destination /etc/resolv.conf /mnt/etc/resolv.conf;
    systemd-firstboot --root=/mnt --timezone=America/New_York --hostname=fed-bootstrap --setup-machine-id;
    printf '%s\n%s\n%s\n%s\n' "alias l='ls -acl'" "alias up='cd ..'" "alias up2='cd ../..'" "alias q='exit'" >> /mnt/root/.bashrc;
    printf '%s\n%s\n%s\n' "alias pg='pgrep -ifa'" "alias pk='pkill -9 -if'" "alias e='echo'" >> /mnt/root/.bashrc;
    chroot /mnt /bin/bash;

Inside Chroot

    dnf install -y glibc-langpack-en; systemd-firstboot --locale=en_US.UTF-8;
    useradd --shell /bin/bash test; usermod -aG wheel test;
    passwd test
    passwd
    rootsubvol='/';
    printf 'UUID=%s  /  btrfs  subvol=%s,compress=zstd:1 0 0\n' "$(blkid -s UUID -o value /dev/vda3)" "$rootsubvol" >> /etc/fstab;
    printf 'UUID=%s  /boot/efi  vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro 0 0\n' "$(blkid -s UUID -o value /dev/vda1)" >> /etc/fstab;
    echo "tmpfs /tmp tmpfs rw,seclabel,nosuid,nodev,inode64 0 0" >> /etc/fstab;
    printf 'UUID=%s  swap swap defaults 0 0\n' "$(blkid -s UUID -o value /dev/vda2)" >> /etc/fstab;
    clear;echo "-------------------"; cat /etc/fstab;
    dnf install -y btrfs-progs e2fsprogs vim tree;
    dnf install -y kernel grub2-efi-x64 grub2-efi-x64-modules shim;
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux;
    grep ^SELINUX= /etc/sysconfig/selinux;
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
