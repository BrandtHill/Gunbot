#!/usr/bin/env bash

docker stop gunbot

docker rm gunbot

sed -e 's/^export //g' -e 's/"//g' .env > .env.docker

docker run -d --log-opt max-size=5m --network host --env-file .env.docker --restart always --name gunbot brandt/gunbot
