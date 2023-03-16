#!/bin/bash

function generate_password(){
	password=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c32)
	sed -i "s/^$1.*/$1=\"$password\"/g" settings.env
}



generate_password 'INFLUXDB_PASSWORD'
generate_password 'POSTGRES_PASSWORD'
generate_password 'PGADMIN_PASSWORD'
generate_password 'POSTGRES_JWT'
generate_password 'GRAFANA_PASSWORD'
