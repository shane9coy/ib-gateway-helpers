#!/bin/bash

# Sends a command to the specified instance of IBC, for example to cause it
# to initiate a tidy closedown or restart of TWS or Gateway.
#
# Usage: commandsend.sh <COMMAND> [args...]
#   e.g. commandsend.sh RECONNECTDATA
#        commandsend.sh SECURITY_CODE 123456
#        commandsend.sh RELOADCONFIG

# You may need to change this line. Set it to the name or IP address of the
# computer that is running IBC. Note that you can use the local loopback
# address (127.0.0.1) if IBC is running on the current machine.

server_address=127.0.0.1

# You may need to change this line. Make sure it's set to the value of the
# CommandServerPort setting in config.ini:

command_server_port=7462


# You shouldn't need to change anything below this line.
#==============================================================================


if [[ -z "$1" ]]; then
	>&2 echo -e "Error: you must supply a valid IBC command as the first argument"
	>&2 exit 1
fi

# SECURITY_CODE takes an extra argument (the 6-digit code itself).
# All other IBC commands are single-token.
if [[ "${1^^}" == "SECURITY_CODE" ]]; then
	if [[ -z "${2:-}" ]]; then
		>&2 echo -e "Error: SECURITY_CODE requires the 6-digit code as the second argument"
		>&2 exit 1
	fi
	ibc_cmd="SECURITY_CODE ${2}"
else
	ibc_cmd="$1"
fi

# Use nc (OpenBSD) — telnet isn't installed on this Pi.
( printf '%s\n' "$ibc_cmd"; sleep 1; printf 'EXIT\n'; printf 'quit\n' ) \
	| nc -w 4 "$server_address" "$command_server_port"
