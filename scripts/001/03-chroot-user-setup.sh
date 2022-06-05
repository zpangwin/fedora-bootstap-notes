#!/bin/bash
if [[ 0 != "${UID}" ]]; then
	echo "E: This script should be run from 'root' directly because sudo";
	echo "   will eventually time out, requiring additional password prompts.";
	echo "   This can cause additional issues if the timeout occurs at a";
	echo "   critical stage.";
	exit 1;

elif [[ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]]; then
	echo "Passed: confirmed script is running from chroot.";

else
	echo "E: This script is intended to be run from chroot.";
	exit 2;
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

if [[ -z "${NEWPASS}" ]]; then
	echo "E: 'NEWPASS' not exported. Export and try again or do it manually...";
	exit 1;
fi

NEWUSER='test';

useradd --shell /bin/bash $NEWUSER;
usermod -aG wheel $NEWUSER;
printf '%s\n%s\n' "$NEWPASS" "$NEWPASS" | passwd $NEWUSER;
printf '%s\n%s\n' "$NEWPASS" "$NEWPASS" | passwd root;

# setup user aliases
printf '%s\n%s\n%s\n%s\n' "alias l='ls -acl'" "alias up='cd ..'" "alias up2='cd ../..'" "alias q='exit'" >> /home/$NEWUSER/.bashrc;
printf '%s\n%s\n%s\n' "alias pg='pgrep -ifa'" "alias pk='pkill -9 -if'" "alias e='echo'" >> /home/$NEWUSER/.bashrc;

