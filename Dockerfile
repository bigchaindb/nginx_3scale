# Dockerfile based on the one hosted at 
# https://github.com/openresty/docker-openresty/blob/master/alpine/Dockerfile
# and https://github.com/openresty/docker-openresty

#FROM openresty/openresty:xenial
FROM openresty/openresty:alpine
MAINTAINER krish@bigchaindb.com
WORKDIR /

COPY nginx.conf.template /usr/local/openresty/nginx/conf/
COPY nginx.lua.template /usr/local/openresty/nginx/conf/
COPY nginx_3scale_wrapper/nginx_3scale /

EXPOSE 80 8080
#FIXME(krish): VOLUME for nginx logs?
ENTRYPOINT ["/nginx_3scale"]
