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

# delete any existing partitions on VM disk (doesn't always clear it perfectly but mostly works ok - display for user to verify at end)
printf '%s\n%s\n%s\n%s\n%s\n%s\n' 'd' '3' 'd' '2' 'd' 'w' | fdisk /dev/vda;
wipefs --all /dev/vda;

# create and format partitions
if [[ 'uefi' == "${SYSTEM_TYPE}" ]]; then
	# setup as GPT
    printf '%s\n%s\n' 'g' 'w' | fdisk /dev/vda && clear;

    # create partition 1 as ESP (EFI System Partition) for vfat /boot/efi
    printf '%s\n%s\n\n%s\n%s\n%s\n' 'n' '1' '+600M' 'Y' 'w' | fdisk /dev/vda && clear;
    printf '%s\n%s\n%s\n' 't' '1' 'w' | fdisk /dev/vda && clear;

    # create partition 2 as 1GB for ext4 /boot
    printf '%s\n%s\n\n%s\n%s\n%s\n' 'n' '2' '+1G' 'Y' 'w' | fdisk /dev/vda && clear;

    # create partition 3 (all remaining space) as btrfs /
    printf '%s\n%s\n\n\n%s\n%s\n' 'n' '3' 'Y' 'w' | fdisk /dev/vda && clear;
else
	# setup as MBR
    printf '%s\n%s\n' 'o' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;

    # create partition 1 as 1GB for ext4 /boot
    printf '%s\n%s\n%s\n\n%s\n%s\n%s\n' 'n' 'p' '1' '+1G' 'Y' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;

    # set MBR "boot" / "active" flag for partition 1
    printf '%s\n%s\n%s\n' 'a' '1' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;

    # create partition 2 (all remaining space) as btrfs /
    printf '%s\n%s\n%s\n\n\n%s\n%s\n' 'n' 'p' '3' 'Y' 'w' | fdisk /dev/vda; clear; fdisk -l /dev/vda;
fi

# print so it can be manually confirmed ... sometimes fdisk doesn't always clean old partitions correctly...
clear;
fdisk -l /dev/vda;
