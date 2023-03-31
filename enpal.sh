#!/bin/sh

# Zugangsdaten InfluxDB
# @ see https://github.com/weldan84/enpal-influx-evcc
INFLUX_HOST="YOUR_INFLUX_HOST"
INFLUX_ORG_ID="YOUR_INFLUX_ORG_ID"
INFLUX_BUCKET="YOUR_INFLUX_BUCKET"
INFLUX_TOKEN="YOUR_INFLUX_TOKEN"
INFLUX_API="${INFLUX_HOST}/api/v2/query?orgID=${INFLUX_ORG_ID}"
QUERY_RANGE_START="-5m"

# Zugangsdaten Powerfox Poweropti
# @see https://www.powerfox.energy/daten-von-powerfox-per-api-nutzen/
POWERFOX_USERNAME="POWERFOX_USERNAME"
POWERFOX_PASSWORD="POWERFOX_PASSWORD"
POWERFOX_DEVICE_ID="POWERFOX_DEVICE_ID"

case $1 in
# Gesamtverbrauch
consumption)
  var=$(curl -f -s "${INFLUX_API}" \
    --header "Authorization: Token ${INFLUX_TOKEN}" \
    --header "Accept: application/json" \
    --header "Content-type: application/vnd.flux" \
    --data "from(bucket: \"$INFLUX_BUCKET\")
            |> range(start: $QUERY_RANGE_START)
            |> filter(fn: (r) => r._measurement == \"Gesamtleistung\")
            |> filter(fn: (r) => r._field == \"Verbrauch\")
            |> keep(columns: [\"_value\"])
            |> last()")
  status="$?"
  var="${var##*,}"
  ;;
# Netzbezug/Einspeisung Enpal InfluxDB (Errechneter Wert)
grid_enpal)
  pv=$(enpal pv)
  consumption=$(enpal consumption)
  battery=$(enpal battery)
  # shellcheck disable=SC2004
  echo $(($consumption - $pv - $battery))
  exit 0
  ;;
# Netzbezug/Einspeisung Powerfox Poweropti (Tatsächlicher Wert)
grid_powerfox)
  # Um das API-Aufrufkontingent nicht zu überschreiten wird hier 3 Sekunden lang pausiert! (Maximal zugelassen 1 pro 3s)
  sleep 3
  var=$(curl -f -s -G "https://backend.powerfox.energy/api/2.0/my/$POWERFOX_DEVICE_ID/current" \
    -u "$POWERFOX_USERNAME:$POWERFOX_PASSWORD")
  status="$?"
  var=$(echo "$var" | jq '.Watt // empty')
  if [ "$var" = "empty" ]; then
    echo >&2 "Der Poweropti liefert keine aktuellen Werte. Hier wird dir geholfen https://poweropti.powerfox.energy/faq/"
    exit 1
  fi
  echo "$var"
  exit "$status"
  ;;
# Aktuelle Solarproduktion / DC-Erzeugungsleistung
pv)
  var=$(curl -f -s "${INFLUX_API}" \
    --header "Authorization: Token ${INFLUX_TOKEN}" \
    --header "Accept: application/json" \
    --header "Content-type: application/vnd.flux" \
    --data "from(bucket: \"$INFLUX_BUCKET\")
            |> range(start: $QUERY_RANGE_START)
            |> filter(fn: (r) => r._measurement == \"LeistungDc\")
            |> filter(fn: (r) => r._field == \"Total\")
            |> keep(columns: [\"_value\"])
            |> last()")
  status="$?"
  var="${var##*,}"
  ;;
# Kumulierte Solarproduktion / DC-Erzeugungsleistung
energy)
  var=$(curl -f -s "${INFLUX_API}" \
    --header "Authorization: Token ${INFLUX_TOKEN}" \
    --header "Accept: application/json" \
    --header "Content-type: application/vnd.flux" \
    --data "from(bucket: \"$INFLUX_BUCKET\")
            |> range(start: $QUERY_RANGE_START)
            |> filter(fn: (r) => r._measurement == \"aggregated\")
            |> filter(fn: (r) => r._field == \"Produktion\")
            |> keep(columns: [\"_value\"])
            |> last()")
  status="$?"
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
      var=$(curl -f -s "${INFLUX_API}" \
        --header "Authorization: Token ${INFLUX_TOKEN}" \
        --header "Accept: application/json" \
        --header "Content-type: application/vnd.flux" \
        --data "from(bucket: \"$INFLUX_BUCKET\")
               |> range(start: $QUERY_RANGE_START)
               |> filter(fn: (r) => r._measurement == \"phasePowerAc\")
               |> filter(fn: (r) => r._field == \"Phase1\")
               |> keep(columns: [\"_value\"])
               |> last()")
      ;;
    2)
      var=$(curl -f -s "${INFLUX_API}" \
        --header "Authorization: Token ${INFLUX_TOKEN}" \
        --header "Accept: application/json" \
        --header "Content-type: application/vnd.flux" \
        --data "from(bucket: \"$INFLUX_BUCKET\")
               |> range(start: $QUERY_RANGE_START)
               |> filter(fn: (r) => r._measurement == \"phasePowerAc\")
               |> filter(fn: (r) => r._field == \"Phase2\")
               |> keep(columns: [\"_value\"])
               |> last()")
      ;;
    3)
      var=$(curl -f -s "${INFLUX_API}" \
        --header "Authorization: Token ${INFLUX_TOKEN}" \
        --header "Accept: application/json" \
        --header "Content-type: application/vnd.flux" \
        --data "from(bucket: \"$INFLUX_BUCKET\")
               |> range(start: $QUERY_RANGE_START)
               |> filter(fn: (r) => r._measurement == \"phasePowerAc\")
               |> filter(fn: (r) => r._field == \"Phase3\")
               |> keep(columns: [\"_value\"])
               |> last()")
      ;;
    *)
      echo >&2 "The phase number is invalid"
      exit 1
      ;;
    esac
    status="$?"
    var="${var##*,}"
  fi
  ;;
# Wechselstromleistung
ac)
  var=$(curl -f -s "${INFLUX_API}" \
    --header "Authorization: Token ${INFLUX_TOKEN}" \
    --header "Accept: application/json" \
    --header "Content-type: application/vnd.flux" \
    --data "from(bucket: \"$INFLUX_BUCKET\")
           |> range(start: $QUERY_RANGE_START)
           |> filter(fn: (r) => r._measurement == \"phasePowerAc\")
           |> filter(fn: (r) => r._field == \"Total\")
           |> keep(columns: [\"_value\"])
           |> last()")
  status="$?"
  var="${var##*,}"
  ;;
# Batterieleistung
# Die maximale Entladeleistung ist auf 5000W begrenzt, die maximale Ladeleistung auf -5000W. Dieser Wert kann/muss je nach Speicher angepasst werden.
battery)
  pv=$(enpal pv)
  ac=$(enpal ac)
  if [ "$POWERFOX_USERNAME" = "POWERFOX_USERNAME" ] || [ "$POWERFOX_PASSWORD" = "POWERFOX_PASSWORD" ]; then
    # Falls Powerfox Poweropti nicht genutzt wird, muss der Ladezustand geschätzt werden
    if [ "$ac" -lt "$pv" ]; then
      echo 0
      exit 0
    else
      battery=$(($ac - $pv))
      if [ "$battery" -lt -5000 ]; then
        echo -5000
        exit 0
      elif [ "$battery" -gt 5000 ]; then
        echo 5000
        exit 0
      fi
    fi
  else
    # Falls Powerfox Poweropti vorhanden ist, kann mit Sicherheit bestimmt werden wie hoch die
    # Batterieleistung ist, indem die Werte für den tatsächlichen Netzbezug mit einberechnet werden.
    grid=$(enpal grid_powerfox)
    if [ "$grid" -gt 0 ] && [ "$ac" -lt "$pv" ]; then
      echo 0
    else
      battery=$(($ac - $pv + $grid))
    fi
  fi

  echo "$battery"
  exit 0
  ;;
# Ladezustand der Batterie (bisher nur 0%, 50% oder 100% möglich)
# Momentan werden durch Enpal in der InfluxDB noch nicht die nötigen Daten bereitgestellt um den genauen Ladezustand bestimmen zu können.
# Ist die Batterieleistung gleich 0 und die DC-Erzeugungsleistung größer als 0 kann davon ausgegangen werden, dass die Batterie zu 100% geladen ist. Beträgt
# die Batterieleistung jedoch 0 und die DC-Erzeugungsleistung ebenso 0, ist die Batterie vollständig entladen. Alles dazwischen erhält aktuell den Wert 50%.
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
  echo grid_enpal
  echo grid_powerfox
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

# Konvertierung
var="${var%.*}"
echo $((var))
exit "$status"
