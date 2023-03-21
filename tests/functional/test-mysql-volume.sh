#!/usr/bin/env bash

set -e

LIFERAY_CLI_BRANCH="next"

if [ "$LIFERAY_CLI_BRANCH" != "" ]; then
	git clone \
		--branch $LIFERAY_CLI_BRANCH \
		--depth 1 \
		https://github.com/liferay/liferay-cli \
		${LOCALDEV_REPO}/tests/work/liferay

	cd ${LOCALDEV_REPO}/tests/work/liferay

	CLI="./gow run main.go"
else
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/liferay/liferay-cli/HEAD/install.sh)"

	CLI="liferay"
fi

$CLI config set localdev.resources.dir ${LOCALDEV_REPO}

$CLI config set localdev.resources.sync false

$CLI runtime mkcert

$CLI runtime mkcert --install

BASE_PATH=${LOCALDEV_REPO}/tests/work/workspace/client-extensions

mkdir -p $BASE_PATH

export WORKSPACE_BASE_PATH="$BASE_PATH"
export BUILD_PROJECTS="false"

$CLI ext create \
	-d ${WORKSPACE_BASE_PATH} \
	-v \
	--noprompt \
	-- \
	--resource-path="template/global-css" \
	--workspace-path="test-global-css" \
	--args=id="test-global-css" \
	--args=name="Test Global CSS"

# copy the Tiltfile.mysql into workspace

cp ${LOCALDEV_REPO}/resources/tilt/Tiltfile.mysql ${WORKSPACE_BASE_PATH}/

$CLI ext start -d ${WORKSPACE_BASE_PATH} &

FOUND_LOCALDEV_SERVER=0

until [ "$FOUND_LOCALDEV_SERVER" == "1" ]; do
	sleep 5
	FOUND_LOCALDEV_SERVER=$(docker ps | grep localdev-extension-runtime | wc -l)
	echo "FOUND_LOCALDEV_SERVER=${FOUND_LOCALDEV_SERVER}"
done

FOUND_DB_SERVER=0

until [ "$FOUND_DB_SERVER" == "1" ]; do
	sleep 5
	FOUND_DB_SERVER=$(docker ps | grep mysql | wc -l)
	echo "FOUND_DB_SERVER=${FOUND_DB_SERVER}"
done

FOUND_EXT_PROVISION_CONFIG_MAPS=0

until [ "$FOUND_EXT_PROVISION_CONFIG_MAPS" == "1" ]; do
	sleep 5
	FOUND_EXT_PROVISION_CONFIG_MAPS=$(docker exec -i localdev-extension-runtime /entrypoint.sh kubectl get cm | grep ext-provision-metadata | wc -l | xargs)
	echo "FOUND_EXT_PROVISION_CONFIG_MAPS=${FOUND_EXT_PROVISION_CONFIG_MAPS}"
	docker logs -n 50 localdev-extension-runtime
done

$CLI ext stop -v

DXP_DOCKER_VOLUME_NAME=$(docker volume ls | grep dxpData | awk '{print $2}')

if [ "$DXP_DOCKER_VOLUME_NAME" == "" ]; then
	echo "Could not find expected docker volume named 'dxpData'"
	exit 1
else
	echo "Found docker volume named $DXP_DOCKER_VOLUME_NAME"
fi

MYSQL_DOCKER_VOLUME_NAME=$(docker volume ls | grep mysqlData | awk '{print $2}')

if [ "$MYSQL_DOCKER_VOLUME_NAME" == "" ]; then
	echo "Could not find expected docker volume named 'mysqlData'"
	exit 1
else
	echo "Found docker volume named $MYSQL_DOCKER_VOLUME_NAME"
fi