#!/bin/bash
if [[ -z "${WHICH_OPTS}" ]]; then
	WHICH_OPTS='';
	if [[ 1 == $(/usr/bin/man which 2>/dev/null | /bin/grep '\-\-skip-alias' 2>/dev/null | /usr/bin/wc -l 2>/dev/null) ]]; then
		export WHICH_OPTS='--skip-alias --skip-functions';
	fi
fi

if [[ 0 == "${UID}" ]]; then
	echo "E: This script should NOT be run from 'root' directly because it needs";
	echo "   to be applied to the live disc user account.";
	exit 1;
elif [[ 'liveuser' != "$USER" ]]; then
	echo "E: This script is intended to be run from a Fedora live disc and";
	echo "   should not be run against an installed system.";
	exit 2;
fi

# don't display first-time sudo lecture
touch ~/.sudo_as_admin_successful

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

ACTIVE_DESKTOP_NAME='unknown';
deNamesList='cinnamon gnome kde lxde lxqt mate xfce'
for deName in $(echo "${deNamesList}"); do
	if [[ "${DESKTOP_SESSION}" == "${deName}" || 1 == $(echo "$DESKTOP_SESSION"|grep -Pci "\\b${deName}\\b") ]]; then
		ACTIVE_DESKTOP_NAME="${deName}";
		break;
	fi
	if [[ "${GDMSESSION}" == "${deName}" || 1 == $(echo "$GDMSESSION"|grep -Pci "\\b${deName}\\b") ]]; then
		ACTIVE_DESKTOP_NAME="${deName}";
		break;
	fi
	if [[ 1 == $(echo "$XDG_CURRENT_DESKTOP"|grep -Pci "\\b${deName}\\b") ]]; then
		ACTIVE_DESKTOP_NAME="${deName}";
		break;
	fi
done

USER_HOME_DIR="$HOME";
CONFIG_DIR="${USER_HOME_DIR}/.config";

case "${ACTIVE_DESKTOP_NAME}" in
	cinnamon) 
		echo "  Detected desktop environment as '${ACTIVE_DESKTOP_NAME}'.";

		# Preferences > Screensaver > Delay before starting the screensaver
		echo "  Disabling screensaver idle delay timeout ...";
		gsettings set org.cinnamon.desktop.session idle-delay "uint32 0";

		# Preferences > Screensaver > Lock the computer when put to sleep
		echo "  Disabling power suspend lock ...";
		gsettings set org.cinnamon.settings-daemon.plugins.power lock-on-suspend false;

		# Preferences > Screensaver > Lock the computer when the screensaver starts
		echo "  Disabling screen-saver lock ...";
		gsettings set org.cinnamon.desktop.screensaver lock-enabled false;

		# Preferences > Screensaver > Lock the computer when the screensaver starts > Delay before locking
		echo "  Setting screen-saver lock delay to 1 hr (failsafe) ...";
		gsettings set org.cinnamon.desktop.screensaver lock-delay "uint32 3600";

		# Preferences > Power Management > Turn off the screen when inactive for: 'Never'
		echo "  Disabling screen power-off timeout ...";
		gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0;

		# Preferences > Power Management > suspend when inactive for: 'Never'
		echo "  Disabling pc sleep timeout ...";
		gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-timeout 0;

		# Preferences > Power Management > when power button is pressed
		echo "  Disabling power button confirmation prompt ...";
		gsettings set org.cinnamon.settings-daemon.plugins.power button-power 'shutdown';
    ;;


	xfce) 
		echo "  Detected desktop environment as '${ACTIVE_DESKTOP_NAME}'.";

		# Settings Manager > Power Manager > Display Tab > Display Power Management (on/off toggle) = off
		echo "  Disabling Display Power Management ...";
		xfconf-query -c 'xfce4-power-manager' -p '/xfce4-power-manager/dpms-enabled' -n -t bool -s false;

		# Settings Manager > Screensaver >  Screensaver tab > Enable Screensaver
		echo "  Disabling screensaver ...";
		xfconf-query -c 'xfce4-screensaver' -p '/saver/enabled' -n -t bool -s false;

		# Settings Manager > Screensaver > Lock Screen tab > Enable Lock Screen
		echo "  Disabling lockscreen ...";
		xfconf-query -c 'xfce4-screensaver' -p '/lock/enabled' -n -t bool -s false;


		userXfceConfigDir="${CONFIG_DIR}/xfce4";

		# disable terminal ""unsafe paste" nag screen
		echo "  Disabling terminal 'unsafe paste' nag screen ...";
		xfceTerminalConfigFile="${userXfceConfigDir}/terminal/terminalrc";
		if [[ ! -f "${xfceTerminalConfigFile}" ]]; then
			mkdir -p "$(dirname "xfceTerminalConfigFile")";
			echo "[Configuration]" > "${xfceTerminalConfigFile}";
			echo "MiscShowUnsafePasteDialog=FALSE" >> "${xfceTerminalConfigFile}";
		else
			terminalConfigHasSectionDef="$(grep -c '^\[Configuration\]' "${xfceTerminalConfigFile}" 2>/dev/null)";
			terminalConfigHasPropertyDef="$(grep -c '^MiscShowUnsafePasteDialog=' "${xfceTerminalConfigFile}" 2>/dev/null)";
			if [[ 0 == "${terminalConfigHasSectionDef}"	]]; then
				echo "[Configuration]" > "${xfceTerminalConfigFile}";
				echo "MiscShowUnsafePasteDialog=FALSE" >> "${xfceTerminalConfigFile}";

			elif [[ 0 == "${terminalConfigHasSectionDef}"	]]; then
				echo "MiscShowUnsafePasteDialog=FALSE" >> "${xfceTerminalConfigFile}";

			else
				sed -i 's/^MiscShowUnsafePasteDialog=.*$/MiscShowUnsafePasteDialog=FALSE/g' "${xfceTerminalConfigFile}";
			fi
		fi

    ;;



    *)
		echo "Desktop Environment could not be determined; skipping...";
    ;;
esac

# close annoying dnfdragora and sealert; not needed for live disc ...
pkill -9 -if dnfdragora;
pkill -9 -if sealert;

# set aliases for current live-disc session
alias l='ls -acl'; alias up='cd ..'; alias up2='cd ../..'; alias e='echo'; alias q='exit';

echo "alias l='ls -acl'; alias up='cd ..'; alias up2='cd ../..'; alias e='echo'; alias q='exit';" >> ~/.bashrc;
echo "alias l='ls -acl'; alias up='cd ..'; alias up2='cd ../..'; alias e='echo'; alias q='exit';" | sudo tee -a /root/.bashrc;


