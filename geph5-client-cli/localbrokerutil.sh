#!/bin/bash
# cargo install geph5-client

# this script is intended to work for macos
# launcher for geph 5 client, assign with a pid, open and connect at startup
geph_client_path="$HOME/.cargo/bin/geph5-client"
default_yaml_path="$HOME/.config/.bridge/client-config.yaml"
pid_path="/tmp/localbroker.pid"
standard_log="/tmp/localbroker.log"
error_log="/tmp/localbroker-error.log"
socks5_port="9909"
http_port="9910"


# A. HEALTHCHECKS
# utility check methods
check_config() {
    # checking that geph-client and config yaml exists
    exit_code=0
    if ! [ -f $geph_client_path ]
        then echo "Error: broker not found: $geph_client_path" >&2
        exit_code=1
        fi
    if ! [ -f $default_yaml_path ]
        then echo "Error: config yaml not found: $default_yaml_path" >&2
        exit_code=1
        fi
    if [ $exit_code -eq 0 ]; then echo "configuration ok"; fi
    return $exit_code
}

check_port() {
    # check occupancy with lsof
    if [ -z $(lsof -i ":$1" | grep "LISTEN" | awk '{print $1}') ]
        then return 1
    else
        return 0
    fi
}

get_pid() {
    pid=$(cat "$pid_path" | tr -d "\n")
    # check if pid is valid
    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid PID value in $pid_path." >&2
        return 1
    fi
    return $pid
}

# i. pre-connect check
pre_connect_check() {
    check_config
}

# ii. in-use checks
check_ip_change() {
    # obtain raw ip
    unset http_proxy https_proxy
    raw_ip=$(curl ifconfig.me 2> /dev/null)
    sleep 0.5
    # obtain brokered ip
    export http_proxy="http://localhost:9910"
    export https_proxy="http://localhost:9910"
    brokered_ip=$(curl ifconfig.me 2> /dev/null)
    unset http_proxy https_proxy
    # display and compare IPs
    echo "Original IP: $raw_ip"
    echo "Brokered IP: $brokered_ip"
    if [ raw_ip = brokered_ip ]
        then echo "FATAL: Brokered IP same as original, possible IP leak." >&2
        return 1
        else echo "Broker masked IP, pass."
    fi
    return 0
}

check_process() {
    pid=$(get_pid)
    # check process exists
    if ! ps -p $PID > /dev/null
        then echo "ERROR: process not found" >&2
        return 1
    fi
    # check process name matches
    
}

# iii. manual status check
status() {
    echo "[Status Check]"
    # whence pid file does not exist
    if ! [ -f "$pid_path" ]; then
        echo "turned OFF"
        if check_port $socks5_port
            then echo "Process not running, but socks5 port occupied." >&2
            return 1
        elif check_port $http_port
            then echo "Process not running, but http port occupied." >&2
            return 1
        else
            echo "Process not running, ports clear."
            return 0
        fi
    fi
    # whence the pid file exists
    # check status of current process
    echo "turned ON"
    pid=$(cat "$pid_path" | tr -d "\n")
    # check if pid is valid
    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid PID value in $pid_path." >&2
        return 1
    fi
    # return 0
    # check if socks5 and http ports are in use
    if ! check_port $socks5_port
        then echo "Error: PID file found, but socks5 not used." >&2
        return 1
    elif ! check_port $http_port
        then echo "Error: PID file found, but https port not used." >&2
        return 1
    else
        echo "Process is running on pid: $pid"
    fi
    # check_ip_change
    # exit_code=$?
    # if [ $exit_code -eq 1 ]
    #     then echo "IP leak detected, stopped."  >&2
    #     stop
    #     return 1
    #     fi
    return 0
}

# iv. TODO: frequent health check -- check progress
frequent_health_check() {
    # process check
    check_process
    return 0
}

# v. TODO: infrequent health check -- check connection status


# manually start, immediately return after sending to nohup
start() {
    echo "[Start]"
    # check if config file exists
    check_config
    exit_code=$?
    if [ $exit_code -eq 1 ]
        then echo "Configuration check failed, cannot start."  >&2
        return 1
        fi
    # create a nohup task
    nohup $geph_client_path --config $default_yaml_path \
        > "$standard_log" \
        2> "$error_log" &
    pid=$!
    # make a tempfile to store the pid
    echo $pid > $pid_path
    echo "running on pid $pid"
    check_ip_change
    exit_code=$?
    if [ $exit_code -eq 1 ]
        then echo "IP leak detected, abort."  >&2
        stop
        return 1
        fi
    return 0
}

# manually stop, kill process and cleanup
cleanup() {
    # delete pid file
    rm "$pid_path"
    # remove processes on the 
}

trap cleanup TERM 

stop() {
    echo "[Stop]"
    if [ -f "$pid_path" ]; then
        pid=$(cat "$pid_path")
        kill $pid
        if [ $? -eq 0 ]; then
            echo "Stopped process with PID: $pid";
            rm "$pid_path"
            return 0
        else
            echo "Error: Failed to stop process with PID: $pid" >&2
            return 1
        fi
    else
        echo "Error: PID file not found." >&2
        return 1
    fi
}

# to be compatible with launchctl, run geph on background, while doing health check occasionally
run() {
    # start, raise on failure
    start
    exit_code=$?
    if [ $exit_code -eq 1 ]
        then return 1
    fi
    # conduct frequent and infrequent health checks
    sleep 5
    frequent_health_check
    exit_code=$?
    if [ $exit_code -eq 1 ]
        then return 1
    fi
}

# handle argument
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    check_config)
        check_config
        ;;
    check_ip_change)
        check_ip_change
        ;;
    check_port)
        check_port
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|check_config|check_ip_change|status}"
        exit 1
        ;;
esac
