# Description

This is basically my just tweaking the install I had done in [reckzero-uefi-ext4-bootstrap-setup.md](./reckzero-uefi-ext4-bootstrap-setup.md) . In this iteration, I was focusing mostly on writing scriptlets/one-liners/etc to reduce time spent typing responses into prompts and semi-automate the bootstrap process. After I get things working the way I want, I might finalize these into scripts and add links but for now, they're copy/paste.

One of my goals is also to eventually tweak the instructions from the install to get as close as possible to a minimal install done normally with Anaconda from the ["Everything" netinstall iso](https://alt.fedoraproject.org/).


## Changes from ReckZero version

1. My EFI partition will be sized as 600 MiB to mimick "Anaconda with Automatic partitioning".
2. Removed swap partition; I consider these option since Anaconda with Automatic partitioning doesn't create them.
3. I will be using the btrfs filesystem instead of ext4 for the root partition. However, I will not be using any named subvolumes in this iteration (or technically speaking, I am using an unnamed subvolume, e.g. `subvol=/`).
4. Since I plan on eventually duplicating "Anaconda with Automatic partitioning", I will be creating a `/boot` partition as a placeholder. This partition is *NOT* strictly required, nor actually even used by this particular iteration.
5. Since I have more installs to do, I won't be installing a desktop in all of the tests. I will only be confirming that I can boot into a minimal install and login with both root and a "test" account.
6. Video sets up a tmpfs fstab entry for /tmp. This is not necessary; Fedora will do this by default if not /tmp entry is defined. Only needed if you want to set a maximum amount of memory that /tmp can use or other custom settings.
7. I will be attempting to reduce prompts as much as possible so you will see me piping responses to various commands like `fdisk` and `passwd` as well as using flags like `dnf install -y` or `rm -rf` to avoid prompts.
8. I disable some services that don't really do much for me (NetworkManager-wait-online.service is generally used for company offices where you have multiple users and a profile is loaded over the network - not needed for home users; lvm2-monitor and [systemd-udev-settle](https://askubuntu.com/questions/888010/slow-booting-systemd-udev-settle-service) aren't really needed unless you're using LVM... and if you don't know what LVM is, you're almost guaranteed that you're not using it).


**All commands below assume that this is running in a VM. You should pratice in a VM first, make your *own* carefully reviewed notes, and understand all commands before running these commands against a real, baremetal system. Backups are YOUR responsibility. These notes are for *my* reference only so don't blame me if you mess up your system because you ran something you didn't understand. My notes are provided AS-IS with no warranty whatsoever, either express or implied.**

You have been warned. ;-)

## Variations

This was tested with both UEFI (OVMF_CODE) and UEFI with Secure Boot (OVMF_CODE.secboot) in virt-manager. No differences were noticed between the two.

## UEFI/GPT partitioning setup:

* `fdisk /dev/vda` with gpt label (`g` in `fdisk`)
* /dev/vda1: 600 MB partition as EFI (`t` in `fdisk`, then type of `1`) => `/boot/efi`
* /dev/vda2: 1 GB ext4 /boot partition (reserved for future iterations / not used yet)
* /dev/vda3: remaining space as btrfs partition

## Commands

Partitioning:

    su -
    setenforce 0;
    test -d /sys/firmware/efi && echo 'uefi' || echo 'bios';
    getenforce
    alias l='ls -acl'; alias up='cd ..'; alias up2='cd ../..'; alias q='exit';
    for i in {3..1}; do parted /dev/vda rm $i --script 2>/dev/null; done; wipefs --all /dev/vda;
    parted /dev/vda mklabel gpt --script;
    parted /dev/vda mkpart fat32 1M 601MiB --script;
    parted /dev/vda mkpart ext4 601MiB 1625MiB --script;
    parted /dev/vda mkpart btrfs 1625MiB 100% --script;
    parted /dev/vda set 1 boot on --script;
    clear; fdisk -l /dev/vda;


Pre-chroot:

    su -
    setenforce 0;
    test -d /sys/firmware/efi && echo 'uefi' || echo 'bios';
    getenforce
    alias l='ls -acl'; alias up='cd ..'; alias up2='cd ../..'; alias q='exit';
    mkfs.vfat -n "EFI" -F 32 /dev/vda1;
    mkfs.ext4 -F -L "boot" /dev/vda2;
    mkfs.btrfs -L "ospart" --force /dev/vda3;
    mount -o compress=zstd:1 /dev/vda3 /mnt;
    mkdir -p /mnt/boot/efi;
    mount /dev/vda1 /mnt/boot/efi;
    dnf --releasever=36 --installroot=/mnt -y groupinstall core;
    for dir in sys dev proc ; do mount --rbind /$dir /mnt/$dir && mount --make-rslave /mnt/$dir ; done;
    /usr/bin/cp --remove-destination /etc/resolv.conf /mnt/etc/resolv.conf;
    systemd-firstboot --root=/mnt --timezone=America/New_York --hostname=uefi-bootstrap-01 --setup-machine-id;
    printf '%s\n%s\n%s\n%s\n' "alias l='ls -acl'" "alias up='cd ..'" "alias up2='cd ../..'" "alias q='exit'" >> /mnt/root/.bashrc;
    printf '%s\n%s\n%s\n' "alias pg='pgrep -ifa'" "alias pk='pkill -9 -if'" "alias e='echo'" >> /mnt/root/.bashrc;
    chroot /mnt /bin/bash;

Inside Chroot (user setup):

    NEWPASS='password';
    NEWUSER='test';useradd --shell /bin/bash $NEWUSER; usermod -aG wheel $NEWUSER;
    printf '%s\n%s\n' "$NEWPASS" "$NEWPASS" | passwd $NEWUSER;
    printf '%s\n%s\n' "$NEWPASS" "$NEWPASS" | passwd root;
    printf '%s\n%s\n%s\n%s\n' "alias l='ls -acl'" "alias up='cd ..'" "alias up2='cd ../..'" "alias q='exit'" >> /home/$NEWUSER/.bashrc;
    printf '%s\n%s\n%s\n' "alias pg='pgrep -ifa'" "alias pk='pkill -9 -if'" "alias e='echo'" >> /home/$NEWUSER/.bashrc;
    // since we're going from root to "test", we won't get prompted for password
    su - test
    // but going from "test" to "test", it should prompt. confirm it works
    su - test
	// now go from "test" to "root", it should prompt for root password. confirm that works too.
    su - root
    // exit inner root session
    exit
    //return to chroot as root (exit test user session)
    exit

Back to Chroot (continue system setup):

    dnf install -y glibc-langpack-en; systemd-firstboot --locale=en_US.UTF-8;
    rm -f /etc/fstab;
    printf 'UUID=%s  /  btrfs  compress=zstd:1 0 0\n' "$(blkid -s UUID -o value /dev/vda3)" >> /etc/fstab;
    printf 'UUID=%s  /boot/efi  vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro 0 0\n' "$(blkid -s UUID -o value /dev/vda1)" >> /etc/fstab;
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

    UUID=<UUID of 3nd partition - aka ospart>  /  btrfs   compress=zstd:1 0 0
    UUID=<UUID of 1st partition - aka EFI>     /boot/efi  vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro 0 0

can now reboot. after reboot, login as root:

    getenforce
    // showed as Enforcing
    // weird that /etc/sysconfig/selinux was ignored but I was going to turn it back on anyway
    restorecon -R /;
    reboot now;

status:

* no issues booting to minimal install after bootstrap
* selinux seems to be running fine


