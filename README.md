# nginx_3scale agent
nginx_3scale agent is a module that is responsible for providing authentication,
authorization and metering of BigchainDB API users, by communicating with 3scale.
We use the openresty for this, which is nginx bundled with lua libraries.
More information at their [website](openresty.org/en)

It is the entrypoint to the BigchainDB cluster, and validates the tokens sent 
by users in HTTP headers for authorization.
The user tokens map directly to the Application Plan specified in 3scale.

## Getting nginx_3scale
Git clone the source, compile and run the executable.
The executable can be compiled to a static binary by simply using the Makefile 
commands.

Alternatively, if you'd like to use Docker you can get an image with 
`make builddocker` from the source dir or 
`docker pull bigchaindb/nginx_3scale:0.1` to get a pre-built image from docker hub.

## Working

* We define a [lua module](./nginx.lua.template) and
  custom hooks (lua functions to be executed at certain phases of the nginx
  request processing lifecycle) to authenticate an API request.

* Download the template available from 3scale which pre-defines all the
  rules defined using the 3Scale UI for monitoring, and the basic nginx
  configuration.

* We heavily modify these templates to add our custom functionality.

* The nginx_3scale agent takes command line parameters from the user and
  accordingly creates the nginx.conf and nginx.lua files from the templates.

* After generating the required conf and lua files, it exec's nginx using this
  conf file, so that it replaces the running binary with nginx.

* Every request calls the `_M.access()` function. This function extracts the
  `app_id` and `app_key` from the HTTP request headers and forwards it to
  3Scale to see if a request is allowed to be forwarded to the BigchainDB
  backend. The request also contains the
  various parameters that one would like to set access policies on. If the
  `app_id` and `app_key` is successful, the access rules for the parameters
  passed with the request are checked to see if the request can pass through.
  For example, we can send a parameter, say `request_body_size`, to the 3Scale
  auth API. If we have defined a rule in the 3Scale dashboard to drop
  `request_body_size` above a certain threshold, the authorization will fail
  even if the `app_id` and `app_key` are valid.

* A successful response from the auth API causes the request to be proxied to
  the backend. After a backend response, the `_M.post_action_content` hook is
  called. We calculate details about all the metrics we are interested in and
  form a payload for the 3Scale reporting API. This ensures that we update
  parameters of every metric defined in the 3Scale UI after every request.

* Note: We do not cache the keys in nginx so that we can validate every request
  with 3Scale and apply plan rules immediately. We can add auth caching to
  improve performance, and in case we move to a fully post-paid billing model.

* Refer to the references made in the [lua module](./nginx.lua.template) for 
  more details about how nginx+lua+3scale works

## Set up a dev environment
Golang development environment, tested with v1.7.4.
Docker, tested with 1.13.0
GNU make, tested with 4.1

## Running nginx_3scale agent
```text
docker run \
    --name=nginx_3scale \
    --publish=8080:8080 \
    --publish=80:80 \
    --restart=always \
    bigchaindb/nginx_3scale:0.1 \
    --3scale-secret-token "<secret response token set in 3scale to validate 3scale requests>" \
    --3scale-service-id "<3scale service id>" \
    --3scale-version-header "<3scale/nginx version header>" \
    --frontend-api-dns-name <frontend dns name/ip> \
    --frontend-api-port <port for our frontend> \
    --health-check-port <health check port> \
    --provider-key "<3scale provider key>"
    --upstream-api-port "proxy port for bdb backend" \
    --upstream-bdb-host "host for dbd backend" \
    --upstream-bdb-port "port for bdb backend"
```

## TCP Ports
Currently binds to all interfaces at ports `health-check-port`, 
`upstream-api-port` and `frontend-api-port`.

## Deployment terminology
We currently use the terms `frontend`, `backend`, `upstream` in our code and
configuration. This diagram should help understand the various terms.
```
                              +------------+                                                   +----------+
                              |            |                                                   |          |
+-----------------------------+----+    N  |                             +---------------------+------+   |
|      Frontend API Port           |    G  |                             |     Upstream  DB Port      |   |
|                                  |    I  |                             |                            |   |
|[port number exposed globally     |    N  |                  +--------> |[port where BDB instance    |   |
| for backend BDB cluster services]|    X  |                  |          | listens/waits for requests]|   |
+-----------------------------+----+       |                  |          +---------------------+------+   |
                              |         G  |                  |                                |          |
                              |         A  |                  |                                | Upstream |
                              |         T  |                  |                                | BDB Host |
+-----------------------------+----+    E  |                  |                                +----------+
|       Health Check Port          |    W  |                  |
|                                  |    A  |                  |
|  [port number exposed to the LB  |    Y  |                  |
|   for health checks]             |       |                  |
+-----------------------------+----+       |                  |
                              |       +----+------------------+----------+
                              |       |     Upstream API Port            |
                              |       |                                  |
                              |       |[internal port where we can       |
                              |       |access backend BDB cluster service|
                              |       +----------------------------------+
                              +------------+
```

