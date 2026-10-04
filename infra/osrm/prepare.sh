#!/bin/sh
# Builds the OSRM (MLD) dataset once from the Iraq extract downloaded by `osrm-download`.
# Karbala is a small part of it; the full country keeps the setup simple and covers districts.
set -eu
cd /data
if [ -f iraq-latest.osrm.mldgr ]; then
  echo "OSRM data already prepared"; exit 0
fi
osrm-extract -p /opt/car.lua iraq-latest.osm.pbf
osrm-partition iraq-latest.osrm
osrm-customize iraq-latest.osrm
echo "OSRM data ready"
