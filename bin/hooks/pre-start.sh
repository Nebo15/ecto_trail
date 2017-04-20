#!/bin/sh
# `pwd` should be /opt/change_logger
APP_NAME="change_logger"

if [ "${DB_MIGRATE}" == "true" ]; then
  echo "[WARNING] Migrating database!"
  ./bin/$APP_NAME command "${APP_NAME}_tasks" migrate!
fi;
