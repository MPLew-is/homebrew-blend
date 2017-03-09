#!/bin/sh
#
#Installation and management of "blends" (meta-formulae) in homebrew
#Designed to be run as a homebrew external command
#
#Example usage:
#	brew blend install amp-stack


#Exit immediately if any of the commands in this script fail
set -e

#Check for existence of homebrew
if ! which brew 1>/dev/null 2>&1
then
	#If not present, show an error message and exit with failure
	cat 1>&2 <<-EOF
		This script requires homebrew ('brew') to be present in the current PATH
		Please install homebrew, or link it so it can be found in PATH
	
	EOF
	
	exit 1

#Check for existence of jq
elif ! which jq 1>/dev/null 2>&1
then
	#If not present, show an error message and exit with failure
	cat 1>&2 <<-EOF
		This script requires jq ('jq') to be present in the current PATH
		Please install jq, or link it so it can be found in PATH
	
	EOF
	
	exit 1
fi


blendRoot="${HOMEBREW_PREFIX}/Elevage"
blendFormulaPath="BlendFormula"
infoFileSuffix="text"
blendFileSuffix="brewfile"


updated="false"


#Get requested loudness of script
quiet="false"

if [ "${1}" = "--quiet" ]
then
	quiet="true"
	shift
fi


#Print status messages (with no trailing line break) only if output is not silenced
printStatus()
{
	if [ "${quiet}" != "true" ]
	then
		printf "%s" "${1}"
	fi
}

#Print status messages (with one trailing line break) only if output is not silenced
echoStatus()
{
	if [ "${quiet}" != "true" ]
	then
		echo "${1}"
	fi
}

#Print status messages (with two trailing line breaks) only if output is not silenced
catStatus()
{
	if [ "${quiet}" != "true" ]
	then
		cat <<-EOF
			${1}
		
		EOF
	fi
}


#Print a message showing the usage options
printUsageMessage()
{
	cat <<-EOF
		Initial setup:      brew blend (install | uninstall) --self
		Check installation: brew blend check
		List:               brew blend list
		Info:               brew blend info {NAME} [{NAME}...]
		Search:             brew blend search {NAME}
		Installation:       brew blend install {NAME} [{NAME}...]
		Uninstallation:     brew blend uninstall [--blend-only] {NAME} [{NAME}...]
		Updating:           brew blend update
		Upgrading:          brew blend upgrade [{NAME}...}
		Help:               brew blend help
		
	EOF
}


#Print a help message when requested
command_help()
{
	cat <<-EOF
		brew-blend: allows for the installation and removal of "blends" (meta-formulae) in homebrew
		
	EOF
	
	printUsageMessage
	
	cat <<-EOF
		Example usage:
		    brew blend install amp-stack
		
		Commands:
		    "help":             print this help message
		    "check":            check if brew-blend has been successfully installed
		    "install --self":   create the directories needed for brew-blend to run
		                            this will be performed automatically when you run brew-blend
		    "uninstall --self": remove the directories created by "install --self"
		    "list":             list all installed blends
		    "info":             print information about the given blend name
		    "search":           search for the given blend name
		    "install":          install the given blend name
		    "uninstall":        uninstall the given blend name
		                            if the "--blend-only" flag is given, only the blend is removed, not any of the component formulae
		    "update":           check all installed blends for updates, and print the names of those that need to be upgraded
		    "upgrade":          upgrade all outdated blends
		
		Arguments:
		    "--quiet": can be provided to any command (except help) to silence any status output
		
		
		brew-blend searches all of your taps for "blends" (meta-formulae) in a 'BlendFormula' directory
		    Your pinned taps will be searched before all others, but otherwise the order can change at any point
		These blends are fed into 'brew-bundle', and as such should follow the same the structure and syntax
		When uninstalling, all casks and normal formula in the blends will be uninstalled
		    Apps installed with 'mas' will not be changed, as uninstallation is not supported by 'mas' itself
		    When uninstalling normal formula, 'brew leaves' will be used to ensure that another installed formula does not depend on the formula being uninstalled
		        'brew-cask' does not contain this functionality, so the casks will be removed without checking dependencies (which are uncommon)
		    All other types (such as taps) will not be modified during the uninstall process
		
	EOF
	
	return 0
}


#Check if the "install --self" command has been run for this version, failing if not
command_check()
{
	if [ ! -d "${blendRoot}" ]
	then
		catStatus "brew-blend is not installed"
		return 21
		
	else
		catStatus "brew-blend is installed"
		return 0
	fi
}


command_install()
{
	if [ "${#}" = "1" ] && [ "${1}" = "--self" ]
	then
		command_install_self
		return 0
	
	else
		command_install_blend "${@}"
		return 0
	fi
}


command_install_self()
{
	if quiet="true" command_check
	then
		catStatus "brew-blend is already installed"
		return 0
	fi
	
	
	parentDirectory="$(dirname "${blendRoot}")"
	printStatus "Creating Elevage in '${parentDirectory}'... "
	
	if [ -r "${HOMEBREW_PREFIX}" ] && [ -w "${HOMEBREW_PREFIX}" ]
	then
		if mkdir -p "${blendRoot}"
		then
			chmod "g+rwx" "${blendRoot}"
			chown "$(whoami):admin" "${blendRoot}"
			
			printStatus "done"
		
		else
			printStatus "ERROR"
			return 31
		fi
	
	else
		echoStatus "permissions needed"
		echoStatus "We need elevated permissions to set up brew-blend, but we'll set permissions properly so we won't need them in the future."
		
		if sudo mkdir -p "${blendRoot}"
		then
			sudo chmod "g+rwx" "${blendRoot}"
			sudo chown "$(whoami):admin" "${blendRoot}"
			
			echoStatus "Elevage created"
		
		else
			echoStatus "ERROR creating Elevage"
			return 31
		fi
	fi
	
	
	echoStatus "brew-blend installed successfully"
	return 0
}


command_uninstall()
{
	if [ "${#}" = "1" ] && [ "${1}" = "--self" ]
	then
		command_uninstall_self
		return 0
	
	else
		command_uninstall_blend "${@}"
		return 0
	fi
}


command_uninstall_self()
{
	if ! quiet="true" command_check
	then
		catStatus "brew-blend is not installed"
		return 0
	fi
	
	
	parentDirectory="$(dirname "${blendRoot}")"
	printStatus "Removing Elevage from '${parentDirectory}'... "
	
	if [ -r "${parentDirectory}" ] && [ -w "${parentDirectory}" ]
	then
		if rm -rf "${blendRoot}"
		then
			printStatus "done"
		
		else
			printStatus "ERROR"
			return 41
		fi
	
	else
		echoStatus "permissions needed"
		echoStatus "We need elevated permissions to remove brew-blend."
		
		if sudo rm -rf "${blendRoot}"
		then
			echoStatus "Elevage removed"
		
		else
			echoStatus "ERROR removing Elevage"
			return 41
		fi
	fi
	
	
	catStatus "brew-blend uninstalled successfully"
	return 0
}


ensureInstallation()
{
	if ! quiet="true" command_check
	then
		echoStatus "Installing brew-blend..."
		command_install_self
	fi
	
	return 0
}


command_list()
{
	ensureInstallation
	
	ls "${blendRoot}"
	
	return 0
}


getTapPaths()
{
	brew tap-info --json=v1 --installed | \
	
	jq -Mr 'sort_by(.pinned) | reverse | .[].path'
	
	return 0
}


getBlendPath()
{
	blendName="${1}"
	
	getTapPaths | \
	
	{
		while read -r tapPath
		do
			blendPath="${tapPath}/${blendFormulaPath}/${blendName}"
			if [ -f "${blendPath}.${blendFileSuffix}" ]
			then
				echo "${blendPath}"
				return 0
			fi
		done
		
		return 3
	}
}

forEachBlend()
{
	forEachCommand="${1}"
	shift
	
	while [ "${#}" -gt "0" ]
	do
		blendName="${1}"
		
		if ! blendPath="$(getBlendPath "${blendName}")"
		then
			catStatus "Blend '${blendName}' not found" 1>&2
			return 4
		fi
		
		"${forEachCommand}" "${blendName}" "${blendPath}"
		
		shift
	done
	
	return 0
}

forEachLocalBlend()
{
	forEachCommand="${1}"
	shift
	
	while [ "${#}" -gt "0" ]
	do
		blendName="${1}"
		
		if [ ! -d "${blendRoot}/${blendName}" ]
		then
			catStatus "Blend '${blendName}' not found" 1>&2
			return 4
		fi
		
		if ! blendPath="$(getBlendPath "${blendName}")"
		then
			blendPath=""
		fi
		
		"${forEachCommand}" "${blendName}" "${blendPath}"
		
		shift
	done
	
	return 0
}


command_info()
{
	ensureInstallation
	
	forEachBlend "displayBlendInfo" "${@}"
	
	return 0
}

displayBlendInfo()
{
	blendTapPath="${2}"
	cat "${blendTapPath}.${infoFileSuffix}"
	
	return 0
}


command_search()
{
	ensureInstallation
	
	if [ "${#}" = "0" ]
	then
		catStatus "No blend names were provided" 1>&2
		return 71
	
	elif [ "${#}" -gt "1" ]
	then
		catStatus "Please provide only one blend name" 1>&2
		return 72
	fi
	
	blendName="${1}"
	
	getTapPaths | \
	
	xargs -n 1 -I_path -- find "_path/${blendFormulaPath}" -name "*${blendName}*.${blendFileSuffix}" 2>/dev/null | \
	
	sed -e "s:^${HOMEBREW_PREFIX}/Homebrew/Library/Taps/::g" | \
	
	sed -e "s:${blendFormulaPath}/::g" | \
	
	sed -e "s:.${blendFileSuffix}\$::g"
	
	return 0
}


command_install_blend()
{
	ensureInstallation
	
	forEachBlend "installBlend" "${@}"
	
	return 0
}

installBlend()
{
	blendName="${1}"
	blendDirectory="${blendRoot}/${blendName}"
	tapBlendPath="${2}"
	
	if [ -d "${blendDirectory}" ]
	then
		catStatus "Blend '${blendName}' is already installed" 1>&2
		return 81
	fi
	
	printStatus "Making a copy of blend '${blendName}' in Elevage... "
	if mkdir -p "${blendDirectory}" && cp "${tapBlendPath}.${blendFileSuffix}" "${blendDirectory}/${blendName}.${blendFileSuffix}"
	then
		echoStatus "done"
		
	else
		echoStatus "ERROR"
		return 82
	fi
	
	echoStatus "Using brew-bundle to install blend '${blendName}'..."
	if brew bundle --file="${blendDirectory}/${blendName}.${blendFileSuffix}"
	then
		echoStatus "Blend '${blendName}' successfully installed"
	
	else
		echoStatus "ERROR installing blend '${blendName}'"
		return 83
	fi
	
	return 0
}


command_uninstall_blend()
{
	ensureInstallation
	
	if [ "${1}" = "--blend-only" ]
	then
		shift
		forEachLocalBlend "uninstallBlendFile" "${@}"
	
	else
		forEachLocalBlend "uninstallBlend" "${@}"
	fi
	
	return 0
}

uninstallBlend()
{
	blendName="${1}"
	blendDirectory="${blendRoot}/${blendName}"
	if [ ! -d "${blendDirectory}" ]
	then
		catStatus "Blend '${blendName}' is not installed" 1>&2
		return 81
	fi
	
	
	storedLeaves="$(brew leaves)"
	uninstallFormulae "${blendName}"
	
	leaves="$(brew leaves)"
	while [ "${leaves}" != "${storedLeaves}" ]
	do
		uninstallFormulae "${blendName}"
		storedLeaves="${leaves}"
		leaves="$(brew leaves)"
	done
	
	
	grep "^cask" "${blendDirectory}/${blendName}.${blendFileSuffix}" | \
	
	awk '{print $1" "$2}' | \
	
	sed -e 's/,$//g' | \
	
	{
		while read -r cask
		do
			if grep --quiet --recursive --exclude-dir="${blendDirectory}" "${cask}" "${blendRoot}"
			then
				continue
			fi
			
			caskName="$(echo "${cask}" | awk '{print $2}' | sed -e "s/^'//g" -e "s/'$//g")"
			brew cask uninstall "${caskName}"
		done
	}
	
	
	grep "^tap" "${blendDirectory}/${blendName}.${blendFileSuffix}" | \
	
	awk '{print $1" "$2}' | \
	
	sed -e 's/,$//g' | \
	
	{
		while read -r tap
		do
			if grep --quiet --recursive --exclude-dir="${blendDirectory}" "${tap}" "${blendRoot}"
			then
				continue
			fi
			
			tapName="$(echo "${tap}" | awk '{print $2}' | sed -e "s/^'//g" -e "s/'$//g")"
			if ! ( brew list --full-name | grep --quiet "${tapName}" )
			then
				brew untap "${tapName}"
			fi
		done
	}
	
	
	uninstallBlendFile "${blendName}"
	return 0
}

uninstallFormulae()
{
	blendName="${1}"
	blendDirectory="${blendRoot}/${blendName}"
	
	grep "^brew" "${blendDirectory}/${blendName}.${blendFileSuffix}" | \
	
	awk '{print $1" "$2}' | \
	
	sed -e 's/,$//g' | \
	
	{
		while read -r formula
		do
			if grep --quiet --recursive --exclude-dir="${blendDirectory}" "${formula}" "${blendRoot}"
			then
				continue
			fi
			
			
			formulaName="$(echo "${formula}" | awk '{print $2}' | sed -e "s/^'//g" -e "s/'$//g")"
			if ( brew leaves | grep --quiet "^${formulaName}\$" )
			then
				brew uninstall "${formulaName}" || true
			fi
		done
	}
}

uninstallBlendFile()
{
	blendName="${1}"
	blendDirectory="${blendRoot}/${blendName}"
	
	printStatus "Removing blend file for '${blendName}' from Elevage... "
	if rm -rf "${blendDirectory}"
	then
		echoStatus "done"
	
	else
		echoStatus "ERROR"
		return 82
	fi
	
	return 0
}


command_update()
{
	ensureInstallation
	
	installed="$(command_list)"
	if [ "${installed}" = "" ]
	then
		catStatus "No blends installed"
		return 0
	fi
	
	forEachLocalBlend "checkDifferent" "${installed}"
	
	if [ "${updated}" = "false" ]
	then
		catStatus "All blends up-to-date"
	fi
	
	return 0
}

checkDifferent()
{
	blendName="${1}"
	
	elevageDirectory="${blendRoot}/${1}"
	elevageFile="${elevageDirectory}/${blendName}.${blendFileSuffix}"
	
	tapPath="${2}"
	tapFile="${tapPath}.${blendFileSuffix}"
	
	if [ "${tapPath}" = "" ]
	then
		echo "Blend '${blendName}' has been removed in the upstream tap" 1>&2
		echo "This blend will no longer update, but you won't be affected otherwise" 1>&2
		echo "You can safely remove this blend with 'brew blend uninstall --blend-only ${blendName}' without affecting any existing formulae" 1>&2
		return 0
	fi
	
	elevageHash="$( shasum --portable --algorithm 512256 "${elevageFile}" | awk '{print $1}')"
	tapHash="$(shasum --portable --algorithm 512256 "${tapFile}" | awk '{print $1}')"
	
	if [ "${elevageHash}" != "${tapHash}" ]
	then
		updated="true"
		echo "${blendName}"
	fi
	
	return 0
}


command_upgrade()
{
	ensureInstallation
	
	installed="$(command_list)"
	if [ "${installed}" = "" ]
	then
		catStatus "No blends installed"
		return 0
	fi
	
	
	if [ "${#}" = "0" ]
	then
		forEachLocalBlend "upgradeBlend" "${installed}"
	
	else
		forEachLocalBlend "upgradeBlend" "${@}"
	fi
	
	return 0
}

upgradeBlend()
{
	blendName="${1}"
	tapBlendPath="${2}"
	if [ "$(checkDifferent "${blendName}" "${tapBlendPath}")" = "" ]
	then
		return 0
	fi
	
	
	blendDirectory="${blendRoot}/${blendName}"
	elevageFile="${blendDirectory}/${blendName}.${blendFileSuffix}"
	
	printStatus "Replacing copy of blend '${blendName}' in Elevage... "
	if rm "${elevageFile}" && cp "${tapBlendPath}.${blendFileSuffix}" "${elevageFile}"
	then
		echoStatus "done"
		
	else
		echoStatus "ERROR"
		return 101
	fi
	
	echoStatus "Using brew-bundle to upgrade blend '${blendName}'..."
	if brew bundle --file="${elevageFile}"
	then
		echoStatus "Blend '${blendName}' successfully upgraded"
	
	else
		echoStatus "ERROR upgrading blend '${blendName}'"
		return 102
	fi
	
	return 0
}


#Parse requested command, and call the corresponding function with the remaining arguments
if [ "${1}" = "help" ] || [ "${1}" = "check" ] || [ "${1}" = "install" ] || [ "${1}" = "uninstall" ] || [ "${1}" = "list" ] || [ "${1}" = "info" ] || [ "${1}" = "search" ] || [ "${1}" = "update" ] || [ "${1}" = "upgrade" ]
then
	commandFunction="command_${1}"
	
	shift
	"${commandFunction}" "${@}"

#Otherwise, fail with error
else
	echo "Unrecognized command '${1}'" 1>&2
	printUsageMessage 1>&2
	exit 2
fi


exit 0
