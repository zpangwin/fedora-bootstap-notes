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

# disable selinux for live disc environment
setenforce 0;

# set aliases for current live-disc session
alias l='ls -acl'; alias up='cd ..'; alias up2='cd ../..'; alias q='exit';

mkdir /tmp/ospart
mount /dev/vda3 /tmp/ospart;

mount -o noatime,compress=zstd:1,subvol=@fedora-root /dev/vda3 /mnt;
mount -o noatime,compress=zstd:1,subvol=@fedora-home /dev/vda3 /mnt/home;

# create and format partitions
if [[ -d /sys/firmware/efi ]]; then
	#mount /dev/vda2 /mnt/boot;
    mount /dev/vda1 /mnt/boot/efi;
else
    mount /dev/vda1 /mnt/boot;
fi

# prep for chroot
for dir in sys dev proc ; do mount --rbind /$dir /mnt/$dir && mount --make-rslave /mnt/$dir ; done;
/usr/bin/cp --remove-destination /etc/resolv.conf /mnt/etc/resolv.conf;

# start chroot
chroot /mnt /bin/bash;
