#!/bin/bash
# CheckMK Local Plugin für CrowdSec Monitoring
# Version 1.1.3
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
# GitHub: https://github.com/somnium78/crowdsec-checkmk-check

# CheckMK Local Plugin Header
echo '<<<local>>>'

# Konfiguration
WARN_THRESHOLD=21600   # 5 Minuten
CRIT_THRESHOLD=43200   # 15 Minuten
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
    echo "2 CrowdSec_Error - cscli not found"
    exit 0
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

# Funktion: Scenario-Statistiken sammeln
get_scenario_stats() {
    local json_output=$($CSCLI_PATH decisions list -o json 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$json_output" ]; then
        echo "http_attacks=0|mail_attacks=0|manual_bans=0"
        return
    fi

    local scenarios=$(echo "$json_output" | jq -r '.[].decisions[].scenario' 2>/dev/null | sort | uniq -c | sort -nr)

    # HTTP-Angriffe zählen
    local http_attacks=$(echo "$scenarios" | grep -E "(http-|CVE-)" | awk '{sum+=$1} END {print sum+0}')

    # Mail-Angriffe zählen
    local mail_attacks=$(echo "$scenarios" | grep "postfix" | awk '{sum+=$1} END {print sum+0}')

    # Manuelle Bans zählen
    local manual_bans=$(echo "$scenarios" | grep -E "(manual|cscli)" | awk '{sum+=$1} END {print sum+0}')

    echo "http_attacks=${http_attacks}|mail_attacks=${mail_attacks}|manual_bans=${manual_bans}"
}

# Funktion: ipset-Statistiken sammeln
get_ipset_stats() {
    if ! command -v ipset >/dev/null 2>&1; then
        echo "ipset_count=0|ipset_entries=0"
        return
    fi

    local ipset_count=$(ipset list 2>/dev/null | grep -c crowdsec || echo "0")
    local ipset_entries=0

    for set in $(ipset list 2>/dev/null | grep crowdsec | cut -d: -f1); do
        local entries=$(ipset list "$set" 2>/dev/null | grep -c '^[0-9]' || echo "0")
        ipset_entries=$((ipset_entries + entries))
    done

    echo "ipset_count=${ipset_count}|ipset_entries=${ipset_entries}"
}

# Bouncer-Status prüfen
$CSCLI_PATH bouncers list 2>/dev/null | while IFS= read -r line; do
    # Header-Zeile und Unicode-Trennlinien überspringen
    if [[ "$line" =~ ^[[:space:]]*Name || "$line" =~ ^[─-]+$ || -z "$line" ]]; then
        continue
    fi

    # Datenzeilen verarbeiten (enthalten IP-Adressen und ✔️)
    if [[ "$line" =~ ✔️ ]] && [[ "$line" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        # Felder mit awk extrahieren
        name=$(echo "$line" | awk '{print $1}')
        # Auto-Created Bouncer mit IP-Pattern überspringen
        if [[ "$name" =~ _[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$name" =~ @[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            continue
        fi
        ip=$(echo "$line" | awk '{print $2}')
        valid=$(echo "$line" | awk '{print $3}')
        timestamp=$(echo "$line" | awk '{print $4}')
        type=$(echo "$line" | awk '{print $5}')

        # Zeit-Differenz berechnen
        diff_seconds=$(parse_iso_time "$timestamp")

        # Status bestimmen (CheckMK Format: 0=OK, 1=WARN, 2=CRIT)
        if [ "$valid" = "✔️" ]; then
            if [ $diff_seconds -gt $CRIT_THRESHOLD ]; then
                status="2"
                message="CRIT - Last pull ${diff_seconds}s ago"
            elif [ $diff_seconds -gt $WARN_THRESHOLD ]; then
                status="1"
                message="WARN - Last pull ${diff_seconds}s ago"
            else
                status="0"
                message="OK - Last pull ${diff_seconds}s ago"
            fi
        else
            status="2"
            message="CRIT - Invalid bouncer"
            diff_seconds=999999
        fi

        # Service-Name bereinigen
        clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9._-]/_/g')

        # CheckMK Local Check Format
        echo "$status CrowdSec_Bouncer_${clean_name} last_pull=${diff_seconds};${WARN_THRESHOLD};${CRIT_THRESHOLD} $message | IP: $ip, Type: $type"
    fi
done

# Machines-Status prüfen
$CSCLI_PATH machines list 2>/dev/null | while IFS= read -r line; do
    # Header-Zeile und Unicode-Trennlinien überspringen
    if [[ "$line" =~ ^[[:space:]]*Name || "$line" =~ ^[─-]+$ || -z "$line" ]]; then
        continue
    fi

    # Datenzeilen verarbeiten (enthalten IP-Adressen und ✔️)
    if [[ "$line" =~ ✔️ ]] && [[ "$line" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        # Felder extrahieren (Heartbeat ist das letzte Feld)
        name=$(echo "$line" | awk '{print $1}')
        # Auto-Created Bouncer mit IP-Pattern überspringen
        if [[ "$name" =~ _[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$name" =~ @[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            continue
        fi
        ip=$(echo "$line" | awk '{print $2}')
        status_symbol=$(echo "$line" | awk '{print $4}')
        os=$(echo "$line" | awk '{print $6}')
        heartbeat=$(echo "$line" | awk '{print $NF}')

        # Heartbeat in Sekunden umwandeln
        seconds=$(parse_relative_time "$heartbeat")

        # Status bestimmen
        if [ "$status_symbol" = "✔️" ]; then
            if [ $seconds -gt $CRIT_THRESHOLD ]; then
                status="2"
                message="CRIT - Heartbeat ${heartbeat} ago"
            elif [ $seconds -gt $WARN_THRESHOLD ]; then
                status="1"
                message="WARN - Heartbeat ${heartbeat} ago"
            else
                status="0"
                message="OK - Heartbeat ${heartbeat} ago"
            fi
        else
            status="2"
            message="CRIT - Not validated"
            seconds=999999
        fi

        # Service-Name bereinigen
        clean_name=$(echo "$name" | sed 's/[^a-zA-Z0-9._-]/_/g')

        echo "$status CrowdSec_Machine_${clean_name} heartbeat_seconds=${seconds};${WARN_THRESHOLD};${CRIT_THRESHOLD} $message | IP: $ip, OS: $os"
    fi
done

# Statistiken sammeln
DECISIONS_COUNT=$($CSCLI_PATH decisions list 2>/dev/null | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | grep -v "^[[:space:]]*IP" | wc -l)
BOUNCERS_COUNT=$($CSCLI_PATH bouncers list 2>/dev/null | grep -c "✔️")
MACHINES_COUNT=$($CSCLI_PATH machines list 2>/dev/null | grep -c "✔️")


SCENARIO_STATS=$(get_scenario_stats)
IPSET_STATS=$(get_ipset_stats)

# Overview-Service mit erweiterten Metriken
echo "0 CrowdSec_Overview active_decisions=${DECISIONS_COUNT}|active_bouncers=${BOUNCERS_COUNT}|active_machines=${MACHINES_COUNT}|${SCENARIO_STATS}|${IPSET_STATS} OK - Active: ${DECISIONS_COUNT} decisions, ${BOUNCERS_COUNT} bouncers, ${MACHINES_COUNT} machines"

if [ "$DECISIONS_COUNT" -gt 0 ]; then
    HTTP_ATTACKS=$(echo "$SCENARIO_STATS" | grep -o 'http_attacks=[0-9]*' | cut -d= -f2)
    MAIL_ATTACKS=$(echo "$SCENARIO_STATS" | grep -o 'mail_attacks=[0-9]*' | cut -d= -f2)
    MANUAL_BANS=$(echo "$SCENARIO_STATS" | grep -o 'manual_bans=[0-9]*' | cut -d= -f2)

    echo "0 CrowdSec_Scenarios ${SCENARIO_STATS} OK - HTTP attacks: ${HTTP_ATTACKS}, Mail attacks: ${MAIL_ATTACKS}, Manual bans: ${MANUAL_BANS}"
fi


IPSET_COUNT=$(echo "$IPSET_STATS" | grep -o 'ipset_count=[0-9]*' | cut -d= -f2)
IPSET_ENTRIES=$(echo "$IPSET_STATS" | grep -o 'ipset_entries=[0-9]*' | cut -d= -f2)

if [ "$IPSET_COUNT" -gt 0 ]; then
    echo "0 CrowdSec_Performance ${IPSET_STATS} OK - ipsets: ${IPSET_COUNT}, blocked IPs: ${IPSET_ENTRIES}"
fi
