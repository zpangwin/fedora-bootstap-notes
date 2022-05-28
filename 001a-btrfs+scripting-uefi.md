# Description

This is basically my just tweaking the install I had done in [000-reckzero-bootstrap-setup.md](./000-reckzero-bootstrap-setup.md). In this iteration, I was focusing mostly on writing scriptlets/one-liners/etc to reduce time spent typing responses into prompts and semi-automate the bootstrap process. After I get things working the way I want, I might finalize these into scripts and add links but for now, they're copy/paste.

Finally, I want to end up with btrfs and I figured that would be a pretty small change so I made that switch too.

As in the original video will setup a basic (no desktop) Fedora install, then from there install Xfce and boot to desktop. Mostly the same as the original except my user is named "test" instead. :-)


## UEFI partitioning setup:

* `fdisk /dev/vda` with gpt label (`g` in `fdisk`)
* /dev/vda1: 512 MB partition as EFI (`t` in `fdisk`, then type of `1`) => `/boot/efi`
* /dev/vda2: 4 GB partition as swap (`t` in `fdisk`, then type of `19`)
* /dev/vda3: remaining space as btrfs partition

## Grub issues with named Btrfs subvolumes

**NOTE: This section is just covering debug notes for an issue I ran into while testing. The fixes to prevent this issue are already integrated into the setup steps. So this section is just left over for historical/troubleshooting reference purposes.**

While I didn't have any issues with a very basic btrfs setup that just used the default / root subvol (e.g. `subvol=/`), I ran into issues when trying to use named btrfs subvolumes. More specifically, it seemed that after using:

    ...
    btrfs subvolume create /mnt/@fedora-root;
    btrfs subvolume create /mnt/@fedora-home;
    ...
    chroot /mnt /bin/bash
    ...
    grep subvol /etc/fstab
      UUID=43411acc-0ff0-4e73-bcee-cbe58a1f090b  /      btrfs  subvol=@fedora-root,compress=zstd:1 0 0
      UUID=43411acc-0ff0-4e73-bcee-cbe58a1f090b  /home  btrfs  subvol=@fedora-home,compress=zstd:1 0 0
    ....
    grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
      Generating grub configuration file ...
      Adding boot menu entry for UEFI Firmware Settings ...
      done    

I would have no GRUB enries for Fedora or the Fedora rescue boot option when I rebooted the system, despite having rerun `grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg` from a chroot with /, /boot, and /home mounted.

After some investigation, I came to realize that I didn't have a `/etc/default/grub` file. Since `dnf provides /etc/default/grub` indicated this should have been installed with `grub2-tools`, I tried `dnf reinstall -y grub2-tools` but that did not create the file. 
A [debian forum post](https://linux.debian.user.narkive.com/qAzdQJJ7/etc-default-grub-doesn-t-exist-what-to-do) suggested that package `grub2-common` contained `/usr/share/grub/default/grub` which was used to generate `/etc/default/grub`. However, this appears to be specific to Debian and did not apply to Fedora. I also confirmed in a UEFI-VM that F36 installed via Anaconda did *not* have this file. Nor did my baremetal F35 (BIOS) install. Querying `dnf provides /usr/share/grub/default/grub` didn't return any matches and running `dnf reinstall -y grub2-common` did *not* create either file.

Per [the official documentation](https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/kernel-module-driver-configuration/Working_with_the_GRUB_2_Boot_Loader/#sec-Adding_a_new_Entry):

> When executing the grub2-mkconfig command, GRUB 2 searches for Linux kernels and other operating systems based on the files located in the /etc/grub.d/ directory. 

So the fact that my copy of `/etc/default/grub` didn't exist could definitely be derailing the menu generation.

Instructions for [Resetting and Reinstalling GRUB2 on UEFI](https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/kernel-module-driver-configuration/Working_with_the_GRUB_2_Boot_Loader/#sec-Resetting_and_Reinstalling_GRUB_2) were to run the following as root:

    rm /etc/grub.d/*;
    rm /etc/sysconfig/grub
    dnf reinstall grub2-efi shim grub2-tools
    grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg

These commands did **not** create `/etc/default/grub` or fix the issue. I eventually resorted to manually creating `/etc/default/grub` based off a copy from a known good install done with Anaconda then rerunning `grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg`. That didn't work either.

[This answer](https://ask.fedoraproject.org/t/fedora-entry-not-in-its-own-grub-menu/16964/9) suggested running both of these:

    grub2-mkconfig -o /etc/grub2.cfg
    grub2-mkconfig -o /etc/grub2-efi.cfg

This finally gave a different output message with something about Fedora... but it also did not work.

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

    mkfs.vfat -F 32 /dev/vda1;
    mkswap /dev/vda2;
    mkfs.btrfs -L ospart --force /dev/vda3;
    mount /dev/vda3 /mnt;
    btrfs subvolume create /mnt/@fedora-root;
    btrfs subvolume create /mnt/@fedora-home;
    ls -acl /mnt;
    umount /mnt;
    mount -o noatime,compress=zstd:1,subvol=@fedora-root /dev/vda3 /mnt;
    mkdir -p /mnt/boot/efi /mnt/home;
    mount -o noatime,compress=zstd:1,subvol=@fedora-home /dev/vda3 /mnt/home;
    mount /dev/vda1 /mnt/boot/efi;
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
    printf 'UUID=%s  /boot/efi  vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro 0 0\n' "$(blkid -s UUID -o value /dev/vda1)" >> /etc/fstab;
    printf 'UUID=%s  /home  btrfs  subvol=%s,compress=zstd:1 0 0\n' "$(blkid -s UUID -o value /dev/vda3)" "$homesubvol" >> /etc/fstab;
    echo "tmpfs /tmp tmpfs rw,seclabel,nosuid,nodev,inode64 0 0" >> /etc/fstab;
    printf 'UUID=%s  swap swap defaults 0 0\n' "$(blkid -s UUID -o value /dev/vda2)" >> /etc/fstab;
    clear;echo "-------------------"; cat /etc/fstab;
    dnf install -y btrfs-progs e2fsprogs vim tree efibootmgr;
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
    restorecon -R /;
    reboot now;

status:

* no issues booting to minimal install after bootstrap
* selinux seems to be running fine
* installing xfce took forever... I know I'm on vpn but still
* no issues booting to / logging into xfce desktop after it eventually finished installing.
