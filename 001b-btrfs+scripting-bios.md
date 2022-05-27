# Description

This is an alternative version of [001-btrfs+scripting.md](./001-btrfs+scripting.md) done with Legacy Bios/MBR partitioning instead of UEFI/GPT partitioning. This mostly affects disk-related commands (partitioning, mount, fstab generation, grub generation)

The partitioning, is also different in that it uses only a ext4 /boot partition instead of a fat32 /boot/efi partition.


## MBR partitioning setup:

* `fdisk /dev/vda` with mbr label (`o` in `fdisk`)
* /dev/vda1: 1 GB /boot partition as ext4 (same as Anaconda's Automatic partitioning)
* /dev/vda2: 4 GB partition as swap (`t` in `fdisk`, then type of `19`)
* /dev/vda3: remaining space as btrfs partition

## Commands

Pre-chroot

    su -
    setenforce 0;
    test -d /sys/firmware/efi && echo 'uefi' || echo 'bios';
    alias l='ls -acl'; alias up='cd ..'; alias up2='cd ../..'; alias q='exit';
    printf '%s\n%s\n%s\n%s\n%s\n%s\n' 'd' '3' 'd' '2' 'd' 'w' | fdisk /dev/vda; wipefs --all /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n' 'o' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n%s\n\n%s\n%s\n%s\n' 'n' 'p' '1' '+1G' 'Y' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n%s\n' 'a' '1' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n%s\n\n%s\n%s\n%s\n' 'n' 'p' '2' '+4G' 'Y' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n%s\n%s\n' 't' '2' '82' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
    printf '%s\n%s\n%s\n\n\n%s\n%s\n' 'n' 'p' '3' 'Y' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;

    mkfs.ext4 -F -L bootpart /dev/vda1;
    mkswap /dev/vda2;
    mkfs.btrfs -L ospart --force /dev/vda3;
    mount /dev/vda3 /mnt;
    btrfs subvolume create /mnt/@fedora-root;
    btrfs subvolume create /mnt/@fedora-home;
    ls -acl /mnt;
    umount /mnt;
    mount -o noatime,compress=zstd:1,subvol=@fedora-root /dev/vda3 /mnt;
    mkdir -p /mnt/home /mnt/boot;
    mount -o noatime,compress=zstd:1,subvol=@fedora-home /dev/vda3 /mnt/home;
    mount /dev/vda1 /mnt/boot;
    dnf --releasever=36 --installroot=/mnt -y groupinstall core;
    for dir in sys dev proc ; do mount --rbind /$dir /mnt/$dir && mount --make-rslave /mnt/$dir ; done;
    /usr/bin/cp --remove-destination /etc/resolv.conf /mnt/etc/resolv.conf;
    systemd-firstboot --root=/mnt --timezone=America/New_York --hostname=fed-bootstrap --setup-machine-id;
    printf '%s\n%s\n%s\n%s\n' "alias l='ls -acl'" "alias up='cd ..'" "alias up2='cd ../..'" "alias q='exit'" >> /mnt/root/.bashrc;
    printf '%s\n%s\n%s\n' "alias pg='pgrep -ifa'" "alias pk='pkill -9 -if'" "alias e='echo'" >> /mnt/root/.bashrc;
    chroot /mnt /bin/bash;

Inside Chroot

    NEWUSER='test';useradd --shell /bin/bash $NEWUSER; usermod -aG wheel $NEWUSER;
    NEWPASS='vm123'; printf '%s\n%s\n' "$NEWPASS" "$NEWPASS" | passwd $NEWUSER;
    NEWPASS='vm123'; printf '%s\n%s\n' "$NEWPASS" "$NEWPASS" | passwd root;
    printf '%s\n%s\n%s\n%s\n' "alias l='ls -acl'" "alias up='cd ..'" "alias up2='cd ../..'" "alias q='exit'" >> /home/$NEWUSER/.bashrc;
    printf '%s\n%s\n%s\n' "alias pg='pgrep -ifa'" "alias pk='pkill -9 -if'" "alias e='echo'" >> /home/$NEWUSER/.bashrc;
    dnf install -y glibc-langpack-en; systemd-firstboot --locale=en_US.UTF-8;
    rootsubvol="$(mount | grep -P 'vda3.*\s+/\s+.*btrfs'|sed -E 's/^.*subvol=\/?([^,)]+).*$/\1/g')";
    homesubvol="$(mount | grep -P 'vda3.*\s+/home\s+.*btrfs'|sed -E 's/^.*subvol=\/?([^,)]+).*$/\1/g')";
    rm -f /etc/fstab;
    printf 'UUID=%s  /  btrfs  subvol=%s,compress=zstd:1 0 0\n' "$(blkid -s UUID -o value /dev/vda3)" "$rootsubvol" >> /etc/fstab;
    printf 'UUID=%s  /boot  ext4 defaults        1 2\n' "$(blkid -s UUID -o value /dev/vda1)" >> /etc/fstab;
    printf 'UUID=%s  /home  btrfs  subvol=%s,compress=zstd:1 0 0\n' "$(blkid -s UUID -o value /dev/vda3)" "$homesubvol" >> /etc/fstab;
    echo "tmpfs /tmp tmpfs rw,seclabel,nosuid,nodev,inode64 0 0" >> /etc/fstab;
    printf 'UUID=%s  swap swap defaults 0 0\n' "$(blkid -s UUID -o value /dev/vda2)" >> /etc/fstab;
    clear;echo "-------------------"; cat /etc/fstab;
    dnf install -y btrfs-progs e2fsprogs vim tree;
    dnf install -y kernel grub2-pc-modules grub2-efi-x64 grub2-efi-x64-modules shim;
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux;
    grep ^SELINUX= /etc/sysconfig/selinux;
    dnf reinstall -y grub2-common;
    grub2-install /dev/vda;
    grub2-mkconfig -o /boot/grub2/grub.cfg;
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
    restorecon -R /;
    reboot now;

status:

* no issues booting to minimal install after bootstrap
* selinux seems to be running fine
* installing xfce took forever... I know I'm on vpn but still
* Had an error booting to graphical session on first attempt (hung dring bootup); hard-powered off and tried again
* No issues booting to Xfce on 2nd, 3rd, or 4th attempts
