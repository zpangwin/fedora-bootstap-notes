#!/bin/bash
if [[ 0 != "${UID}" ]]; then
	echo "E: This script should be run from 'root' directly because sudo";
	echo "   will eventually time out, requiring additional password prompts.";
	echo "   This can cause additional issues if the timeout occurs at a";
	echo "   critical stage.";
	exit 1;
fi

VIRTUAL_MACHINE_TYPE='unknown';
IS_VIRTUAL_MACHINE=0;
if [[ 0 != $(sudo dmidecode 2>/dev/null|grep -Pci '(manufacturer|product).*(innotek|QEMU|VirtualBox|VMWare)') ]]; then
	IS_VIRTUAL_MACHINE=1;

	if [[ 0 != $(sudo dmidecode 2>/dev/null|grep -Pci '(manufacturer|product).*(QEMU)') ]]; then
		VIRTUAL_MACHINE_TYPE='qemu';
	elif [[ 0 != $(sudo dmidecode 2>/dev/null|grep -Pci '(manufacturer|product).*(VirtualBox)') ]]; then
		VIRTUAL_MACHINE_TYPE='virtualbox';
	elif [[ 0 != $(sudo dmidecode 2>/dev/null|grep -Pci '(manufacturer|product).*(VMWare)') ]]; then
		VIRTUAL_MACHINE_TYPE='vmware';
	fi

elif [[ 0 != $(hostnamectl 2>/dev/null|grep -Pci 'Chassis:.*\b(vm)\b') ]]; then
	IS_VIRTUAL_MACHINE=1;

	if [[ 0 != $(hostnamectl 2>/dev/null|grep -Pci 'Hardware Vendor:.*\b(QEMU)\b') ]]; then
		VIRTUAL_MACHINE_TYPE='qemu';
	fi

elif [[ 0 != $(grep -Pc '^flags.*\bhypervisor\b' /proc/cpuinfo 2>/dev/null) ]]; then
	IS_VIRTUAL_MACHINE=1;

	if [[ 1 == "${hasInxi}" ]]; then
		if [[ 1 == $(inxi -M 2>/dev/null|grep -Pci '\b(Qemu)\b') ]]; then
			VIRTUAL_MACHINE_TYPE='qemu';
		fi
	fi
fi

if [[ 1 == "${IS_VIRTUAL_MACHINE}" ]]; then
	echo "Passed Safety Check: Detected VM Type as '${VIRTUAL_MACHINE_TYPE}'";
else
	echo "E: This script is designed to be run from a virtual machine.";
	echo "   Running it on a normal computer (aka 'baremetal') is not";
	echo "   only dangerous as it could destroy data, but the script is";
	echo "   should not be run without careful study and modication.";
	echo "";
	echo "   In particular, you should:";
	echo "";
	echo "  * Change the hard-coded device names (e.g. /dev/vda) to match the actual target drive.";
	echo "  * Remove the --force and -F flags from the formatting commands.";
	exit 10;
fi

SYSTEM_TYPE='unknown';
if [[ -d /sys/firmware/efi ]]; then
	SYSTEM_TYPE='uefi';
else
	SYSTEM_TYPE='bios';
fi

NEWUSER='test';
if [[ -n "${NEW_USER}" ]]; then
    NEWUSER="${NEW_USER}";
fi

NEWPASS='vm123';
if [[ -n "${NEW_PASS}" ]]; then
    NEWPASS="${NEW_PASS}";
fi

ROOTPASS="${NEWPASS}"
if [[ -n "${ROOT_PASS}" ]]; then
    ROOTPASS="${ROOT_PASS}";
fi

useradd --shell /bin/bash $NEWUSER;
usermod -aG wheel $NEWUSER;
printf '%s\n%s\n' "$NEWPASS" "$NEWPASS" | passwd $NEWUSER;
printf '%s\n%s\n' "$ROOTPASS" "$ROOTPASS" | passwd root;

# setup user aliases
printf '%s\n%s\n%s\n%s\n' "alias l='ls -acl'" "alias up='cd ..'" "alias up2='cd ../..'" "alias q='exit'" >> /home/$NEWUSER/.bashrc;
printf '%s\n%s\n%s\n' "alias pg='pgrep -ifa'" "alias pk='pkill -9 -if'" "alias e='echo'" >> /home/$NEWUSER/.bashrc;

# setup locale
dnf install -y glibc-langpack-en;
systemd-firstboot --locale=en_US.UTF-8;

# fstab prep
rootsubvol="$(mount | grep -P 'vda3.*\s+/\s+.*btrfs'|sed -E 's/^.*subvol=\/?([^,)]+).*$/\1/g')";
homesubvol="$(mount | grep -P 'vda3.*\s+/home\s+.*btrfs'|sed -E 's/^.*subvol=\/?([^,)]+).*$/\1/g')";
rm -f /etc/fstab;

# generate fstab entries
printf 'UUID=%s  /  btrfs  subvol=%s,compress=zstd:1 0 0\n' "$(blkid -s UUID -o value /dev/vda3)" "$rootsubvol" >> /etc/fstab;

if [[ 'uefi' == "${SYSTEM_TYPE}" ]]; then
	# entries under UEFI/GPT (has vfat /boot/efi)
	printf 'UUID=%s  /boot/efi  vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro 0 0\n' "$(blkid -s UUID -o value /dev/vda1)" >> /etc/fstab;
else
	# entries under BIOS/MBR (has ext4 /boot)
    printf 'UUID=%s  /boot  ext4 defaults        1 2\n' "$(blkid -s UUID -o value /dev/vda1)" >> /etc/fstab;
    
fi
printf 'UUID=%s  /home  btrfs  subvol=%s,compress=zstd:1 0 0\n' "$(blkid -s UUID -o value /dev/vda3)" "$homesubvol" >> /etc/fstab;
echo "tmpfs /tmp tmpfs rw,seclabel,nosuid,nodev,inode64 0 0" >> /etc/fstab;
printf 'UUID=%s  swap swap defaults 0 0\n' "$(blkid -s UUID -o value /dev/vda2)" >> /etc/fstab;

# install dependencies for booting ...
dnf install -y btrfs-progs e2fsprogs vim tree;
dnf install -y kernel grub2-efi-x64 grub2-efi-x64-modules shim;

if [[ 'bios' == "${SYSTEM_TYPE}" ]]; then
    dnf install -y grub2-pc-modules;
    dnf reinstall -y grub2-common;
fi	

# temporarily set selinux to permissive for first boot
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux;

# generate grub entries
if [[ 'uefi' == "${SYSTEM_TYPE}" ]]; then
	grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg;

else
    grub2-install /dev/vda;
    grub2-mkconfig -o /boot/grub2/grub.cfg;
fi

# generate dracut images to /boot
dracut --regenerate-all --force;

# make sure network service is enabled ...
systemctl enable NetworkManager;

# disable unnecessary network services that cause fedora to boot slower ...
systemctl disable NetworkManager-wait-online.service;
systemctl mask lvm2-monitor.service systemd-udev-settle.service;

# fix selinux filesystem contexts on any paths that aren't mounted to live disc paths
# (e.g. ignore /dev, /proc, /sys for now)
restorecon -R /boot /etc /home /opt /root /usr /var;

