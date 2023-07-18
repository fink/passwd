#!/bin/bash
# shellcheck disable=SC2236,SC2207
#
# Merge Fink's passwd and group additions into DirectoryServices
#


# Config
prefixPath="&&PRFIX&&"

DarwinVersion="$(uname -r | cut -d. -f1)"
sysadminctlVersion="17" # macOS 10.13
if [ "${DarwinVersion}" -ge "${sysadminctlVersion}" ]; then
	sysadminctlVersionRun="1"
fi



# Use sysadminctl for primary user creation
function dsImport () {
	local name="${1}"
	local uid="${2}"
	local gid="${3}"
	local home="${4}"
	local shell="${5}"
	local info="${6}"
	local output

	output="$(dsimport /dev/stdin '/Local/Default' 'I' --outputfile "/dev/stdout" --template StandardUser <<< "${name}:*:${uid}:${gid}:${info}:${home}:${shell}")"

	if ! /usr/libexec/PlistBuddy -c "Print :Succeeded:0" /dev/stdin <<< "${output}" 2> /dev/null; then
		echo "Could not create user: ${name}" >&2
		exit 1
	fi

	dscl . create "/users/${name}" IsHidden 1
	dscl . delete "/users/${name}" AuthenticationAuthority
	dscl . delete "/users/${name}" accountPolicyData

	defaults write /Library/Preferences/com.apple.loginwindow HiddenUsersList -array-add "${name}"

	dscacheutil -q user -a name "${name}" 2> /dev/null
}

# Use dscl for primary user creation
function dsclUser () {
	local name="${1}"
	local uid="${2}"
	local gid="${3}"
	local home="${4}"
	local shell="${5}"
	local info="${6}"


	if ! dscl . create "/users/${name}"; then
		echo "Could not create user: ${name}" >&2
		exit 1
	fi
	dscl . create "/users/${name}" uid "${uid}"
	dscl . create "/users/${name}" name "${name}"
	dscl . create "/users/${name}" passwd '*'
	dscl . create "/users/${name}" hint ""
	dscl . create "/users/${name}" gid "${gid}"
	dscl . create "/users/${name}" home "${home}"
	dscl . create "/users/${name}" shell "${shell}"
	dscl . create "/users/${name}" realname "${info}"

	dscl . create "/users/${name}" IsHidden 1
	dscl . delete "/users/${name}" AuthenticationAuthority

	defaults write /Library/Preferences/com.apple.loginwindow HiddenUsersList -array-add "${name}"

	dscacheutil -q user -a name "${name}" 2> /dev/null
}

# Use dseditgroup for primary group creation
function dseditgroupGroup () {
	local groupname="${1}"
	local gid="${2}"
	local groupmembership="${3}"


	if ! dseditgroup -o create -i "${gid}" "${groupname}"; then
		echo "Could not create group: ${groupname}" >&2
		exit 1
	fi
	dscl . create "/groups/${groupname}" passwd '*'
	dscl . create "/groups/${groupname}" GroupMembership "${groupmembership}"

	dscl . create "/groups/${groupname}" IsHidden 1

	dscacheutil -q group -a name "${groupname}" 2> /dev/null
}

# Use dscl for primary group creation
function dsclGroup () {
	local groupname="${1}"
	local gid="${2}"
	local groupmembership="${3}"


	if ! dscl . create "/groups/${groupname}"; then
		echo "Could not create group: ${groupname}" >&2
		exit 1
	fi
	dscl . create "/groups/${groupname}" name "${groupname}"
	dscl . create "/groups/${groupname}" passwd '*'
	dscl . create "/groups/${groupname}" gid "${gid}"
	dscl . create "/groups/${groupname}" GroupMembership "${groupmembership}"

	dscl . create "/groups/${groupname}" IsHidden 1

	dscacheutil -q group -a name "${groupname}" 2> /dev/null
}

# Add user alias
function userAlias () {
	local sysUser="${1}"
	local aliUser="${2}"


	dscl . -merge "/users/${sysUser}" RecordName "${aliUser}"
}

# Add group alias
function groupAlias () {
	local sysGroup="${1}"
	local aliGroup="${2}"


	dscl . -merge "/groups/${sysGroup}" RecordName "${aliGroup}"
}

# Get uid
function uidNumber () {
	local name="${1}"
	local _uid

	if [ ! -z "${fixedUserFink}" ]; then
		_uid="$(grep "^${name}:" "${fixedUserFink}" 2>/dev/null | cut -d ':' -f '3')"
	elif [ ! -z "${uidMin}" ]; then
		local testUid="${uidMin}"
		while [ "${testUid}" -le "${uidMax}" ]; do
			if [ ! -z "$(dscacheutil -q user -a uid "${testUid}" 2> /dev/null)" ]; then
				testUid="$((testUid + 1))"
			else
				_uid="${testUid}"
				break
			fi
		done
	fi

	# No uid found
	if [ -z "${_uid}" ]; then
		tee >&2 <<- EOF
			I could not find an unused UID in the range ${uidMin} - ${uidMax}.
			You can expand this range by changing the AutoUidMin and/or
			AutoUidMax values in ${prefixPath}/etc/passwd.conf.

			##########################################

			Make sure to run 'fink reinstall passwd-${SHORTNAME}'
			to install the ${SHORTNAME} entry, or you can create
			it manually if you would prefer to do that.

			##########################################

		EOF
		exit 1
	elif [ ! -z "$(dscacheutil -q user -a uid "${_uid}" 2> /dev/null)" ]; then
		tee >&2 <<- EOF
			UID ${_uid} is already in use
		EOF
		exit 1
	fi

	echo "${_uid}"
}

# Get gid
function gidNumber () {
	local groupname="${1}"
	local _gid

	if [ ! -z "${fixedGroupFink}" ]; then
		_gid="$(grep "^${name}:" "${fixedGroupFink}" 2>/dev/null | cut -d ':' -f '3')"
	elif [ ! -z "${uidMin}" ]; then
		local testGid="${uidMin}"
		while [ "${testGid}" -le "${uidMax}" ]; do
			if [ ! -z "$(dscacheutil -q group -a gid "${testGid}" 2> /dev/null)" ]; then
				testGid="$((testGid + 1))"
			else
				_gid="${testGid}"
				break
			fi
		done
	fi

	# No gid found
	if [ -z "${_gid}" ]; then
		tee >&2 <<- EOF
			I could not find an unused GID in the range ${uidMin} - ${uidMax}.
			You can expand this range by changing the AutoUidMin and/or
			AutoUidMax values in ${prefixPath}/etc/passwd.conf.

			##########################################

			Make sure to run 'fink reinstall passwd-${GROUPNAME}'
			to install the ${GROUPNAME} entry, or you can create
			it manually if you would prefer to do that.

			##########################################

		EOF
		exit 1
	elif [ ! -z "$(dscacheutil -q group -a gid "${_gid}" 2> /dev/null)" ]; then
		tee >&2 <<- EOF
			GID ${_gid} is already in use
		EOF
		exit 1
	fi

	echo "${_gid}"
}


# Usage message.
function upUsage () {
	tee >&2 << EOF
usage:	update-passwd -n <Short-Name> -g <Group-Name> [-h <Home-Dir>] [-s <Shell>] -i <Info-String> -m <Group-Members>
	update-passwd -g <Group-Name> -m <Group-Members>
	update-passwd -V

	Options include:
	-n short-name		= User short name
	-g group-name		= Name of (primary) group
	-h home-dir		= Home directory path (optional)
	-s shell		= Path to login shell (optional)
	-i info-string		= Long discription of user
	-m group-members	= A list of group membersips by name
	-V			= emit version and exit
	-?			= help message
EOF
	exit 1
}

# Config
UPVERSION="&&UPVERSION&&"
while getopts ":n:g:h:s:i:m:V" OPTION; do
	case "${OPTION}" in
		n)
			SHORTNAME="${OPTARG}"
		;;
		g)
			GROUPNAME="${OPTARG}"
		;;
		h)
			HOME="${OPTARG}"
		;;
		s)
			SHELL="${OPTARG}"
		;;
		i)
			INFO="${OPTARG}"
		;;
		m)
			MEMBERS="${OPTARG}"
		;;
		V)
			echo "update-passwd ${UPVERSION}"
			exit 0
		;;
		?)
			# If an unknown flag is used (or -?):
			upUsage
		;;
	esac
done


# Check if needed software is installed.
PATH="${PATH}:/usr/local/sbin:/usr/local/bin"
commands=(
dscl
dscacheutil
defaults
id
sed
grep
cut
tr
tee
)
if [ "${sysadminctlVersionRun}" = "1" ]; then
commands+=(
dsimport
dseditgroup
dsmemberutil
/usr/libexec/PlistBuddy
)
fi
for command in "${commands[@]}"; do
	if ! type "${command}" &> /dev/null; then
		echo "${command} is missing, please install" >&2
		exit 100
	fi
done


### Verify that update-passwd was called correctly
if [ "$(/usr/bin/id -u)" -ne "0" ]; then
	echo "You must be root to run update-passwd."
	exit 1
fi

# Set the operating mode
if [ ! -z "${SHORTNAME}" ]; then
	opMode="user"
	: "${HOME:="/var/empty"}"
	: "${SHELL:="/usr/bin/false"}"
	if [ -z "${INFO}" ] || [ -z "${GROUPNAME}" ] || [ -z "${MEMBERS}" ]; then
		upUsage
	fi
elif [ ! -z "${GROUPNAME}" ]; then
	opMode="group"
	if [ -z "${MEMBERS}" ]; then
		upUsage
	fi
else
	upUsage
fi


# Decide if ids are static or dynamic
if [ "$(grep '^AutoUid:' "${prefixPath}/etc/passwd.conf" | sed -e 's:[[:blank:]]\{1,\}: :g' | cut -d ' ' -f "2")" = "true" ]; then
	uidMin="$(grep '^AutoUidMin:' "${prefixPath}/etc/passwd.conf" | sed -e 's:[[:blank:]]\{1,\}: :g' | cut -d ' ' -f '2')"
	uidMax="$(grep '^AutoUidMax:' "${prefixPath}/etc/passwd.conf" | sed -e 's:[[:blank:]]\{1,\}: :g' | cut -d ' ' -f '2')"
elif [ -f "${prefixPath}/etc/passwd-fink.conf" ] && [ -f "${prefixPath}/etc/group-fink.conf" ]; then
	fixedUserFink="${prefixPath}/etc/passwd-fink.conf"
	fixedGroupFink="${prefixPath}/etc/group-fink.conf"
fi



# Setup group
echo "Checking to see if the group ${GROUPNAME} exists:"
if [ ! -z "$(dscacheutil -q group -a name "${GROUPNAME}" 2> /dev/null)" ]; then
	echo "Group ${GROUPNAME} already exists."
elif [ ! -z "$(dscacheutil -q group -a name "_${GROUPNAME}" 2> /dev/null)" ]; then
	echo "Group _${GROUPNAME} exists; creating alias..."
	groupAlias "_${GROUPNAME}" "${GROUPNAME}"
	dscl . -merge "/groups/_${GROUPNAME}" GroupMembership "${MEMBERS}"
else
	echo "Group ${GROUPNAME} does not exist; creating..."
	gidNumber="$(gidNumber "${GROUPNAME}")"
	if [ "${sysadminctlVersionRun}" = "1" ]; then
		dseditgroupGroup "${GROUPNAME}" "${gidNumber}" "${MEMBERS}"
	else
		dsclGroup "${GROUPNAME}" "${gidNumber}" "${MEMBERS}"
	fi
fi



# Setup user
if [ "${opMode}" = "user" ]; then
	echo "Checking to see if the user ${SHORTNAME} exists:"
fi
if [ "${opMode}" = "user" ] && [ ! -z "$(dscacheutil -q user -a name "${SHORTNAME}" 2> /dev/null)" ]; then
	echo "User ${SHORTNAME} already exists."
elif [ "${opMode}" = "user" ] && [ ! -z "$(dscacheutil -q user -a name "_${SHORTNAME}" 2> /dev/null)" ]; then
	echo "User _${SHORTNAME} exists; creating alias..."
	userAlias "_${SHORTNAME}" "${SHORTNAME}"
elif [ "${opMode}" = "user" ]; then
	echo "User ${SHORTNAME} does not exist; creating..."
	: "${gidNumber="$(dscl . -read "/groups/${GROUPNAME}" PrimaryGroupID | cut -d ' ' -f '2')"}"
	if [ "${sysadminctlVersionRun}" = "1" ]; then
		dsImport "${SHORTNAME}" "$(uidNumber "${SHORTNAME}")" "${gidNumber}" "${HOME}" "${SHELL}" "${INFO}"
		dsmemberutil flushcache
	else
		dsclUser "${SHORTNAME}" "$(uidNumber "${SHORTNAME}")" "${gidNumber}" "${HOME}" "${SHELL}" "${INFO}"
	fi
fi




# kill local directory service so it will see our local
# file changes -- it will automatically restart
/usr/bin/killall DirectoryService 2>/dev/null || /usr/bin/killall opendirectoryd 2>/dev/null
