#!/bin/bash
set -euo pipefail

mongodb_frontend_port=`printenv MONGODB_FRONTEND_PORT`
mongodb_backend_host=`printenv MONGODB_BACKEND_HOST`
mongodb_backend_port=`printenv MONGODB_BACKEND_PORT`
bdb_frontend_port=`printenv BIGCHAINDB_FRONTEND_PORT`
bdb_backend_host=`printenv BIGCHAINDB_BACKEND_HOST`
bdb_backend_port=`printenv BIGCHAINDB_BACKEND_PORT`
mongodb_whitelist=`printenv MONGODB_WHITELIST`
dns_server=`printenv DNS_SERVER`

nginx_health_check_port=`printenv NGINX_HEALTH_CHECK_PORT`

threescale_secret_token=`printenv THREESCALE_SECRET_TOKEN`
threescale_service_id=`printenv THREESCALE_SERVICE_ID`
threescale_version_header=`printenv THREESCALE_VERSION_HEADER`
threescale_provider_key=`printenv THREESCALE_PROVIDER_KEY`
threescale_frontend_api_dns_name=`printenv THREESCALE_FRONTEND_API_DNS_NAME`
threescale_upstream_api_port=`printenv THREESCALE_UPSTREAM_API_PORT`

# sanity checks TODO(Krish): hardening
if [[ -z "${mongodb_frontend_port}" || \
    -z "${mongodb_backend_host}" || \
    -z "${mongodb_backend_port}" || \
    -z "${bdb_frontend_port}" || \
    -z "${bdb_backend_host}" || \
    -z "${bdb_backend_port}" || \
    -z "${dns_server}" || \
    -z "${nginx_health_check_port}" || \
    -z "${threescale_secret_token}" || \
    -z "${threescale_service_id}" || \
    -z "${threescale_version_header}" || \
    -z "${threescale_provider_key}" || \
    -z "${threescale_frontend_api_dns_name}" || \
    -z "${threescale_upstream_api_port}" ]] ; then
  echo "Invalid environment settings detected. Exiting!"
  exit 1
fi

NGINX_LUA_FILE=/usr/local/openresty/nginx/conf/nginx.lua
NGINX_CONF_FILE=/usr/local/openresty/nginx/conf/nginx.conf

# configure the nginx.lua file with env variables
sed -i "s|SERVICE_ID|${threescale_service_id}|g" $NGINX_LUA_FILE
sed -i "s|THREESCALE_RESPONSE_SECRET_TOKEN|${threescale_secret_token}|g" $NGINX_LUA_FILE
sed -i "s|PROVIDER_KEY|${threescale_provider_key}|g" $NGINX_LUA_FILE

# configure the nginx.conf file with env variables
sed -i "s|MONGODB_FRONTEND_PORT|${mongodb_frontend_port}|g" $NGINX_CONF_FILE
sed -i "s|MONGODB_BACKEND_HOST|${mongodb_backend_host}|g" $NGINX_CONF_FILE
sed -i "s|MONGODB_BACKEND_PORT|${mongodb_backend_port}|g" $NGINX_CONF_FILE
sed -i "s|BIGCHAINDB_FRONTEND_PORT|${bdb_frontend_port}|g" $NGINX_CONF_FILE
sed -i "s|BIGCHAINDB_BACKEND_HOST|${bdb_backend_host}|g" $NGINX_CONF_FILE
sed -i "s|BIGCHAINDB_BACKEND_PORT|${bdb_backend_port}|g" $NGINX_CONF_FILE
sed -i "s|DNS_SERVER|${dns_server}|g" $NGINX_CONF_FILE
sed -i "s|UPSTREAM_API_PORT|${threescale_upstream_api_port}|g" $NGINX_CONF_FILE
sed -i "s|SERVICE_ID|${threescale_service_id}|g" $NGINX_CONF_FILE
sed -i "s|FRONTEND_DNS_NAME|${threescale_frontend_api_dns_name}|g" $NGINX_CONF_FILE
sed -i "s|PROVIDER_KEY|${threescale_provider_key}|g" $NGINX_CONF_FILE
sed -i "s|THREESCALE_VERSION_HEADER|${threescale_version_header}|g" $NGINX_CONF_FILE
sed -i "s|HEALTH_CHECK_PORT|${nginx_health_check_port}|g" $NGINX_CONF_FILE
sed -i "s|THREESCALE_RESPONSE_SECRET_TOKEN|${threescale_secret_token}|g" $NGINX_CONF_FILE

# populate the whitelist in the conf file as per MONGODB_WHITELIST env var
hosts=$(echo ${mongodb_whitelist} | tr ":" "\n")
for host in $hosts; do
  sed -i "s|MONGODB_WHITELIST|allow ${host};\n    MONGODB_WHITELIST|g" $NGINX_CONF_FILE
done

# remove the MONGODB_WHITELIST marker string from template
sed -i "s|MONGODB_WHITELIST||g" $NGINX_CONF_FILE

# start nginx
echo "INFO: starting nginx..."
exec /usr/local/openresty/nginx/sbin/nginx -c ${NGINX_CONF_FILE}
