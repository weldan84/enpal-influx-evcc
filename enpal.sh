#!/bin/sh

# Zugangsdaten
INFLUX_HOST="YOUR_INFLUX_HOST"
INFLUX_ORG_ID="YOUR_INFLUX_ORG_ID"
INFLUX_BUCKET="YOUR_INFLUX_BUCKET"
INFLUX_TOKEN="YOUR_INFLUX_TOKEN"
INFLUX_API="${INFLUX_HOST}/api/v2/query?orgID=${INFLUX_ORG_ID}"
QUERY_RANGE_START="-5m"

case $1 in
# Gesamtverbrauch
consumption)
  var=$(curl --request POST "${INFLUX_API}" \
    --header "Authorization: Token ${INFLUX_TOKEN}" \
    --header "Accept: application/json" \
    --header "Content-type: application/vnd.flux" \
    --data "from(bucket: \"$INFLUX_BUCKET\")
            |> range(start: $QUERY_RANGE_START})
            |> filter(fn: (r) => r._measurement == \"Gesamtleistung\")
            |> filter(fn: (r) => r._field == \"Verbrauch\")
            |> keep(columns: [\"_value\"])
            |> last()") >/dev/null 2>&1
  var="${var##*,}"
  ;;
# Netzbezug/Einspeisung
grid)
  pv=$(enpal pv)
  consumption=$(enpal consumption)
  battery=$(enpal battery)
  # shellcheck disable=SC2004
  echo $(($consumption - $pv - $battery))
  exit 0
  ;;
# Aktuelle Solarproduktion
pv)
  var=$(curl --request POST "${INFLUX_API}" \
    --header "Authorization: Token ${INFLUX_TOKEN}" \
    --header "Accept: application/json" \
    --header "Content-type: application/vnd.flux" \
    --data "from(bucket: \"$INFLUX_BUCKET\")
            |> range(start: $QUERY_RANGE_START)
            |> filter(fn: (r) => r._measurement == \"Gesamtleistung\")
            |> filter(fn: (r) => r._field == \"Produktion\")
            |> keep(columns: [\"_value\"])
            |> last()") >/dev/null 2>&1
  var="${var##*,}"
  ;;
# Kumulierte Solarproduktion
energy)
  var=$(curl --request POST "${INFLUX_API}" \
    --header "Authorization: Token ${INFLUX_TOKEN}" \
    --header "Accept: application/json" \
    --header "Content-type: application/vnd.flux" \
    --data "from(bucket: \"$INFLUX_BUCKET\")
            |> range(start: $QUERY_RANGE_START)
            |> filter(fn: (r) => r._measurement == \"aggregated\")
            |> filter(fn: (r) => r._field == \"Produktion\")
            |> keep(columns: [\"_value\"])
            |> last()") >/dev/null 2>&1
  var="${var##*,}"
  ;;
# Aktuelle Produktion der Phasen 1 bis 3
phase)
  if [ -z "$2" ]; then
    echo >&2 "The phase number must be passed as an argument"
    exit 1
  else
    case $2 in
    1)
      var=$(curl --request POST "${INFLUX_API}" \
        --header "Authorization: Token ${INFLUX_TOKEN}" \
        --header "Accept: application/json" \
        --header "Content-type: application/vnd.flux" \
        --data "from(bucket: \"$INFLUX_BUCKET\")
               |> range(start: $QUERY_RANGE_START)
               |> filter(fn: (r) => r._measurement == \"phasePowerAc\")
               |> filter(fn: (r) => r._field == \"Phase1\")
               |> keep(columns: [\"_value\"])
               |> last()") >/dev/null 2>&1
      ;;
    2)
      var=$(curl --request POST "${INFLUX_API}" \
        --header "Authorization: Token ${INFLUX_TOKEN}" \
        --header "Accept: application/json" \
        --header "Content-type: application/vnd.flux" \
        --data "from(bucket: \"$INFLUX_BUCKET\")
               |> range(start: $QUERY_RANGE_START)
               |> filter(fn: (r) => r._measurement == \"phasePowerAc\")
               |> filter(fn: (r) => r._field == \"Phase2\")
               |> keep(columns: [\"_value\"])
               |> last()") >/dev/null 2>&1
      ;;
    3)
      var=$(curl --request POST "${INFLUX_API}" \
        --header "Authorization: Token ${INFLUX_TOKEN}" \
        --header "Accept: application/json" \
        --header "Content-type: application/vnd.flux" \
        --data "from(bucket: \"$INFLUX_BUCKET\")
               |> range(start: $QUERY_RANGE_START)
               |> filter(fn: (r) => r._measurement == \"phasePowerAc\")
               |> filter(fn: (r) => r._field == \"Phase3\")
               |> keep(columns: [\"_value\"])
               |> last()") >/dev/null 2>&1
      ;;
    *)
      echo >&2 "The phase number is invalid"
      exit 1
      ;;
    esac
    var="${var##*,}"
  fi
  ;;
# Wechselstromleistung
ac)
  var=$(curl --request POST "${INFLUX_API}" \
    --header "Authorization: Token ${INFLUX_TOKEN}" \
    --header "Accept: application/json" \
    --header "Content-type: application/vnd.flux" \
    --data "from(bucket: \"$INFLUX_BUCKET\")
           |> range(start: $QUERY_RANGE_START)
           |> filter(fn: (r) => r._measurement == \"phasePowerAc\")
           |> filter(fn: (r) => r._field == \"Total\")
           |> keep(columns: [\"_value\"])
           |> last()") >/dev/null 2>&1
  var="${var##*,}"
  ;;
# Batterieleistung
# Die maximale Ladeleistung ist auf 5000W begrenzt, die maximale Entladeleistung auf -5000W. Dieser Wert kann/muss je nach Speicher angepasst werden.
battery)
  pv=$(enpal pv)
  ac=$(enpal ac)
  # shellcheck disable=SC2004
  battery=$(($ac - $pv))
  if [ "$ac" -lt "$pv" ]; then
    echo 0
    exit 0
  elif [ $battery -lt -5000 ]; then
    echo -5000
    exit 0
  elif [ $battery -gt 5000 ]; then
    echo 5000
    exit 0
  fi
  echo $battery
  exit 0
  ;;
# Ladezustand der Batterie (bisher nur 0%, 50% oder 100% möglich)
# Momentan werden durch Enpal in der InfluxDB noch nicht die nötigen Daten bereitgestellt um den genauen Ladezustand bestimmen zu können.
# Ist die Batterieleistung gleich 0 und die Solarproduktion größer als 0 kann davon ausgegangen werden, dass die Batterie zu 100% geladen ist. Beträgt
# die Batterieleistung jedoch 0 und die Solarproduktion ebenso 0, ist die Batterie vollständig entladen. Alles dazwischen erhält aktuell den Wert 50%.
soc)
  pv=$(enpal pv)
  battery=$(enpal battery)
  if [ "$battery" -eq 0 ] && [ "$pv" -gt 0 ]; then
    echo 100
  elif [ "$battery" -eq 0 ]; then
    echo 0
  else
    echo 50
  fi
  exit 0
  ;;
# Kleine Gedankenstütze für die Konsole ;)
help)
  echo consumption
  echo grid
  echo pv
  echo energy
  echo phase \[1-3\]
  echo ac
  echo battery
  echo soc
  exit 0
  ;;
*)
  echo >&2 "The argument for the desired meter value is missing or invalid"
  exit 1
  ;;
esac

# Filtern
var=$(echo "$var" | xargs)

# Konvertierung zu Ganzzahl
var="${var%.*}"
echo $((var))
