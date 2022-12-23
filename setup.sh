#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
COMPOSE_FILE=$SCRIPT_DIR/docker-compose.yaml

function dc(){
  sudo docker compose --env-file=settings.env -f $COMPOSE_FILE $@
}

function generate_influxdb_api_token(){
  local ret_json=$(dc exec influxdb influx auth create \
    --all-access \
    --json)
  local token=$(echo $ret_json | grep -oP '(?<="token": ")[^"]*' )
  echo $token
}

function add_influxdb_datasource_to_grafana(){
  cp $SCRIPT_DIR/templates/grafana-influxdb-datasource.yaml.template $SCRIPT_DIR/grafana-influxdb-datasource.yaml
  sed -i 's/INFLUXDB_GRAFANA_TOKEN/'$1'/g' $SCRIPT_DIR/grafana-influxdb-datasource.yaml

  dc cp \
    $SCRIPT_DIR/grafana-influxdb-datasource.yaml \
    grafana:/etc/grafana/provisioning/datasources/

  dc restart grafana
  rm $SCRIPT_DIR/grafana-influxdb-datasource.yaml
}

function add_postgres_datasource_to_grafana(){
  cp $SCRIPT_DIR/templates/grafana-postgres-datasource.yaml.template $SCRIPT_DIR/grafana-postgres-datasource.yaml

  dc cp \
	$SCRIPT_DIR/grafana-postgres-datasource.yaml \
	grafana:/etc/grafana/provisioning/datasources/

  dc restart grafana
  rm $SCRIPT_DIR/grafana-postgres-datasource.yaml
}

source settings.env

dc down
dc up -d

sleep 2

INFLUXDB_IMPORTER_TOKEN=$(generate_influxdb_api_token)
INFLUXDB_GRAFANA_TOKEN=$(generate_influxdb_api_token)

add_influxdb_datasource_to_grafana $INFLUXDB_GRAFANA_TOKEN
add_postgres_datasource_to_grafana

export INFLUXDB_URL="http://localhost:${INFLUXDB_PORT}"
export INFLUXDB_ORG="${INFLUXDB_ORG}"
export INFLUXDB_BUCKET="${INFLUXDB_BUCKET}"
export INFLUXDB_TOKEN=$INFLUXDB_IMPORTER_TOKEN

echo -e "Influxdb API tokens\n"
echo -e "  Importer: \t$INFLUXDB_IMPORTER_TOKEN\n"
echo -e "  Grafana: \t$INFLUXDB_GRAFANA_TOKEN\n"

