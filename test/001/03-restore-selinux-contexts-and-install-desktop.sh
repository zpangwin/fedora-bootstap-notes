#!/bin/bash
if [[ 0 != "${UID}" ]]; then
	echo "E: This script should be run from 'root' directly.";
	exit 1;
fi

restorecon -R /;
dnf groupinstall -y 'Xfce Desktop';
restorecon -R /;
reboot now;
