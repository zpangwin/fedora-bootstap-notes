# Description

Some random notes / commands I collected while following this guide: [Youtube: Fedora 36 Bootstrap Installation by Animortis Productions](https://www.youtube.com/watch?v=hjR37L2xC6g). [Here](https://www.reddit.com/r/Fedora/comments/uub5b8/fedora_linux_commandline_bootstrap_installation/) is a link to the same thing on reddit, in case any useful comments get added over there.


## general

Instructions seemed to work for UEFI setup. There are some differences needed for Legacy BIOS setups that are not covered in the video. I may add them if I get some time to test them out in a VM but currently these notes are UEFI only.

On the security-side of things, the video creator doesn't go into much explaination on the SELinux front other than that you need to disable it for the install. For some viewers, it might not even be obvious from the video but I would like to clarify that you *only* need to disable it for the install. You can (and should) re-enable it afterwards unless you have a very good understanding of Linux security modules (LSMs) and fully understand the risks of running without one enabled.

To give some background for those coming from Debian-/Ubuntu-based distros, who might not know much about SELinux: being on Fedora with it (permanently) disabled is *NOT* the same as being on a Debian-/Ubuntu-based distro that is not using it. In the former (Fedora) scenario, you would be running with no LSM whatsoever. While in the latter (Debian) scenario, you generally have AppArmor (aka "AA"). Unfortunately, setting up AA in Fedora is not supported (e.g. it's not in the repos and you're unlikely to get help from redhatters). AFAIK getting AA to work in Fedora, is not something easy to do as, at minimum, it would require writing and maintaining your own AppArmor policies. SELinux policies OTOH are maintained by RedHat and are generally pretty good for normal basic usage (no issues with Steam/LibreOffice/browsers/etc). You might run into issues when doing more advanced things like running a server. And I will admit that there *are* situations where it can be annoying and turning it off is easier than getting past the learning curve; I'm just saying that permanently disabling it should not be the default cource of action and that should only be done if there is a roadblock where something is not working. Temporarily disabling it for debugging/installs is usually fine.


### video instructions

Video disables SELinux on the livedisc as the very first step: `setenforce 0` then opens a root terminal and does partitioning. You should do this first but I'll repeat it below just in case someone (such as myself) skips right into the terminal commands.

I'm also gonna skip the `fdisk` steps for brevity but basically he created the following UEFI/GPT setup:

* `fdisk /dev/vda` with gpt label (`g` in `fdisk`)
* /dev/vda1: 512 MB partition as EFI (`t` in `fdisk`, then type of `1`) => `/boot/efi`
* /dev/vda2: 12 GB partition as swap (`t` in `fdisk`, then type of `19`)
* /dev/vda3: remaining space as ext4 partition

If you were installing via Anaconda with Automatic partitioning, you'd get get a 600 MB /boot/efi partition (vfat), a 1GB /boot partition (ext4), and the remaining space as a btrfs root partition. If you skip the `tmpfs` fstab definition that's described in the video, Fedora still creates one by default. Neither a tmpfs or swap entry (for a partition or a swapfile) is added by Anaconda with Automatic partitioning. I'm not saying Anaconda's is "better" / "more standard"; just noting the differences. After readin the Arch wiki, it actually seems kind of weird that Anaconda does this particular setup. Even LUKS setups generally seem to only have either /boot or /boot/efi as a separate partition, rather than both. I'm assuming RedHat has its reasons and it is probably easier to use a consistent partitioning/format setup than have multiple cases to handle.

Anyway, here are the commands I saw used in the video:

Pre-chroot

    setenforce 0
    mkfs.vfat /dev/vda1
    mkswap /dev/vda2
    mkfs.ext4 /dev/vda3
    mount /dev/vda3 /mnt
    mkdir -p /mnt/boot/efi
    mount /dev/vda1 /mnt/boot/efi
    dnf --releasever=36 --installroot=/mnt groupinstall core
    for dir in sys dev proc ; do mount --rbind /$dir /mnt/$dir && mount --make-rslave /mnt/$dir ; done;
    rm /mnt/etc/resolv.conf
    cp /etc/resolv.conf /mnt/etc/
    systemd-firstboot --root=/mnt --timezone=America/New_York --hostname=fed-strap --setup-machine-id
    chroot /mnt /bin/bash

Inside Chroot

    dnf install glibc-langpack-en
    systemd-firstboot --locale=en_US.UTF-8
    passwd
    cp /proc/mounts /etc/fstab
    chmod 744 /etc/fstab
    blkid

    vi /etc/fstab

Fstab contents

    UUID=(uuid of vda3 aka os part)  /          ext4  rw,seclabel,relatime 0 0
    UUID=(uuid of vda1 aka efi part) /boot/eti  vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro 0 0
    tmpfs /tmp tmpfs rw,seclabel,nosuid,nodev,inode64 0 0
    UUID=(uuid of vda2 aka swap part) swap swap defaults 0 0

Finalize Chroot:

    dnf install kernel vim
    dnf install grub2-efi-x64 grub2-efi-x64-modules shim
    grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
    dracut --regenerate-all --force
    vim /etc/sysconfig/selinux
      // change to permissive
    systemctl enable NetworkManager

can now reboot

after reboot:

login as root

    useradd -mG wheel aaron
    passwd aaron
    exit
    // logged in under user account
    sudo dnf groupinstall 'Xfce Desktop'
    sudo reboot
