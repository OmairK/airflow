#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

#######################################################################################################
#
# Adds trap to the traps already set.
#
# Arguments:
#      trap to set
#      .... list of signals to handle
#######################################################################################################
function container_utils::add_trap() {
    trap="${1}"
    shift
    for signal in "${@}"
    do
        # adding trap to exiting trap
        local handlers
        handlers="$( trap -p "${signal}" | cut -f2 -d \' )"
        # shellcheck disable=SC2064
        trap "${trap};${handlers}" "${signal}"
    done
}

#######################################################################################################
#
# Asserts and warns the user if this script is called out of the breeze env.
#
# Used globals:
#   VERBOSE
#######################################################################################################
function container_utils::assert_in_container() {
    export VERBOSE=${VERBOSE:="false"}
    if [[ ! -f /.dockerenv ]]; then
        echo >&2
        echo >&2 "You are not inside the Airflow docker container!"
        echo >&2 "You should only run this script in the Airflow docker container as it may override your files."
        echo >&2 "Learn more about how we develop and test airflow in:"
        echo >&2 "https://github.com/apache/airflow/blob/master/CONTRIBUTING.rst"
        echo >&2
        exit 1
    fi
}

#######################################################################################################
#
# Prints more verbose output of the scripts
#
# Modified globals:
#   VERBOSE_COMMANDS
#
# Returns:
#   None
#######################################################################################################
function container_utils::in_container_script_start() {
    if [[ ${VERBOSE_COMMANDS:="false"} == "true" ]]; then
        set -x
    fi
}

#######################################################################################################
#
# Prints the output of the error before exiting the script
#
# Arguments:
#   exit_code
#
# Globals used:
#   PRINT_INFO_FROM_SCRIPTS
#   OUT_FILE_PRINTED_ON_ERROR
#
#######################################################################################################
function container_utils::in_container_script_end() {
    #shellcheck disable=2181
    local exit_code
    exit_code=$?
    if [[ ${exit_code} != 0 ]]; then
        if [[ "${PRINT_INFO_FROM_SCRIPTS=="true"}" == "true" ]] ;then
            if [[ -n ${OUT_FILE_PRINTED_ON_ERROR=} ]]; then
                echo "  ERROR ENCOUNTERED!"
                echo
                echo "  Output:"
                echo
                cat "${OUT_FILE_PRINTED_ON_ERROR}"
                echo "###########################################################################################"
            fi
            echo "###########################################################################################"
            echo "  [IN CONTAINER]   EXITING ${0} WITH STATUS CODE ${exit_code}"
            echo "###########################################################################################"
        fi
    fi

    if [[ ${VERBOSE_COMMANDS} == "true" ]]; then
        set +x
    fi
}

#######################################################################################################
#
# Cleans up PYC files (in case they come in mounted folders)
#
#######################################################################################################
function container_utils::in_container_cleanup_pyc() {
    set +o pipefail
    sudo find . \
        -path "./airflow/www/node_modules" -prune -o \
        -path "./airflow/www_rbac/node_modules" -prune -o \
        -path "./.eggs" -prune -o \
        -path "./docs/_build" -prune -o \
        -path "./build" -prune -o \
        -name "*.pyc" | grep ".pyc$" | sudo xargs rm -f
    set -o pipefail
}

#######################################################################################################
#
# Cleans up __pycache__ directories (in case they come in mounted folders)
#
#######################################################################################################
function container_utils::in_container_cleanup_pycache() {
    set +o pipefail
    find . \
        -path "./airflow/www/node_modules" -prune -o \
        -path "./airflow/www_rbac/node_modules" -prune -o \
        -path "./.eggs" -prune -o \
        -path "./docs/_build" -prune -o \
        -path "./build" -prune -o \
        -name "__pycache__" | grep "__pycache__" | sudo xargs rm -rf
    set -o pipefail
}

#######################################################################################################
#
# Fixes ownership of files generated in container - if they are owned by root, they will be owned by
# The host user. Only needed if the host is Linux - on Mac, ownership of files is automatically
# changed to the Host user via osxfs filesystem
# 
# Used globals:
#   AIRFLOW_SOURCES
#   VERBOSE
#   HOST_USER_ID
#   HOST_GROUP_ID
#
# Modified globals:
#   HOST_OS 
#######################################################################################################
function container_utils::in_container_fix_ownership() {
    if [[ ${HOST_OS:=} == "Linux" ]]; then
        local directories_to_fix
        directories_to_fix=(
                "/tmp"
                "/files"
                "/root/.aws"
                "/root/.azure"
                "/root/.config/gcloud"
                "/root/.docker"
                "${AIRFLOW_SOURCES}"
        )
        if [[ ${VERBOSE} == "true" ]]; then
            echo "Fixing ownership of mounted files"
        fi
        sudo find "${directories_to_fix[@]}" -print0 -user root 2>/dev/null \
            | sudo xargs --null chown "${HOST_USER_ID}.${HOST_GROUP_ID}" --no-dereference ||
                true >/dev/null 2>&1
        if [[ ${VERBOSE} == "true" ]]; then
            echo "Fixed ownership of mounted files"
        fi
    fi
}
#######################################################################################################
#
# Cleans up the temp dir in container.
#
# Used globals:
#   VERBOSE
#   AIRFLOW_SOURCES
#
#######################################################################################################
function container_utils::in_container_clear_tmp() {
    if [[ ${VERBOSE} == "true" ]]; then
        echo "Cleaning ${AIRFLOW_SOURCES}/tmp from the container"
    fi
    rm -rf /tmp/*
    if [[ ${VERBOSE} == "true" ]]; then
        echo "Cleaned ${AIRFLOW_SOURCES}/tmp from the container"
    fi
}

#######################################################################################################
#
# Pushes the airflow sources to the stack for easy access thoroughout the script.
#
# Used globals:
#   AIRFLOW_SOURCES
#######################################################################################################
function container_utils::in_container_go_to_airflow_sources() {
    pushd "${AIRFLOW_SOURCES}"  &>/dev/null || exit 1
}

#######################################################################################################
#
# Basic sanity which checks if its in the container followed by pushing the AIRFLOW SOURCE onto the 
# stack and then cleaning up pyc and pycache files from the container.
#
#######################################################################################################
function container_utils::in_container_basic_sanity_check() {
    container_utils::assert_in_container
    container_utils::in_container_go_to_airflow_sources
    container_utils::in_container_cleanup_pyc
    container_utils::in_container_cleanup_pycache
}

#######################################################################################################
#
# Sets up the pylint 
# 
# Used globals:
#   VERBOSE
#   AIRFLOW_SOURCES
#   DISABLE_CHECKS_FOR_TESTS
#
#######################################################################################################
function container_utils::in_container_refresh_pylint_todo() {
    if [[ ${VERBOSE} == "true" ]]; then
        echo
        echo "Refreshing list of all non-pylint compliant files. This can take some time."
        echo

        echo
        echo "Finding list  all non-pylint compliant files everywhere except 'tests' folder"
        echo
    fi
    # Using path -prune is much better in the local environment on OSX because we have host
    # Files mounted and node_modules is a huge directory which takes many seconds to even scan
    # -prune works better than -not path because it skips traversing the whole directory. -not path traverses
    # the directory and only excludes it after all of it is scanned
    find . \
        -path "./airflow/www/node_modules" -prune -o \
        -path "./airflow/www_rbac/node_modules" -prune -o \
        -path "./airflow/migrations/versions" -prune -o \
        -path "./.eggs" -prune -o \
        -path "./docs/_build" -prune -o \
        -path "./build" -prune -o \
        -path "./tests" -prune -o \
        -name "*.py" \
        -not -name 'webserver_config.py' | \
        grep  ".*.py$" | \
        xargs pylint | tee "${AIRFLOW_SOURCES}/scripts/ci/pylint_todo_main.txt"

    grep -v "\*\*" < "${AIRFLOW_SOURCES}/scripts/ci/pylint_todo_main.txt" | \
       grep -v "^$" | grep -v "\-\-\-" | grep -v "^Your code has been" | \
       awk 'BEGIN{FS=":"}{print "./"$1}' | sort | uniq > "${AIRFLOW_SOURCES}/scripts/ci/pylint_todo_new.txt"

    if [[ ${VERBOSE} == "true" ]]; then
        echo
        echo "So far found $(wc -l <"${AIRFLOW_SOURCES}/scripts/ci/pylint_todo_new.txt") files"
        echo

        echo
        echo "Finding list of all non-pylint compliant files in 'tests' folder"
        echo
    fi
    find "./tests" -name "*.py" -print0 | \
        xargs -0 pylint --disable="${DISABLE_CHECKS_FOR_TESTS}" | tee "${AIRFLOW_SOURCES}/scripts/ci/pylint_todo_tests.txt"

    grep -v "\*\*" < "${AIRFLOW_SOURCES}/scripts/ci/pylint_todo_tests.txt" | \
        grep -v "^$" | grep -v "\-\-\-" | grep -v "^Your code has been" | \
        awk 'BEGIN{FS=":"}{print "./"$1}' | sort | uniq >> "${AIRFLOW_SOURCES}/scripts/ci/pylint_todo_new.txt"

    rm -fv "${AIRFLOW_SOURCES}/scripts/ci/pylint_todo_main.txt" "${AIRFLOW_SOURCES}/scripts/ci/pylint_todo_tests.txt"
    mv -v "${AIRFLOW_SOURCES}/scripts/ci/pylint_todo_new.txt" "${AIRFLOW_SOURCES}/scripts/ci/pylint_todo.txt"

    if [[ ${VERBOSE} == "true" ]]; then
        echo
        echo "Found $(wc -l <"${AIRFLOW_SOURCES}/scripts/ci/pylint_todo.txt") files"
        echo
    fi
}

export DISABLE_CHECKS_FOR_TESTS="missing-docstring,no-self-use,too-many-public-methods,protected-access,do-not-use-asserts"

#######################################################################################################
#
# Starts up the scheduler heartbeat and binds the PID to env variable
#
# Modified globals:
#   HEARTBEAT_PID
#
#######################################################################################################
function container_utils::start_output_heartbeat() {
    local message
    local interval
    message=${1:-"Still working!"}
    interval=${2:=10}
    echo
    echo "Starting output heartbeat"
    echo

    bash 2> /dev/null <<EOF &
while true; do
  echo "\$(date): ${message} "
  sleep ${interval}
done
EOF
    export HEARTBEAT_PID=$!
}

#######################################################################################################
#
# Clears the resourses associated with the scheduler heartbeat.
#
# Used globals:
#   HEARTBEAT_PID
#
#######################################################################################################
function container_utils::stop_output_heartbeat() {
    kill "${HEARTBEAT_PID}"
    wait "${HEARTBEAT_PID}" || true 2> /dev/null
}

#######################################################################################################
#
# Perform the setup for kerberos authentication.
#
# Used globals:
#   AIRFLOW_SOURCES
#   AIRFLOW_HOME
#
#######################################################################################################
function container_utils::setup_kerberos() {
    local fqdn
    fqdn=$(hostname)
    local admin="admin"
    local pass="airflow"
    local krb5_ktname=/etc/airflow.keytab
    local res_1
    local res_2
    local res_2

    sudo cp "${AIRFLOW_SOURCES}/scripts/in_container/krb5/krb5.conf" /etc/krb5.conf

    echo -e "${pass}\n${pass}" | \
        sudo kadmin -p "${admin}/admin" -w "${pass}" -q "addprinc -randkey airflow/${fqdn}" 2>&1 \
          | sudo tee "${AIRFLOW_HOME}/logs/kadmin_1.log" >/dev/null
    res_1=$?

    sudo kadmin -p "${admin}/admin" -w "${pass}" -q "ktadd -k ${krb5_ktname} airflow" 2>&1 \
          | sudo tee "${AIRFLOW_HOME}/logs/kadmin_2.log" >/dev/null
    res_2=$?

    sudo kadmin -p "${admin}/admin" -w "${pass}" -q "ktadd -k ${krb5_ktname} airflow/${fqdn}" 2>&1 \
          | sudo tee "${AIRFLOW_HOME}/logs``/kadmin_3.log" >/dev/null
    res_3=$?

    if [[ ${res_1} != 0 || ${res_2} != 0 || ${res_3} != 0 ]]; then
        exit 1
    else
        echo
        echo "Kerberos enabled and working."
        echo
        sudo chmod 0644 "${krb5_ktname}"
    fi
}


#######################################################################################################
#
# Dumps the airflow logs to the files directory in the container.
#
# Used globals:
#   AIRFLOW_HOME
#   CI_BUILD_ID
#   CI_JOB_ID
#
#######################################################################################################
function container_utils::dump_airflow_logs() {
    local dump_file
    dump_file=/files/airflow_logs_$(date "+%Y-%m-%d")_${CI_BUILD_ID}_${CI_JOB_ID}.log.tar.gz
    echo "###########################################################################################"
    echo "                   Dumping logs from all the airflow tasks"
    echo "###########################################################################################"
    pushd "${AIRFLOW_HOME}" || exit 1
    tar -czf "${dump_file}" logs
    echo "                   Logs dumped to ${dump_file}"
    popd || exit 1
    echo "###########################################################################################"
}


#######################################################################################################
#
# Dumps the airflow logs to the files directory in the container.
#
# Arguments:
#   AIRFLOW
# Used globals:
#   AIRFLOW_SOURCES
#
# Modify globals:
#   SLUGIFY_USES_TEXT_UNIDECODE
#######################################################################################################
function container_utils::install_released_airflow_version() {
    local installs
    pip uninstall -y apache-airflow || true
    find /root/airflow/ -type f -print0 | xargs -0 rm -f --
    if [[ ${1} == "1.10.2" || ${1} == "1.10.1" ]]; then
        export SLUGIFY_USES_TEXT_UNIDECODE=yes
    fi
    rm -rf "${AIRFLOW_SOURCES}"/*.egg-info
    installs=("apache-airflow==${1}" "werkzeug<1.0.0")
    pip install --upgrade "${installs[@]}"
}


export CI=${CI:="false"}
export GITHUB_ACTIONS=${GITHUB_ACTIONS:="false"}
