#!/bin/bash
# CheckMK Local Plugin für CrowdSec Monitoring
# Version 1.0.0
# 
# Copyright (C) 2025 somnium78
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# GitHub: https://github.com/somnium78/crowdsec_monitoring

# Konfiguration
WARN_THRESHOLD=300    # 5 Minuten
CRIT_THRESHOLD=900    # 15 Minuten

CURRENT_TIME=$(date +%s)

# cscli-Pfad finden
CSCLI_PATH=""
for path in /usr/bin/cscli /usr/local/bin/cscli /bin/cscli /opt/crowdsec/bin/cscli; do
    if [ -x "$path" ]; then
        CSCLI_PATH="$path"
        break
    fi
done

if [ -z "$CSCLI_PATH" ]; then
    echo "CRIT CrowdSec_Error - cscli not found"
    exit 1
fi

# Funktion: ISO 8601 Zeit zu Sekunden-Differenz
parse_iso_time() {
    local iso_time="$1"
    local timestamp=$(date -d "$iso_time" +%s 2>/dev/null)
    if [ $? -eq 0 ] && [ $timestamp -gt 0 ]; then
        echo $((CURRENT_TIME - timestamp))
    else
        echo 999999
    fi
}

# Funktion: Relative Zeit zu Sekunden
parse_relative_time() {
    local rel_time="$1"

    if [[ "$rel_time" =~ ^[0-9]+s$ ]]; then
        echo ${rel_time%s}
    elif [[ "$rel_time" =~ ^[0-9]+m[0-9]*s*$ ]]; then
        local minutes=$(echo "$rel_time" | sed 's/m.*//' | grep -o '[0-9]*')
        local seconds=$(echo "$rel_time" | sed 's/.*m//' | sed 's/s//' | grep -o '[0-9]*')
        echo $((${minutes:-0} * 60 + ${seconds:-0}))
    elif [[ "$rel_time" =~ ^[0-9]+h ]]; then
        echo 999999  # Stunden = kritisch
    elif [ "$rel_time" = "-" ]; then
        echo 999999  # Kein Heartbeat
    else
        echo 999999  # Unbekanntes Format
    fi
}

# Bouncer-Status prüfen
echo "<<<crowdsec_bouncers>>>"

$CSCLI_PATH bouncers list 2>/dev/null | while IFS= read -r line; do
    # Header-Zeile und Unicode-Trennlinien überspringen
    if [[ "$line" =~ ^[[:space:]]*Name || "$line" =~ ^[─-]+$ || -z "$line" ]]; then
        continue
    fi

    # Datenzeilen verarbeiten (enthalten IP-Adressen und ✔️)
    if [[ "$line" =~ ✔️ ]] && [[ "$line" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        # Felder mit awk extrahieren
        name=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk '{print $2}')
        valid=$(echo "$line" | awk '{print $3}')
        timestamp=$(echo "$line" | awk '{print $4}')  # ISO-Format ist ein Feld
        type=$(echo "$line" | awk '{print $5}')
        version=$(echo "$line" | awk '{print $6}')

        # Zeit-Differenz berechnen
        diff_seconds=$(parse_iso_time "$timestamp")

        # Status bestimmen
        if [ "$valid" = "✔️" ]; then
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
        else
            status="CRIT"
            message="Invalid bouncer"
            diff_seconds=999999
        fi

        # Service-Name bereinigen (@ und andere Sonderzeichen)
        clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9._-]/_/g')

        echo "$status CrowdSec_Bouncer_${clean_name} last_pull=${diff_seconds} $message | IP: $ip, Type: $type, Version: ${version}"
    fi
done

# Machines-Status prüfen
echo "<<<crowdsec_machines>>>"

$CSCLI_PATH machines list 2>/dev/null | while IFS= read -r line; do
    # Header-Zeile und Unicode-Trennlinien überspringen
    if [[ "$line" =~ ^[[:space:]]*Name || "$line" =~ ^[─-]+$ || -z "$line" ]]; then
        continue
    fi

    # Datenzeilen verarbeiten (enthalten IP-Adressen und ✔️)
    if [[ "$line" =~ ✔️ ]] && [[ "$line" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        # Felder extrahieren (Heartbeat ist das letzte Feld)
        name=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk '{print $2}')
        last_update=$(echo "$line" | awk '{print $3}')
        status_symbol=$(echo "$line" | awk '{print $4}')
        version=$(echo "$line" | awk '{print $5}')
        os=$(echo "$line" | awk '{print $6}')
        auth_type=$(echo "$line" | awk '{print $7}')
        heartbeat=$(echo "$line" | awk '{print $NF}')  # Letztes Feld = Heartbeat

        # Heartbeat in Sekunden umwandeln
        seconds=$(parse_relative_time "$heartbeat")

        # Status bestimmen
        if [ "$status_symbol" = "✔️" ]; then
            if [ $seconds -gt $CRIT_THRESHOLD ]; then
                status="CRIT"
                message="Heartbeat ${heartbeat} ago"
            elif [ $seconds -gt $WARN_THRESHOLD ]; then
                status="WARN"
                message="Heartbeat ${heartbeat} ago"
            else
                status="OK"
                message="Heartbeat ${heartbeat} ago"
            fi
        else
            status="CRIT"
            message="Not validated"
            seconds=999999
        fi

        # Service-Name bereinigen
        clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9._-]/_/g')

        echo "$status CrowdSec_Machine_${clean_name} heartbeat_seconds=${seconds} $message | IP: $ip, OS: $os, Version: $version"
    fi
done

# Statistiken
echo "<<<crowdsec_stats>>>"

# Decisions zählen (nur Datenzeilen mit IP-Adressen)
DECISIONS_COUNT=$($CSCLI_PATH decisions list 2>/dev/null | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | grep -v "^[[:space:]]*IP" | wc -l)

# Bouncers zählen (✔️ Symbol)
BOUNCERS_COUNT=$($CSCLI_PATH bouncers list 2>/dev/null | grep -c "✔️")

# Machines zählen (✔️ Symbol)
MACHINES_COUNT=$($CSCLI_PATH machines list 2>/dev/null | grep -c "✔️")

echo "OK CrowdSec_Overview active_decisions=${DECISIONS_COUNT};active_bouncers=${BOUNCERS_COUNT};active_machines=${MACHINES_COUNT} Active: ${DECISIONS_COUNT} decisions, ${BOUNCERS_COUNT} bouncers, ${MACHINES_COUNT} machines"
