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


#If homebrew prefix variable is not set but brew is in the PATH (checked above), fetch the needed value from brew itself
#This should only ever happen during development, running the script directly without installing it
if [ "${HOMEBREW_PREFIX}" = "" ]
then
	HOMEBREW_PREFIX="$(brew --prefix)"
fi


#Define some variables to allow for easy changing later
blendRoot="${HOMEBREW_PREFIX}/Elevage"
blendFormulaPath="BlendFormula"
infoFileSuffix="text"
blendFileSuffix="brewfile"


#Initialize variable indicating whether any blends were updated
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
		Initial setup:      brew blend (install-self | uninstall-self)
		Check installation: brew blend check
		List:               brew blend list
		Info:               brew blend info {NAME} [{NAME}...]
		Search:             brew blend search [{NAME}]
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
		    "install-self":     create the directories needed for brew-blend to run
		                            this will be performed automatically when you run brew-blend
		    "uninstall-self":   remove the directories created by "install-self"
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


#Check if the "install-self" command has been run for this version, failing if not
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


#Create blend storage directory and set its permissions
command_install_self()
{
	#Prevent command from executing if any arguments are provided
	if [ "${#}" != "0" ]
	then
		echo "Command install-self does not take any arguments" 1>&2
		return 32
	fi
	
	
	#Check if already installed, and return if so, as another installation is unnecessary
	if quiet="true" command_check
	then
		catStatus "brew-blend is already installed"
		return 0
	fi
	
	
	#Set variable for Elevage's parent directory
	parentDirectory="$(dirname "${blendRoot}")"
	
	
	printStatus "Creating Elevage in '${parentDirectory}'... "
	
	#If the parent directory is readable and writable by the current user, create directory and ensure correct permissions automatically
	if [ -r "${parentDirectory}" ] && [ -w "${parentDirectory}" ]
	then
		if mkdir -p "${blendRoot}"
		then
			#These permissions were taken from homebrew-cask, which has a similar setup
			chmod "g+rwx" "${blendRoot}"
			chown "$(whoami):admin" "${blendRoot}"
			
			printStatus "done"
		
		else
			printStatus "ERROR"
			return 31
		fi
	
	#Otherwise, prompt for sudo to create and set permissions on the directory
	else
		echoStatus "permissions needed"
		echoStatus "We need elevated permissions to set up brew-blend, but we'll set permissions properly so we won't need them in the future"
		
		if sudo mkdir -p "${blendRoot}"
		then
			#These permissions were taken from homebrew-cask, which has a similar setup
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


#Remove blend storage directory created by command_install_self
command_uninstall_self()
{
	#Prevent command from executing if any arguments are provided
	if [ "${#}" != "0" ]
	then
		echo "Command uninstall-self does not take any arguments" 1>&2
		return 32
	fi
	
	
	#If brew-blend is not installed, don't run the uninstallation
	if ! quiet="true" command_check
	then
		catStatus "brew-blend is not installed"
		return 0
	fi
	
	
	#Set variable for Elevage's parent directory
	parentDirectory="$(dirname "${blendRoot}")"
	
	printStatus "Removing Elevage from '${parentDirectory}'... "
	
	#If the parent directory is readable and writable by the current user, remove Elevage directory automatically
	if [ -r "${parentDirectory}" ] && [ -w "${parentDirectory}" ]
	then
		if rm -rf "${blendRoot}"
		then
			printStatus "done"
		
		else
			printStatus "ERROR"
			return 41
		fi
	
	#Otherwise, prompt for sudo to remove the directory
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


#Install brew-blend if called and not installed
ensureInstallation()
{
	if ! quiet="true" command_check
	then
		echoStatus "Installing brew-blend..."
		command_install_self
	fi
	
	return 0
}


#List all folders in the Elevage directory, which is the list of all installed blends
command_list()
{
	ensureInstallation
	
	ls "${blendRoot}"
	
	return 0
}


#Get the paths to all homebrew taps from the homebrew JSON API, with pinned taps listed first so those blends appear first
getTapPaths()
{
	brew tap-info --json=v1 --installed | \
	
	jq -Mr 'sort_by(.pinned) | reverse | .[].path'
	
	return 0
}


#Search all taps for the input blend name, and return that blend's full path if found
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

#Execute an input function for each blend name listed as an argument
forEachBlend()
{
	#Store the input command so it can be shifted off
	forEachCommand="${1}"
	shift
	
	#Iterate through the input blends, and fail if no tap path is returned
	while [ "${#}" -gt "0" ]
	do
		#If the input blend name contains a slash, treat it as a fully-qualified tap+blend name
		blendName="${1}"
		if [ "${blendName##*/}" != "${blendName}" ]
		then
			#Strip everything after the last slash to get the tap name
			tapName="${blendName%/*}"
			
			#If the tap name does not contain a slash, it's not a valid tap, so print a message and return with error
			if [ "${tapName##*/}" = "${tapName}" ]
			then
				echo "The given tap '${tapName}' is not valid; it should be in user/repository format" 1>&2
				return 85
			fi
			
			#Otherwise, tap the tap, and set the blend name to the shortened value
			brew tap "${tapName}"
			blendName="${blendName##*/}"
		fi
		
		if ! blendPath="$(getBlendPath "${blendName}")"
		then
			catStatus "Blend '${blendName}' not found" 1>&2
			return 4
		fi
		
		#If found, call the input function with the blend name and full blend path
		"${forEachCommand}" "${blendName}" "${blendPath}"
		
		shift
	done
	
	return 0
}

#Execute an input function for each blend name listed as an argument
#Differs from `forEachBlend` in that it does not fail if the blend no longer exists in its tap
forEachLocalBlend()
{
	#Store the input command so it can be shifted off
	forEachCommand="${1}"
	shift
	
	#Iterate through the input blends, and fail if no installed blend is found
	while [ "${#}" -gt "0" ]
	do
		blendName="${1}"
		
		if [ ! -d "${blendRoot}/${blendName}" ]
		then
			catStatus "Blend '${blendName}' not found" 1>&2
			return 5
		fi
		
		#If the blend is not found in any tap, simply set the tap path to an empty string
		if ! blendPath="$(getBlendPath "${blendName}")"
		then
			blendPath=""
		fi
		
		#If found, call the input function with the blend name and full blend path
		"${forEachCommand}" "${blendName}" "${blendPath}"
		
		shift
	done
	
	return 0
}


#Call `displayBlendInfo` for each input blend
command_info()
{
	ensureInstallation
	
	forEachBlend "displayBlendInfo" "${@}"
	
	return 0
}

#`cat` the info file associated with the input blend
displayBlendInfo()
{
	blendTapPath="${2}"
	cat "${blendTapPath}.${infoFileSuffix}"
	
	return 0
}


#Search all taps for the input blend name with wildcards on either side
command_search()
{
	ensureInstallation
	
	#Ensure no more than blend name is provided
	#With just using `forEachBlend`, search would be **extremely** inefficient, and the output would likely be confusing, so it's being limited to 1 blend at a time
	if [ "${#}" -gt "1" ]
	then
		catStatus "Please provide only one blend name" 1>&2
		return 72
	fi
	
	
	#If no blend name is provided, leave the blend name empty for a wildcard search
	if [ "${#}" = "0" ]
	then
		blendName=""
	
	#Otherwise, set it to the provided argument
	else
		blendName="${1}"
	fi
	
	
	#Get paths to all taps
	getTapPaths | \
	
	#Find all blend files in installed taps
	xargs -n 1 -I_path -- find "_path/${blendFormulaPath}" -name "*${blendName}*.${blendFileSuffix}" 2>/dev/null | \
	
	#Strip the initial path prefix, the Elevage directory prefix, and the file suffix from the file path to get the fully-qualified blend name
	sed \
		-e "s:^${HOMEBREW_PREFIX}/Homebrew/Library/Taps/::g" \
		-e "s:${blendFormulaPath}/::g" \
		-e "s:.${blendFileSuffix}\$::g" \
		-e 's:/homebrew-\([^/]*\)/:/\1/:g'
	
	return 0
}


#Call installBlend for each input blend name
command_install()
{
	ensureInstallation
	
	forEachBlend "installBlend" "${@}"
	
	return 0
}

#Use `brew bundle` to install each input argument after validating it exists
installBlend()
{
	#Set initial variables for easy use later in the function
	blendName="${1}"
	blendDirectory="${blendRoot}/${blendName}"
	blendTapPath="${2}"
	
	#Check if formulae is already installed; don't install if so
	if [ -d "${blendDirectory}" ]
	then
		catStatus "Blend '${blendName}' is already installed" 1>&2
		return 81
	fi
	
	
	#Create the directory for the blend
	printStatus "Creating directory for blend '${blendName}' in Elevage... "
	if mkdir "${blendDirectory}"
	then
		#If the creation succeeds, copy the blend file into it
		echoStatus "done"
		printStatus "Making a copy of blend '${blendName}' in Elevage... "
		
		if cp "${blendTapPath}.${blendFileSuffix}" "${blendDirectory}/${blendName}.${blendFileSuffix}"
		then
			echoStatus "done"
		
		#If the copying fails, clean up the created blend directory
		else
			echoStatus "ERROR"
			
			removeBlendDirectory "${blendName}"
			
			return 82
		fi
	
	#Fail with error if the directory fails to be created
	else
		echoStatus "ERROR"
		return 83
	fi
	
	#Install the blend file
	echoStatus "Using brew-bundle to install blend '${blendName}'..."
	if brew bundle --file="${blendDirectory}/${blendName}.${blendFileSuffix}"
	then
		echoStatus "Blend '${blendName}' successfully installed"
	
	#If installation fails, clean up the created blend directory
	else
		echoStatus "ERROR installing blend '${blendName}'"
		
		removeBlendDirectory "${blendName}"
		
		return 84
	fi
	
	return 0
}


#Remove the blend directory created for the input blend
removeBlendDirectory()
{
	blendName="${1}"
	blendDirectory="${blendRoot}/${blendName}"
	
	#Don't attempt to remove the blend directory if not present
	if [ ! -d "${blendDirectory}" ]
	then
		echoStatus "Unknown blend '${blendName}'" 1>&2
		return 7
	fi
	
	#Attempt to remove the blend directory
	printStatus "Removing directory for blend '${blendName}' in Elevage... "
	if rm -rf "${blendDirectory}"
	then
		echoStatus "done"
	
	#This should basically never happen unless the user messes with permission settings, but it's put here just in case
	else
		echoStatus "ERROR"
		echoStatus "Well, crap. Something has gone critically wrong here. Please remove the directory '${blendDirectory}' manually to reset your installation, and report this issue on GitHub if possible." 1>&2
		
		return 6
	fi
}


#Call `uninstallBlend` or `uninstallBlendFile` for each input blend name, depending on the presence of the `--blend-only` flag
command_uninstall()
{
	ensureInstallation
	
	#If the first blend name is "--blend-only", treat it as a flag and only remove the blend directory itself
	if [ "${#}" -gt "1" ] && [ "${1}" = "--blend-only" ]
	then
		shift
		forEachLocalBlend "removeBlendDirectory" "${@}"
	
	#Otherwise, treat all arguments as blends, and fully uninstall them
	#This means that `brew blend uninstall --blend-only` treats '--blend-only' as a blend
	else
		forEachLocalBlend "uninstallBlend" "${@}"
	fi
	
	return 0
}

#Uninstall the blend completely, including any leaf formulae, taps, and casks (all casks are treated as leaves)
uninstallBlend()
{
	#Check if the formula is actually installed before attempting uninstallation
	blendName="${1}"
	blendDirectory="${blendRoot}/${blendName}"
	if [ ! -d "${blendDirectory}" ]
	then
		catStatus "Blend '${blendName}' is not installed" 1>&2
		return 81
	fi
	
	
	#Store a copy of `brew leaves` to compare against after uninstallation
	storedLeaves="$(brew leaves)"
	
	#Do a first-pass at uninstalling leaf formulae
	uninstallComponentType "${blendName}" "brew" "uninstallFormula" "checkFormulaDependency"
	
	#While the leaf formulae keep changing, continue running through the uninstallation
	#This is done to allow the uninstallation of chained formulae that are not used anywhere else
	#For instance, if a blend installs A, B, and C (in that order), where A depends on B depends on C, the first pass will uninstall C, the second B, and the third A until `brew leaves` remains the same indicating there are no more leaf formulae available for uninstall
	#This works in reverse too, if C depends on B depends on A, the first pass will remove A, the second B, and the third C
	#If a formula not in this blend depends on a formula in this blend, brew leaves will not list the formula as a leaf, leading to it not being uninstalled
	leaves="$(brew leaves)"
	while [ "${leaves}" != "${storedLeaves}" ]
	do
		uninstallComponentType "${blendName}" "brew" "uninstallFormula" "checkFormulaDependency"
		storedLeaves="${leaves}"
		leaves="$(brew leaves)"
	done
	
	
	#Uninstall all casks in the blend, ignoring dependencies
	uninstallComponentType "${blendName}" "cask" "uninstallTap" "false"
	
	#Untap all "leaf" taps
	uninstallComponentType "${blendName}" "tap" "uninstallTap" "checkTapDependency"
	
	#Remove the actual blend directory
	#removeBlendDirectory "${blendName}"
	return 0
}

#Uninstall a formula with an input name
uninstallFormula()
{
	name="${1}"
	brew uninstall "${name}"
}

#Check if the formula can be uninstalled, returning failure code if not
#This leverages brew leaves to determine if the formula can be uninstalled without causing issues for other formulae
checkFormulaDependency()
{
	name="${1}"
	test "$(brew uses --installed "${name}")" = ""
}

#Uninstall a cask with an input name
uninstallCask()
{
	name="${1}"
	brew cask uninstall "${name}"
}

#Uninstall a tap with an input name
uninstallTap()
{
	name="${1}"
	brew untap "${name}"
}

#Check if the tap can be uninstalled, returning failure code if not
#This leverages brew list to determine if there are any formulae installed that are part of the tap
checkTapDependency()
{
	name="${1}"
	! brew list --full-name | grep --quiet "^${name}/"
}

#Find all components of the input type, and iterate through each, installing if possible
uninstallComponentType()
{
	#Store arguments in named variables for easy reference
	blendName="${1}"
	componentType="${2}"
	uninstall="${3}"
	dependencyCheck="${4}"
	
	#Set a variable for the blend directory
	blendDirectory="${blendRoot}/${blendName}"
	
	#Search for the input type string in the blend file
	grep "^${componentType}" "${blendDirectory}/${blendName}.${blendFileSuffix}" | \
	
	#Get just the component type and name, so that different arguments between blends do not register as different components
	#This takes something like "tap 'telemachus/brew', 'https://telemachus@bitbucket.org/telemachus/brew.git'" and outputs just "tap 'telemachus/brew',"
	awk '{print $1" "$2}' | \
	
	#Remove the trailing comma, if present
	#Outputs something like "tap 'telemachus/brew'"
	sed -e 's/,$//g' | \
	
	{
		#Iterate through each component, determine if it should be uninstalled, then uninstall it if so
		while read -r component
		do
			#Search all blends except the one being uninstalled for the component intallation string, skipping this component if found
			if grep --quiet --recursive --include="*.brewfile" --exclude-dir="${blendDirectory}" "${component}" "${blendRoot}"
			then
				continue
			fi
			
			#If not found, get just the component name from the "{type} '{name}'" format
			#Outputs something like "telemachus/brew"
			componentName="$(echo "${component}" | awk '{print $2}' | sed -e "s/^'//g" -e "s/'$//g")"
			
			#If no formulae are installed from the given component, run the input uninstallation command
			if "${dependencyCheck}" "${componentName}"
			then
				"${uninstall}" "${componentName}" || true
			fi
		done
	}
}


#Call `checkDifferent` for each input blend
command_update()
{
	ensureInstallation
	
	#Don't attempt an update if no blends installed
	installed="$(command_list)"
	if [ "${installed}" = "" ]
	then
		catStatus "No blends installed"
		return 0
	fi
	
	#Call `checkDifferent` for each input blend, matched against the local (installed) blends
	forEachLocalBlend "checkDifferent" "${installed}"
	
	#If nothing updated, return a status message
	if [ "${updated}" = "false" ]
	then
		catStatus "All blends up-to-date"
	fi
	
	return 0
}

#Compare the stored blend against that in the taps, and print its name if changed
checkDifferent()
{
	#Set some initial variables to prevent duplication
	blendName="${1}"
	
	blendDirectory="${blendRoot}/${1}"
	blendFile="${blendDirectory}/${blendName}.${blendFileSuffix}"
	
	blendTapPath="${2}"
	blendTapFile="${blendTapPath}.${blendFileSuffix}"
	
	#If the tap path is empty, it means that the upstream blend was removed, so print a message to that effect
	if [ "${blendTapPath}" = "" ]
	then
		echo "Blend '${blendName}' has been removed in the upstream tap" 1>&2
		echo "This blend will no longer update, but you won't be affected otherwise" 1>&2
		echo "You can safely remove this blend with 'brew blend uninstall --blend-only ${blendName}' without affecting any existing formulae" 1>&2
		return 0
	fi
	
	#Compare the hashes of the two blend files
	blendHash="$( shasum --portable --algorithm 512256 "${blendFile}" | awk '{print $1}')"
	tapHash="$(shasum --portable --algorithm 512256 "${blendTapFile}" | awk '{print $1}')"
	
	if [ "${blendHash}" != "${tapHash}" ]
	then
		#Print the blend name and set the updated flag to true if the hashes don't match (i.e. there was an upgrade)
		updated="true"
		echo "${blendName}"
	fi
	
	return 0
}


#Run `upgradeBlend` for each blend, either from input or all installed
command_upgrade()
{
	ensureInstallation
	
	#Don't attempt upgrade if no blends installed
	installed="$(command_list)"
	if [ "${installed}" = "" ]
	then
		catStatus "No blends installed"
		return 0
	fi
	
	#If no arguments passed, upgrade all installed blends
	if [ "${#}" = "0" ]
	then
		forEachLocalBlend "upgradeBlend" "${installed}"
	
	#If arguments passed, upgrade just those
	else
		forEachLocalBlend "upgradeBlend" "${@}"
	fi
	
	return 0
}

#Use `brew bundle` to upgrade outdated blends
upgradeBlend()
{
	#If the blend has not changed, don't upgrade it
	blendName="${1}"
	blendTapPath="${2}"
	if [ "$(checkDifferent "${blendName}" "${blendTapPath}")" = "" ]
	then
		return 0
	fi
	
	
	#Initialize some variables for the paths to the blends
	blendDirectory="${blendRoot}/${blendName}"
	blendFile="${blendDirectory}/${blendName}.${blendFileSuffix}"
	
	#Remove the existing Elevage file, and copy the new blend to Elevage
	printStatus "Replacing copy of blend '${blendName}' in Elevage... "
	if rm "${blendFile}" && cp "${blendTapPath}.${blendFileSuffix}" "${blendFile}"
	then
		echoStatus "done"
		
	else
		echoStatus "ERROR"
		return 101
	fi
	
	
	#Upgrade blend using `brew-bundle`
	echoStatus "Using brew-bundle to upgrade blend '${blendName}'..."
	if brew bundle --file="${blendFile}"
	then
		echoStatus "Blend '${blendName}' successfully upgraded"
	
	#On failure, print error message
	else
		echoStatus "ERROR upgrading blend '${blendName}'"
		return 102
	fi
	
	return 0
}


#Parse requested command, and call the corresponding function with the remaining arguments
if [ "${1}" = "help" ] || [ "${1}" = "check" ] || [ "${1}" = "install-self" ] || [ "${1}" = "uninstall-self" ] || [ "${1}" = "list" ] || [ "${1}" = "info" ] || [ "${1}" = "search" ] || [ "${1}" = "install" ] || [ "${1}" = "uninstall" ] || [ "${1}" = "update" ] || [ "${1}" = "upgrade" ]
then
	#Get the command function name, and replace all dashes with underscores
	commandFunction="$(echo "command_${1}" | sed -e 's/-/_/g')"
	
	shift
	"${commandFunction}" "${@}"

#Otherwise, fail with error
else
	echo "Unrecognized command '${1}'" 1>&2
	printUsageMessage 1>&2
	exit 2
fi


exit 0
