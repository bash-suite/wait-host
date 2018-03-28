#!/bin/sh

#
# `wait-host.sh` is an sh script that will wait on the availability of a host and TCP port.
# Specially designed to be used in Alpine container, It is useful for synchronizing 
# interdependent services, such as linked docker containers.  
#
# You can use it to wait for a database to be ready, for php-fpm connection, ...
#


# set -e : Exit the script if any statement returns a non-true return value.
# set -u : Exit the script when using uninitialised variable.
#set -eu

# Default values
readonly progname=$(basename $0)

# Display help message
function getHelp() {
    cat << USAGE >&2

Usage: $progname [host:port] [OPTIONS] [-- command args]

    -h | --host         Host or IP under test
    -p | --port         TCP port under test
                        Alternatively, you can specify the host and port as host:port
    -d | --delay        Delay in seconds, before trying to contact the host.
    -m | --message      Delay message
    -s | --strict       Only execute subcommand if the test succeeds
    -q | --quiet        Don't output any status messages
    -t | --timeout      Timeout in seconds, zero for no timeout

    -- command args     Execute command with args after the test finishes

Examples:
    $progname mysql:3306        Wait indefinitely for port 3306 to be available on host mysql
    $progname google.com:80     Wait indefinitely for port 80 to be available on host google.com
    $progname mysql:3306 -t 15  Wait a maximum of 15s for port 3306 to be available on host mysql

    Use echo \$? to get the result

Full example:
    $progname mysql:3306 \\
                -t 120 \\
                -d 2 \\
                -m 'Waiting for database connection on host:\$HOST and port:\$PORT' \\
                -s \\
                -- echo "Database connection established" \\
                || echo "Error while trying to connect to the database"

    Wait 120 seconds for port 3306 to be available on host mysql
    Display a custom message every 2 seconds
    Display a custom message on success
    Display a custom message on error (strict mode)

USAGE
}

# echo the message if not in quiet mode
function echoerr() {
    [ "$QUIET" -ne 1 ] && printf "%s\n" "$*" 1>&2
}

function do_wait() {
    while :
    do
        # Check for connection on host
        nc -z -w 1 "$HOST" "$PORT"
        result=$?

        # Display message on error
        if [ $result -ne 0 ]; then
            echoerr "$MESSAGE"
            sleep $DELAY
        else
            break
        fi
    done
    
    return $result
}

function wait_for_host() {
    if [ "$TIMEOUT" -gt 0 ]; then
        # Waiting message
        echoerr "Waiting $TIMEOUT seconds for $HOST:$PORT"
        # trap SIGINT SIGTERM
        trap 'kill -SIGTERM $TIMEOUT_ID 2>/dev/null; return 1' SIGINT SIGTERM
        # use timeout function to rerun the script without timeout
        timeout -t "$TIMEOUT" -s TERM "$0" -h=$HOST -p=$PORT -d=$DELAY -m="$MESSAGE" -s=$STRICT -q=$QUIET -t=0 &
        # get the process id
        TIMEOUT_ID=$! 
        # wait to the end of the timeout unless it is killed
        while kill -0 $TIMEOUT_ID > /dev/null 2>&1; do
            wait
        done
        # Last check to get an error at the end of the timeout
        nc -z -w 1 "$HOST" "$PORT"
        result=$?
    else
        do_wait
        # get the result of the wait function
        result=$?
    fi

    return $result
}

# Default values
STRICT=0
QUIET=0
TIMEOUT=0
DELAY=2
MESSAGE='Waiting connection for $HOST:$PORT'

# Get input parameters
while [ $# -gt 0 ]; do
    case "$1" in
        
        [!-]*:* )
            THOST=$(printf "%s\n" "$1"| cut -d : -f 1)
            TPORT=$(printf "%s\n" "$1"| cut -d : -f 2)
            [ -z "$HOST" ] && HOST=$THOST
            case $TPORT in
                ''|*[!0-9]*) break ;;
                *) [ -z "$PORT" ] && PORT=$TPORT ;;
            esac
            shift 1
        ;;

        -h|--host)
            HOST="$2"
            [ -z "$HOST" ] && break
            shift 2
        ;;

        -h=*|--host=*)
            HOST=$(printf "%s" "$1" | cut -d = -f 2)
            shift 1
        ;;

        -p|--port)
            case $2 in
                ''|*[!0-9]*) break ;;
                *) PORT="$2" ;;
            esac
            shift 2
        ;;

        -p=*|--port=*)
            case ${1#*=} in
                ''|*[!0-9]*) break ;;
                *) PORT="${1#*=}" ;;
            esac
            shift 1
        ;;

        -d|--delay)
            case $2 in
                ''|*[!0-9]*) break ;;
                *) DELAY="$2" ;;
            esac
            shift 2
        ;;
        
        -d=*|--delay=*)
            case ${1#*=} in
                ''|*[!0-9]*) break ;;
                *) DELAY="${1#*=}" ;;
            esac
            shift 1
        ;;

        -m|--message)
            MESSAGE="$2"
            shift 2
        ;;
        
        -m=*|--message=*)
            MESSAGE=$(printf "%s" "$1" | cut -d = -f 2)
            shift 1
        ;;

        -s|--strict)
            STRICT=1
            shift 1
        ;;

        -s=*|--strict=*)
            case ${1#*=} in
                ''|[!0-1]) break ;;
                *) STRICT="${1#*=}" ;;
            esac
            shift 1
        ;;

        -q|--quiet)
            QUIET=1
            shift 1
        ;;

        -q=*|--quiet=*)
            case ${1#*=} in
                ''|[!0-1]) break ;;
                *) QUIET="${1#*=}" ;;
            esac
            shift 1
        ;;

        -t|--timeout)
            case $2 in
                ''|*[!0-9]*) break ;;
                *) TIMEOUT="$2" ;;
            esac
            shift 2
        ;;
        
        -t=*|--timeout=*)
            case ${1#*=} in
                ''|*[!0-9]*) break ;;
                *) TIMEOUT="${1#*=}" ;;
            esac
            shift 1
        ;;

        --)
            shift
            break
        ;;

        --help)
            getHelp
            exit 0
        ;;

        *)
            echoerr "Invalid argument '$1'. Use --help to see the valid options"
            exit 1
        ;;

    esac
done

# check for host and port
if [ -z "$HOST" -o -z "$PORT" ]; then
    echoerr "Invalid host or port. Use --help to see the valid options."
    exit 2
fi

# Update the HOST and PORT in the default message
MESSAGE=$(eval "echo $MESSAGE")

# Start waiting for the host
wait_for_host
WAIT_RESULT=$?

# If not in strict mode, execute the subcommand whatever
# the result of wait_for_host
if [ "$*" != "" ]; then
    if [ $WAIT_RESULT -ne 0 -a $STRICT -eq 1 ]; then
        echoerr "Error while in strict mode. Refusing to execute subcommand"
    else
        exec "$@"
    fi
fi

# Exit with the result  of wait_for_host 
exit $WAIT_RESULT
