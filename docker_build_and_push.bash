#!/bin/bash

docker build -t bigchaindb/nginx_3scale:1.6 .

docker push bigchaindb/nginx_3scale:1.6
