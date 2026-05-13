#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# casjaysdevdocker/apprise - nginx + gunicorn + apprise-api init.d
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1003,SC2016,SC2031,SC2120,SC2155,SC2199,SC2317
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
trap 'retVal=$?;[ "$SERVICE_IS_RUNNING" != "yes" ] && [ -f "$SERVICE_PID_FILE" ] && rm -Rf "$SERVICE_PID_FILE";exit $retVal' SIGINT SIGTERM EXIT
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ -f "/config/.debug" ] && [ -z "$DEBUGGER_OPTIONS" ] && export DEBUGGER_OPTIONS="$(<"/config/.debug")" || DEBUGGER_OPTIONS="${DEBUGGER_OPTIONS:-}"
{ [ "$DEBUGGER" = "on" ] || [ -f "/config/.debug" ]; } && echo "Enabling debugging" && set -xo pipefail -x$DEBUGGER_OPTIONS && export DEBUGGER="on" || set -o pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
export PATH="/usr/local/etc/docker/bin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin"
SCRIPT_FILE="$0"
SERVICE_NAME="apprise"
__script_exit() {
	local exit_code="${1:-0}"
	if [ "${BASH_SOURCE[0]}" != "${0}" ]; then return "$exit_code"; else exit "$exit_code"; fi
}
SCRIPT_NAME="$(basename -- "$SCRIPT_FILE" 2>/dev/null)"
if [ ! -f "/run/.start_init_scripts.pid" ]; then
	echo "__start_init_scripts function hasn't been Initialized" >&2
	SERVICE_IS_RUNNING="no"
	__script_exit 1
fi
if [ -f "/usr/local/etc/docker/functions/entrypoint.sh" ]; then
	. "/usr/local/etc/docker/functions/entrypoint.sh"
fi
for set_env in "/root/env.sh" "/usr/local/etc/docker/env"/*.sh "/config/env"/*.sh; do
	[ -f "$set_env" ] && . "$set_env"
done
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
START_SCRIPT="/usr/local/etc/docker/exec/$SERVICE_NAME"
RESET_ENV="no"
WWW_ROOT_DIR="/usr/local/share/apprise-api/webapp"
DATA_DIR="/data/apprise"
CONF_DIR="/config/nginx"
ETC_DIR="/etc/nginx"
VAR_DIR=""
TMP_DIR="/tmp/apprise"
RUN_DIR="/run/apprise"
LOG_DIR="/data/logs/apprise"
WORK_DIR=""
SERVICE_PORT="8000"
RUNAS_USER="root"
SERVICE_USER="root"
SERVICE_GROUP="root"
RANDOM_PASS_USER=""
RANDOM_PASS_ROOT=""
SERVICE_UID="0"
SERVICE_GID="0"
EXEC_CMD_BIN='/usr/local/etc/docker/bin/start-apprise'
EXEC_CMD_ARGS=''
EXEC_PRE_SCRIPT=''
IS_WEB_SERVER="yes"
IS_DATABASE_SERVICE="no"
USES_DATABASE_SERVICE="no"
DATABASE_SERVICE_TYPE=""
PRE_EXEC_MESSAGE="Apprise REST API listening on http://localhost:${SERVICE_PORT:-8000}/"
POST_EXECUTE_WAIT_TIME="1"
PATH="$PATH:."
IP4_ADDRESS="$(__get_ip4)"
IP6_ADDRESS="$(__get_ip6)"
ROOT_FILE_PREFIX="/config/secure/auth/root"
USER_FILE_PREFIX="/config/secure/auth/user"
root_user_name="${APPRISE_ROOT_USER_NAME:-}"
root_user_pass="${APPRISE_ROOT_PASS_WORD:-}"
user_name="${APPRISE_USER_NAME:-}"
user_pass="${APPRISE_USER_PASS_WORD:-}"
[ -f "/config/env/apprise.script.sh" ] && . "/config/env/apprise.script.sh"
[ -f "/config/env/apprise.sh" ] && . "/config/env/apprise.sh"
ADD_APPLICATION_FILES=""
ADD_APPLICATION_DIRS="/usr/local/share/apprise-api /run/apprise /tmp/apprise /config/apprise/store /config/apprise/attach /config/apprise/plugin"
APPLICATION_FILES="$LOG_DIR/$SERVICE_NAME.log"
APPLICATION_DIRS="$ETC_DIR $CONF_DIR $LOG_DIR $TMP_DIR $RUN_DIR $VAR_DIR"
ADDITIONAL_CONFIG_DIRS="/config/apprise"
CMD_ENV="APPRISE_CONFIG_DIR=/config/apprise/store,APPRISE_ATTACH_DIR=/config/apprise/attach,APPRISE_PLUGIN_PATHS=/config/apprise/plugin"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__run_precopy() {
	local hostname=${HOSTNAME}
	if builtin type -t __run_precopy_local | grep -q 'function'; then __run_precopy_local; fi
}
__execute_prerun() {
	local hostname=${HOSTNAME}
	mkdir -p /run/apprise /tmp/apprise /data/logs/apprise \
	         /config/apprise/store /config/apprise/attach /config/apprise/plugin \
	         /config/apprise/conf.d
	chmod 1777 /tmp/apprise 2>/dev/null || true
	if builtin type -t __execute_prerun_local | grep -q 'function'; then __execute_prerun_local; fi
}
__run_pre_execute_checks() {
	local exitStatus=0
	__banner "Running preexecute check for $SERVICE_NAME"
	# Validate nginx config syntax
	nginx -t -c /etc/nginx/nginx.conf 2>&1 | head -20 || exitStatus=$?
	__banner "Finished preexecute check for $SERVICE_NAME: Status $exitStatus"
	if [ $exitStatus -ne 0 ]; then
		echo "The pre-execution check has failed" >&2
		[ -f "$SERVICE_PID_FILE" ] && rm -Rf "$SERVICE_PID_FILE"
		__script_exit 1
	fi
	if builtin type -t __run_pre_execute_checks_local | grep -q 'function'; then __run_pre_execute_checks_local; fi
	return $exitStatus
}
__update_conf_files() {
	local exitCode=0
	local sysname="${SERVER_NAME:-${FULL_DOMAIN_NAME:-$HOSTNAME}}"
	__replace "REPLACE_TZ" "${TZ:-UTC}" "/etc/nginx/nginx.conf" 2>/dev/null || true
	if builtin type -t __update_conf_files_local | grep -q 'function'; then __update_conf_files_local; fi
	return $exitCode
}
__pre_execute() {
	local exitCode=0
	sleep 2
	if builtin type -t __pre_execute_local | grep -q 'function'; then __pre_execute_local; fi
	return $exitCode
}
__post_execute() {
	local pid=""
	local retVal=0
	local ctime=${POST_EXECUTE_WAIT_TIME:-1}
	local waitTime=$((ctime * 60))
	sleep $waitTime
	(
		__banner "Running post commands for $SERVICE_NAME"
		# Drop the sample yaml into /config/apprise/ if not already present
		if [ -f /usr/local/share/template-files/config/apprise/apprise.yml.sample ] && \
		   [ ! -f /config/apprise/apprise.yml.sample ]; then
			cp -f /usr/local/share/template-files/config/apprise/apprise.yml.sample /config/apprise/ 2>/dev/null || true
		fi
		__banner "Finished post commands for $SERVICE_NAME: Status $retVal"
	) 2>"/dev/stderr" | tee -p -a "/data/logs/init.txt" &
	pid=$!
	if builtin type -t __post_execute_local | grep -q 'function'; then __post_execute_local; fi
	return $retVal
}
__pre_message() {
	local exitCode=0
	[ -n "$PRE_EXEC_MESSAGE" ] && eval echo "$PRE_EXEC_MESSAGE"
	if builtin type -t __pre_message_local | grep -q 'function'; then __pre_message_local; fi
	return $exitCode
}
__update_ssl_conf() {
	local exitCode=0
	if builtin type -t __update_ssl_conf_local | grep -q 'function'; then __update_ssl_conf_local; fi
	return $exitCode
}
__create_service_env() {
	local exitCode=0
	if [ ! -f "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" ]; then
		cat <<EOF | tee -p "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" &>/dev/null
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Generated by 99-apprise.sh - edit to override defaults
#APPRISE_WORKER_COUNT=""
#APPRISE_WORKER_TIMEOUT="300"
#APPRISE_BASE_URL=""
#APPRISE_STATEFUL_MODE="simple"
EOF
	fi
	if [ ! -f "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh" ]; then
		__run_precopy_local() { true; }
		__execute_prerun_local() { true; }
		__run_pre_execute_checks_local() { true; }
		__update_conf_files_local() { true; }
		__pre_execute_local() { true; }
		__post_execute_local() { true; }
		__pre_message_local() { true; }
		__update_ssl_conf_local() { true; }
	fi
	__file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" || exitCode=$((exitCode + 1))
	__file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh" || exitCode=$((exitCode + 1))
	return $exitCode
}
__run_start_script() {
	local runExitCode=0
	local cmd="$(eval echo "${EXEC_CMD_BIN:-}")"
	local args="$(eval echo "${EXEC_CMD_ARGS:-}")"
	local name="$(eval echo "${EXEC_CMD_NAME:-}")"
	local sysname="${SERVER_NAME:-${FULL_DOMAIN_NAME:-$HOSTNAME}}"
	[ -f "$CONF_DIR/$SERVICE_NAME.exec_cmd.sh" ] && . "$CONF_DIR/$SERVICE_NAME.exec_cmd.sh"
	if [ ! -x "$cmd" ]; then echo "$cmd is not executable" >&2; return 2; fi
	if __proc_check "nginx"; then echo "nginx already running" >&2; return 0; fi
	echo "Starting $cmd $args" | tee -a -p "/data/logs/init.txt"
	su_cmd touch "$SERVICE_PID_FILE"
	if [ ! -f "$START_SCRIPT" ]; then
		cat <<EOF >"$START_SCRIPT"
#!/usr/bin/env bash
trap 'exitCode=\$?;if [ \$exitCode -ne 0 ] && [ -f "\$SERVICE_PID_FILE" ]; then rm -Rf "\$SERVICE_PID_FILE"; fi; exit \$exitCode' EXIT
set -Eeo pipefail
retVal=10
cmd="$cmd"
SERVICE_NAME="$SERVICE_NAME"
SERVICE_PID_FILE="$SERVICE_PID_FILE"
$cmd $args 2>>"/dev/stderr" >>"$LOG_DIR/$SERVICE_NAME.log" &
execPid=\$!
sleep 3
checkPID="\$(ps ax | awk '{print \$1}' | grep -v grep | grep "\$execPid$" || false)"
[ -n "\$execPid"  ] && [ -n "\$checkPID" ] && echo "\$execPid" >"\$SERVICE_PID_FILE" && retVal=0 || retVal=10
[ "\$retVal" = 0 ] && echo "\$cmd has been started" || echo "Failed to start $cmd $args" >&2
exit \$retVal
EOF
	fi
	[ -x "$START_SCRIPT" ] || chmod 755 -Rf "$START_SCRIPT"
	[ "$CONTAINER_INIT" = "yes" ] || eval sh -c "$START_SCRIPT"
	runExitCode=$?
	return $runExitCode
}
__run_secure_function() {
	local filesperms
	for filesperms in "${USER_FILE_PREFIX}"/* "${ROOT_FILE_PREFIX}"/*; do
		[ -e "$filesperms" ] && { chmod -Rf 600 "$filesperms"; chown -Rf $SERVICE_USER:$SERVICE_USER "$filesperms" 2>/dev/null; }
	done 2>/dev/null
	unset filesperms
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" && . "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh"
__file_exists_with_content "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh" && . "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.local.sh"
SERVICE_EXIT_CODE=0
EXEC_CMD_NAME="$(basename -- "$EXEC_CMD_BIN")"
SERVICE_PID_FILE="/run/init.d/$EXEC_CMD_NAME.pid"
SERVICE_PID_NUMBER="$(__pgrep)"
__check_service "$1" && SERVICE_IS_RUNNING=yes
[ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"
[ -d "$RUN_DIR" ] || mkdir -p "$RUN_DIR"
[ -n "$USER_FILE_PREFIX" ] && { [ -d "$USER_FILE_PREFIX" ] || mkdir -p "$USER_FILE_PREFIX"; }
[ -n "$ROOT_FILE_PREFIX" ] && { [ -d "$ROOT_FILE_PREFIX" ] || mkdir -p "$ROOT_FILE_PREFIX"; }
[ -n "$RUNAS_USER" ] || RUNAS_USER="root"
[ -n "$SERVICE_USER" ] || SERVICE_USER="$RUNAS_USER"
[ -n "$SERVICE_GROUP" ] || SERVICE_GROUP="${SERVICE_USER:-$RUNAS_USER}"
[ "$IS_WEB_SERVER" = "yes" ] && RESET_ENV="yes" && __is_htdocs_mounted
[ "$IS_WEB_SERVER" = "yes" ] && [ -z "$SERVICE_PORT" ] && SERVICE_PORT="8000"
[ -f "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh" ] && . "/config/env/${SERVICE_NAME:-$SCRIPT_NAME}.sh"
sysname="${SERVER_NAME:-${FULL_DOMAIN_NAME:-$HOSTNAME}}"
__create_service_env
__init_config_etc
__execute_prerun
__create_service_user "$SERVICE_USER" "$SERVICE_GROUP" "${WORK_DIR:-/home/$SERVICE_USER}" "${SERVICE_UID:-}" "${SERVICE_GID:-}"
__set_user_group_id $SERVICE_USER ${SERVICE_UID:-} ${SERVICE_GID:-}
__setup_directories
__switch_to_user
__init_working_dir
__pre_message
__update_ssl_conf
__update_ssl_certs
__run_secure_function
__run_precopy
for config_2_etc in $CONF_DIR $ADDITIONAL_CONFIG_DIRS; do
	__initialize_system_etc "$config_2_etc" 2>/dev/stderr | tee -p -a "/data/logs/init.txt"
done
__initialize_replace_variables "$ETC_DIR" "$CONF_DIR" "$ADDITIONAL_CONFIG_DIRS" "$WWW_ROOT_DIR"
__update_conf_files
__pre_execute
__fix_permissions "$SERVICE_USER" "$SERVICE_GROUP"
__run_pre_execute_checks 2>/dev/stderr | tee -a -p "/data/logs/entrypoint.log" "/data/logs/init.txt" || return 20
__run_start_script 2>>/dev/stderr | tee -p -a "/data/logs/entrypoint.log"
errorCode=$?
if [ -n "$EXEC_CMD_BIN" ]; then
	if [ "$errorCode" -eq 0 ]; then SERVICE_EXIT_CODE=0; SERVICE_IS_RUNNING="yes"; else SERVICE_EXIT_CODE=$errorCode; SERVICE_IS_RUNNING="${SERVICE_IS_RUNNING:-no}"; [ -s "$SERVICE_PID_FILE" ] || rm -Rf "$SERVICE_PID_FILE"; fi
	SERVICE_EXIT_CODE=0
fi
__post_execute 2>"/dev/stderr" | tee -p -a "/data/logs/init.txt" &
__banner "Initializing of $SERVICE_NAME has completed with statusCode: $SERVICE_EXIT_CODE" | tee -p -a "/data/logs/entrypoint.log" "/data/logs/init.txt"
__script_exit $SERVICE_EXIT_CODE
