#!/bin/bash
# CheckMK Local Plugin für CrowdSec Monitoring
# Automatische Pfad-Erkennung

# Konfiguration
WARN_THRESHOLD=300    # 5 Minuten
CRIT_THRESHOLD=900    # 15 Minuten
CURRENT_TIME=$(date +%s)

# cscli-Pfad automatisch finden
CSCLI_PATH=""
for path in /usr/bin/cscli /usr/local/bin/cscli /bin/cscli /opt/crowdsec/bin/cscli; do
    if [ -x "$path" ]; then
        CSCLI_PATH="$path"
        break
    fi
done

if [ -z "$CSCLI_PATH" ]; then
    echo "CRIT CrowdSec_Error - cscli not found in standard paths"
    exit 1
fi

# Debug-Ausgabe (kann später entfernt werden)
# echo "# DEBUG: Using cscli at: $CSCLI_PATH" >&2

# Funktion: Zeitdifferenz berechnen (ISO 8601 Format)
time_diff() {
    local api_time="$1"

    # ISO Format mit Timezone (2025-08-23T01:29:23+02:00)
    local api_timestamp=$(date -d "$api_time" +%s 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo $((CURRENT_TIME - api_timestamp))
    else
        echo 999999  # Fehler bei Zeitkonvertierung
    fi
}

# Bouncer-Status prüfen
echo "<<<crowdsec_bouncers>>>"

# Text-Parsing (robuster als JSON)
$CSCLI_PATH bouncers list 2>/dev/null | tail -n +3 | while IFS= read -r line; do
    # Leere Zeilen überspringen
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]]; then
        continue
    fi

    # Zeile parsen (Name, IP, Valid, Last API pull, Type, Version)
    name=$(echo "$line" | awk '{print $1}')
    ip=$(echo "$line" | awk '{print $2}')
    valid=$(echo "$line" | awk '{print $3}')

    # Last API pull kann mehrere Felder umfassen (Datum + Zeit)
    last_pull=$(echo "$line" | awk '{print $4" "$5}')
    type=$(echo "$line" | awk '{print $6}')
    version=$(echo "$line" | awk '{$1=$2=$3=$4=$5=$6=""; print $0}' | sed 's/^[[:space:]]*//')

    # Status bestimmen
    if [ "$valid" = "✔️" ]; then
        if [ -z "$last_pull" ] || [ "$last_pull" = "  " ]; then
            status="CRIT"
            message="Never connected"
            diff_seconds=999999
        else
            diff_seconds=$(time_diff "$last_pull")
            if [ $diff_seconds -gt $CRIT_THRESHOLD ]; then
                status="CRIT"
                message="Last pull ${diff_seconds}s ago"
            elif [ $diff_seconds -gt $WARN_THRESHOLD ]; then
                status="WARN"
                message="Last pull ${diff_seconds}s ago"
            else
                status="OK"
                message="Last pull ${diff_seconds}s ago"
            fi
        fi
    else
        status="CRIT"
        message="Invalid bouncer"
        diff_seconds=999999
    fi

    # Service-Name bereinigen (Sonderzeichen entfernen)
    clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9._-]/_/g')

    echo "$status CrowdSec_Bouncer_${clean_name} last_pull=${diff_seconds} $message | IP: $ip, Type: $type"
done

# Machines-Status prüfen
echo "<<<crowdsec_machines>>>"

$CSCLI_PATH machines list 2>/dev/null | tail -n +3 | while IFS= read -r line; do
    # Leere Zeilen überspringen
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]]; then
        continue
    fi

    # Zeile parsen
    name=$(echo "$line" | awk '{print $1}')
    ip=$(echo "$line" | awk '{print $2}')
    last_update=$(echo "$line" | awk '{print $3" "$4}')
    status_symbol=$(echo "$line" | awk '{print $5}')
    version=$(echo "$line" | awk '{print $6}')
    os=$(echo "$line" | awk '{$1=$2=$3=$4=$5=$6=$7=$8=""; print $0}' | sed 's/^[[:space:]]*//')
    last_heartbeat=$(echo "$line" | awk '{print $NF}')

    # Status bestimmen
    if [ "$status_symbol" = "✔️" ]; then
        # Heartbeat-Zeit parsen
        if [[ "$last_heartbeat" =~ ^[0-9]+s$ ]]; then
            seconds=${last_heartbeat%s}
        elif [[ "$last_heartbeat" =~ ^[0-9]+m[0-9]+s$ ]]; then
            minutes=$(echo "$last_heartbeat" | sed 's/m.*//; s/[^0-9]//g')
            secs=$(echo "$last_heartbeat" | sed 's/.*m//; s/s//')
            seconds=$((minutes * 60 + secs))
        elif [[ "$last_heartbeat" =~ h.*m.*s ]] || [[ "$last_heartbeat" =~ ^[0-9]+h$ ]]; then
            seconds=999999  # Stunden = kritisch
        elif [ "$last_heartbeat" = "-" ]; then
            seconds=999999  # Kein Heartbeat
        else
            seconds=999999  # Unbekanntes Format
        fi

        if [ $seconds -gt $CRIT_THRESHOLD ]; then
            status="CRIT"
            message="Heartbeat ${last_heartbeat} ago"
        elif [ $seconds -gt $WARN_THRESHOLD ]; then
            status="WARN"
            message="Heartbeat ${last_heartbeat} ago"
        else
            status="OK"
            message="Heartbeat ${last_heartbeat} ago"
        fi
    else
        status="CRIT"
        message="Not validated"
        seconds=999999
    fi

    # Service-Name bereinigen
    clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9._-]/_/g')

    echo "$status CrowdSec_Machine_${clean_name} heartbeat_seconds=${seconds} $message | IP: $ip, OS: $os"
done

# Statistiken
echo "<<<crowdsec_stats>>>"

# Decisions zählen (Zeilen - Header)
DECISIONS_OUTPUT=$($CSCLI_PATH decisions list 2>/dev/null)
if [ $? -eq 0 ]; then
    ACTIVE_DECISIONS=$(echo "$DECISIONS_OUTPUT" | tail -n +3 | grep -v "^[[:space:]]*$" | wc -l)
else
    ACTIVE_DECISIONS=0
fi

# Bouncers zählen (✔️ Symbol)
BOUNCERS_OUTPUT=$($CSCLI_PATH bouncers list 2>/dev/null)
if [ $? -eq 0 ]; then
    ACTIVE_BOUNCERS=$(echo "$BOUNCERS_OUTPUT" | grep -c "✔️")
else
    ACTIVE_BOUNCERS=0
fi

# Machines zählen (✔️ Symbol)
MACHINES_OUTPUT=$($CSCLI_PATH machines list 2>/dev/null)
if [ $? -eq 0 ]; then
    ACTIVE_MACHINES=$(echo "$MACHINES_OUTPUT" | grep -c "✔️")
else
    ACTIVE_MACHINES=0
fi

echo "OK CrowdSec_Overview active_decisions=${ACTIVE_DECISIONS};active_bouncers=${ACTIVE_BOUNCERS};active_machines=${ACTIVE_MACHINES} Active: ${ACTIVE_DECISIONS} decisions, ${ACTIVE_BOUNCERS} bouncers, ${ACTIVE_MACHINES} machines"
