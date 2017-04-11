FROM openresty/openresty:xenial
LABEL maintainer "dev@bigchaindb.com"
WORKDIR /
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get autoremove \
    && apt-get clean
COPY nginx.conf.template /usr/local/openresty/nginx/conf/nginx.conf
COPY nginx.lua.template /usr/local/openresty/nginx/conf/nginx.lua
COPY nginx_entrypoint.bash /
EXPOSE 80 8080 8888 27017
ENTRYPOINT ["/nginx_entrypoint.bash"]
