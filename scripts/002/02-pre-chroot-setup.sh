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

# disable selinux for live disc environment
setenforce 0;

# set aliases for current live-disc session
alias l='ls -acl'; alias up='cd ..'; alias up2='cd ../..'; alias q='exit';

# prep for btrfs subvolumes
btrfsRootMountpoint="/tmp/ospart";
mkdir -p "${btrfsRootMountpoint}";
rootSubvolName="root";
homeSubvolName="home";

# create and format partitions
if [[ 'uefi' == "${SYSTEM_TYPE}" ]]; then
	# format GPT partitions
    mkfs.vfat -n "EFI" -F 32 /dev/vda1;
    mkfs.ext4 -F -L "boot" /dev/vda2;
    mkfs.btrfs -L "ospart" --force /dev/vda3;

	# setup btrfs subvolumes
    mount -o noatime,compress=zstd:1 /dev/vda3 "${btrfsRootMountpoint}";
    btrfs subvolume create "${btrfsRootMountpoint}/${rootSubvolName}";
    btrfs subvolume create "${btrfsRootMountpoint}/${homeSubvolName}";

	# mount GPT partitions
    mount -o "noatime,compress=zstd:1,subvol=${rootSubvolName}" /dev/vda3 /mnt;
    mkdir -p /mnt/home /mnt/boot/efi;
    mount /dev/vda1 /mnt/boot/efi;
    mount -o "noatime,compress=zstd:1,subvol=${homeSubvolName}" /dev/vda3 /mnt/home;
else
	# format MBR partitions
    mkfs.ext4 -F -L "boot" /dev/vda1;
    mkfs.btrfs -L "ospart" --force /dev/vda2;

	# setup btrfs subvolumes
    mount -o noatime,compress=zstd:1 /dev/vda2 "${btrfsRootMountpoint}";
    btrfs subvolume create "${btrfsRootMountpoint}/${rootSubvolName}";
    btrfs subvolume create "${btrfsRootMountpoint}/${homeSubvolName}";

	# mount MBR partitions
    mount -o "noatime,compress=zstd:1,subvol=${rootSubvolName}" /dev/vda2 /mnt;
    mkdir -p /mnt/home /mnt/boot;
    mount /dev/vda1 /mnt/boot;
    mount -o "noatime,compress=zstd:1,subvol=${homeSubvolName}" /dev/vda2 /mnt/home;
fi

if [[ 0 == "$(mount | grep -c '/mnt')" ]]; then
	echo "E: mountpoints for /mnt not found. Please check manually...";
	exit 1;
fi

# install minimal fedora setup
dnf --releasever=36 --installroot=/mnt -y groupinstall core;

# prep for chroot
for dir in sys dev proc ; do mount --rbind /$dir /mnt/$dir && mount --make-rslave /mnt/$dir ; done;
/usr/bin/cp --remove-destination /etc/resolv.conf /mnt/etc/resolv.conf;
systemd-firstboot --root=/mnt --timezone=America/New_York --hostname=fed-bootstrap --setup-machine-id;

# add aliases for chroot session
printf '%s\n%s\n%s\n%s\n' "alias l='ls -acl'" "alias up='cd ..'" "alias up2='cd ../..'" "alias q='exit'" >> /mnt/root/.bashrc;
printf '%s\n%s\n%s\n' "alias pg='pgrep -ifa'" "alias pk='pkill -9 -if'" "alias e='echo'" >> /mnt/root/.bashrc;

# start chroot
chroot /mnt /bin/bash;
