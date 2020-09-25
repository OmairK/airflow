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
# Script to check licences for all code. Can be started from any working directory
# shellcheck source=scripts/in_container/_in_container_script_init.sh
. "$( dirname "${BASH_SOURCE[0]}" )/_in_container_script_init.sh"

EXIT_CODE=0

export DISABLED_INTEGRATIONS=""

#######################################################################################################
#
# Checks the status of a service
# 
# Arguments:
#   Service name
#   Call, command to check the service status
#   Max Checks
#
# Modified globals:
#   EXIT_CODE
#######################################################################################################
function check_environment::check_service {
    local integration_name
    local call
    local max_check
    local last_check_result
    local res
    integration_name=$1
    call=$2
    max_check=${3:=1}

    echo -n "${integration_name}: "
    while true
    do
        set +e
        last_check_result=$(eval "${call}" 2>&1)
        res=$?
        set -e
        if [[ ${res} == 0 ]]; then
            echo -e " \e[32mOK.\e[0m"
            break
        else
            echo -n "."
            max_check=$((max_check-1))
        fi
        if [[ ${max_check} == 0 ]]; then
            echo -e " \e[31mERROR!\e[0m"
            echo "Maximum number of retries while checking service. Exiting"
            break
        else
            sleep 1
        fi
    done
    if [[ ${res} != 0 ]]; then
        echo "Service could not be started!"
        echo
        echo "$ ${call}"
        echo "${last_check_result}"
        echo
        EXIT_CODE=${res}
    fi
}

#######################################################################################################
#
# Checks the status of an integration service
# 
# Arguments:
#   Integration name
#   Call, command to check the service status
#   Max Checks
# 
# Used globals:
#   DISABLED_INTEGRATIONS
#   
# Returns:
#   None
#   
#######################################################################################################
function check_environment::check_integration {
    local integration_name=$1

    local env_var_name=INTEGRATION_${integration_name^^}
    if [[ ${!env_var_name:=} != "true" ]]; then
        DISABLED_INTEGRATIONS="${DISABLED_INTEGRATIONS} ${integration_name}"
        return
    fi
    check_environment::check_service "${@}"
}

#######################################################################################################
#
# Status check for different db backends
# 
# Arguments:
#   Max Checks
#
# Used globals:
#   BACKEND
# 
# Returns:
#   None for success and 1 for error.
#
#######################################################################################################
function check_environment::check_db_backend {
    MAX_CHECK=${1:=1}

    if [[ ${BACKEND} == "postgres" ]]; then
        check_environment::check_service "postgres" "nc -zvv postgres 5432" "${MAX_CHECK}"
    elif [[ ${BACKEND} == "mysql" ]]; then
        check_environment::check_service "mysql" "nc -zvv mysql 3306" "${MAX_CHECK}"
    elif [[ ${BACKEND} == "sqlite" ]]; then
        return
    else
        echo "Unknown backend. Supported values: [postgres,mysql,sqlite]. Current value: [${BACKEND}]"
        exit 1
    fi
}

#######################################################################################################
#
# Resets the Airflow's meta db.
# 
# Used globals:
#   DB_RESET
#   RUN_AIRFLOW_1_10
# 
# Returns:
#   0 if the db is reset, non-zero on error.
#######################################################################################################
function check_environment::resetdb_if_requested() {
    if [[ ${DB_RESET:="false"} == "true" ]]; then
        if [[ ${RUN_AIRFLOW_1_10} == "true" ]]; then
            airflow resetdb -y
        else
            airflow db reset -y
        fi
    fi
    return $?
}

#######################################################################################################
#
# Starts airflow if requested.
# 
# Used globals:
#   BASH_SOURCE
#   SESSION
#
# Modified globals:
#   START_AIRFLOW
#
# Returns:
#   0 if the db is reset, non-zero on error.
#######################################################################################################
function check_environment::startairflow_if_requested() {
    if [[ ${START_AIRFLOW:="false"} == "true" ]]; then

        . "$( dirname "${BASH_SOURCE[0]}" )/configure_environment.sh"

        # initialize db and create the admin user if it's a new run
        airflow db init
        airflow users create -u admin -p admin -f Thor -l Adminstra -r Admin -e dummy@dummy.email

        #this is because I run docker in WSL - Hi Bill!
        export TMUX_TMPDIR=~/.tmux/tmp
        mkdir -p ~/.tmux/tmp
        chmod 777 -R ~/.tmux/tmp

        # Set Session Name
        readonly SESSION="Airflow"

        # Start New Session with our name
        tmux new-session -d -s $SESSION

        # Name first Pane and start bash
        tmux rename-window -t 0 'Main'
        tmux send-keys -t 'Main' 'bash' C-m 'clear' C-m

        tmux split-window -v
        tmux select-pane -t 1
        tmux send-keys 'airflow scheduler' C-m

        tmux split-window -h
        tmux select-pane -t 2
        tmux send-keys 'airflow webserver' C-m

        # Attach Session, on the Main window
        tmux select-pane -t 0
        tmux send-keys 'cd /opt/airflow/' C-m 'clear' C-m

        tmux attach-session -t $SESSION:0
    fi
    return $?
}

echo "==============================================================================================="
echo "             Checking integrations and backends"
echo "==============================================================================================="
if [[ -n ${BACKEND=} ]]; then
    check_environment::check_db_backend 20
    echo "-----------------------------------------------------------------------------------------------"
fi
check_environment::check_integration kerberos "nc -zvv kerberos 88" 30
check_environment::check_integration mongo "nc -zvv mongo 27017" 20
check_environment::check_integration redis "nc -zvv redis 6379" 20
check_environment::check_integration rabbitmq "nc -zvv rabbitmq 5672" 20
check_environment::check_integration cassandra "nc -zvv cassandra 9042" 20
check_environment::check_integration openldap "nc -zvv openldap 389" 20
check_environment::check_integration presto "nc -zvv presto 8080" 40
echo "-----------------------------------------------------------------------------------------------"

if [[ ${EXIT_CODE} != 0 ]]; then
    echo
    echo "Error: some of the CI environment failed to initialize!"
    echo
    # Fixed exit code on initialization
    # If the environment fails to initialize it is re-started several times
    exit 254
fi

check_environment::resetdb_if_requested
check_environment::startairflow_if_requested

if [[ -n ${DISABLED_INTEGRATIONS=} ]]; then
    echo
    echo "Disabled integrations:${DISABLED_INTEGRATIONS}"
    echo
    echo "Enable them via --integration <INTEGRATION_NAME> flags (you can use 'all' for all)"
    echo
fi

exit 0
