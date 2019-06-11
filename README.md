## ![](https://github.com/docker-suite/artwork/raw/master/logo/png/logo_32.png) wait-host
![License: MIT](https://img.shields.io/github/license/docker-suite/goss.svg?color=green&style=flat-square)

`wait-host.sh` is an sh script that will wait on the availability of a host and TCP port.  
Specially designed to be used in Alpine container, It is useful for synchronizing interdependent services, such as linked docker containers. 
You can use it to wait for a database to be ready, for php-fpm connection, ...


## ![](https://github.com/docker-suite/artwork/raw/master/various/pin/png/pin_16.png) Usage

```
Usage: wait-host.sh [host:port] [OPTIONS] [-- command args]

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
    wait-host.sh mysql:3306        Wait indefinitely for port 3306 to be available on host mysql
    wait-host.sh google.com:80     Wait indefinitely for port 80 to be available on host google.com
    wait-host.sh mysql:3306 -t 15  Wait a maximum of 15s for port 3306 to be available on host mysql

Full example:
    wait-host.sh mysql:3306 \
                -t 120 \
                -d 2 \
                -m 'Waiting for database connection on host: and port:' \
                -s \
                -- echo "Database connection established" \
                || echo "Error while trying to connect to the database"

    Wait 120 seconds for port 3306 to be available on host mysql
    Display a custom message every 2 seconds
    Display a custom message on success
    Display a custom message on error (strict mode)
```
