#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
COMPOSE_FILE=$SCRIPT_DIR/docker-compose.yaml

function dc(){
  sudo docker compose --env-file=settings.env -f $COMPOSE_FILE "$@"
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

function write_influxdb_importer_login_details_to_json(){
  jq -n \
	  --arg INFLUXDB_PORT "${INFLUXDB_PORT}" \
	  --arg INFLUXDB_ORG "${INFLUXDB_ORG}" \
	  --arg INFLUXDB_BUCKET "${INFLUXDB_BUCKET}" \
	  --arg INFLUXDB_TOKEN "${INFLUXDB_IMPORTER_TOKEN}" \
	  '{influxdb_port: $INFLUXDB_PORT, influxdb_org: $INFLUXDB_ORG, influxdb_bucket: $INFLUXDB_BUCKET, influxdb_token: $INFLUXDB_TOKEN}' \
  	  > influxdb_importer_login_details.json
}

function init_postgres(){
  dc exec -it postgres psql -U ${POSTGRES_USER} -c "create role authenticator noinherit login password '${POSTGRES_PASSWORD}';"
  dc exec -it postgres psql -U ${POSTGRES_USER} -c "grant \"${POSTGRES_USER}\" to authenticator;"
}

function print_results(){
  echo -e "\n\rPorts:"
  echo -e "  Influxdb:  ${INFLUXDB_PORT}"
  echo -e "  Postgres:  ${POSTGRES_PORT}"
  echo -e "  PgAdmin:   ${PGADMIN_PORT}"
  echo -e "  Postgrest: ${POSTGREST_PORT}"
  echo -e "  Grafana:   ${GRAFANA_PORT}"
  echo -e ""
  echo -e "Influxdb API tokens"
  echo -e "  Importer: $INFLUXDB_IMPORTER_TOKEN"
  echo -e "  Grafana:  $INFLUXDB_GRAFANA_TOKEN"
}


source settings.env

dc down
dc up -d

sleep 2

INFLUXDB_IMPORTER_TOKEN=$(generate_influxdb_api_token)
INFLUXDB_GRAFANA_TOKEN=$(generate_influxdb_api_token)

add_influxdb_datasource_to_grafana $INFLUXDB_GRAFANA_TOKEN
add_postgres_datasource_to_grafana

init_postgres

write_influxdb_importer_login_details_to_json

print_results
