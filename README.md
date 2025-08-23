# CrowdSec Monitoring Plugin for CheckMK

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Version](https://img.shields.io/github/v/release/somnium78/crowdsec-checkmk-check)](https://github.com/somnium78/crowdsec-checkmk-check/releases)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)](https://github.com/somnium78/crowdsec-checkmk-check)

A CheckMK local plugin to monitor CrowdSec LAPI server status, including bouncer connectivity, machine heartbeats, and active decisions.

## 🚀 Features
### Core Monitoring
- **Bouncer Monitoring**: Track API pull status and connectivity of all registered bouncers
- **Machine Monitoring**: Monitor heartbeat status of CrowdSec agents
- **Decision Statistics**: Count active decisions and blocked IPs
- **Alerting**: Configurable warning and critical thresholds
- **Multi-Architecture**: Supports centralized CrowdSec deployments

### Advanced Analytics (v1.1.0+)
- **Attack Pattern Recognition**: HTTP vs Mail vs Manual threat categorization
- **Performance Monitoring**: ipset efficiency and blocking statistics
- **Scenario Intelligence**: Detailed attack type analysis
- **Threat Landscape**: Comprehensive security posture overview

## 📊 Monitored Services

| Service Type | Count | Description |
|--------------|-------|-------------|
| **Bouncers** | 1-20+ | API pull status, connectivity health |
| **Machines** | 1-10+ | Heartbeat status, validation state |
| **Overview** | 1 | Global statistics and health summary |
| **Scenarios** | 1 | Attack pattern analysis (v1.1.0+) |
| **Performance** | 1 | ipset and blocking efficiency (v1.1.0+) |

## 🔧 Quick Install

```bash
# Download latest version
wget https://raw.githubusercontent.com/somnium78/crowdsec-checkmk-check/v1.1.0/crowdsec.sh

# Install plugin
sudo cp crowdsec.sh /usr/lib/check_mk_agent/local/
sudo chmod +x /usr/lib/check_mk_agent/local/crowdsec.sh
sudo chown root:root /usr/lib/check_mk_agent/local/crowdsec.sh

# Test plugin
sudo /usr/lib/check_mk_agent/local/crowdsec.sh

# Expected output should start with:
# <<<local>>>
# 0 CrowdSec_Bouncer_[name] last_pull=X;300;900 OK - Last pull Xs ago | ...

# Restart CheckMK Agent
sudo systemctl restart check-mk-agent
```
# 📈 Performance Metrics
## Bouncer Metrics
    last_pull: Seconds since last API pull (WARN: >300s, CRIT: >900s)
    Connection health: API connectivity status
    Type information: Bouncer variant and version

# Machine Metrics
    heartbeat_seconds: Seconds since last heartbeat (WARN: >300s, CRIT: >900s)
    Validation status: Agent authentication state
    OS information: Platform and version details

# Scenario Metrics (v1.1.0+)
    http_attacks: HTTP-based attack attempts
    mail_attacks: SMTP/Mail-based attack attempts
    manual_bans: Administrative interventions

# Performance Metrics (v1.1.0+)
    ipset_count: Number of active ipset tables
    ipset_entries: Total blocked IP addresses

# 🛠️ Requirements
## System Requirements
- OS: Linux (Debian, Ubuntu, CentOS, RHEL)
- CrowdSec: v1.4.0+ (tested with v1.6.11)
- CheckMK Agent: Any recent version
- Shell: bash 4.0+

## Dependencies
- Required: cscli, date, awk, grep, sed
- Optional: jq (enhanced JSON parsing), ipset (performance metrics)

## Permissions
- cscli access: Plugin runs as root via CheckMK Agent
- Network access: LAPI server connectivity required


# 📋 Configuration
## Default Thresholds
```Bash
WARN_THRESHOLD=300    # 5 minutes
CRIT_THRESHOLD=900    # 15 minutes
```

## Custom Configuration
```Bash
# Edit plugin for custom thresholds
sudo nano /usr/lib/check_mk_agent/local/crowdsec.sh

# Modify these values:
WARN_THRESHOLD=600    # 10 minutes
CRIT_THRESHOLD=1800   # 30 minutes
```

# 🔍 CheckMK Integration
## Service Discovery
    Setup → Hosts → [Host]
    Services → Service Discovery
    Full Scan → Refresh
    Add discovered CrowdSec services

## Expected Services
    CrowdSec Bouncer [name] - Individual bouncer monitoring
    CrowdSec Machine [name] - Individual machine monitoring
    CrowdSec Overview - Global statistics
    CrowdSec Scenarios - Attack pattern analysis (v1.1.0+)
    CrowdSec Performance - Blocking efficiency (v1.1.0+)

# 🚨 Alerting Examples
## Bouncer Alerts
```
WARN - CrowdSec Bouncer mx1-firewall: Last pull 420s ago
CRIT - CrowdSec Bouncer opnsense: Last pull 1200s ago  
```

## Machine Alerts
```
WARN - CrowdSec Machine ns2.risse.cloud: Heartbeat 8m ago
CRIT - CrowdSec Machine mx1.risse.cloud: Not validated
```

## Scenario Alerts (v1.1.0+)
```
OK - HTTP attacks: 24, Mail attacks: 10, Manual bans: 2
```


# Architecture Support

This plugin is designed for centralized CrowdSec deployments:

    LAPI Server: Central server running CrowdSec Local API (where this plugin runs)
    Agents: Remote machines analyzing logs and sending decisions to LAPI
    Bouncers: Firewall/proxy systems pulling decisions from LAPI


# 🔧 Troubleshooting
## Plugin not working

1. Check cscli availability:
```bash
which cscli
cscli bouncers list
```

2. Test plugin manually:
```bash
sudo /usr/lib/check_mk_agent/local/crowdsec.sh
```

3. Check CheckMK agent logs:
```bash
sudo journalctl -u check-mk-agent
```

## No services discovered

1. Restart CheckMK agent:
```bash
sudo systemctl restart check-mk-agent
```
2. Force service discovery in CheckMK web interface

3. Check plugin permissions:
```bash
ls -la /usr/lib/check_mk_agent/local/crowdsec.sh
```

## Incorrect timestamps

- Ensure system time is synchronized (NTP)
- Check timezone configuration
- Verify CrowdSec is running and accessible

# 📊 Real-World Example
## Production Environment
```
Infrastructure: 4 servers, 7 bouncers, 64 active decisions
Threat Landscape: 24 HTTP attacks, 10 mail attacks, 2 manual bans
Performance: 7 ipsets, 23,000+ blocked IPs
Monitoring: 15 CheckMK services, 5-minute intervals
```
## CheckMK Dashboard
```
✅ CrowdSec Overview: 64 decisions, 7 bouncers, 4 machines  
✅ CrowdSec Scenarios: HTTP: 24, Mail: 10, Manual: 2
✅ CrowdSec Performance: 7 ipsets, 23,000 IPs blocked
✅ All bouncers: API pulls &lt; 30s
✅ All machines: Heartbeats &lt; 60s
```

# 🤝 Contributing

1. Fork the repository
2. Create a feature branch (git checkout -b feature/amazing-feature)
3. Commit your changes (git commit -m 'Add amazing feature')
4. Push to the branch (git push origin feature/amazing-feature)
5. Open a Pull Request

# 📞 Support

- Issues: GitHub Issues
- Discussions: GitHub Discussions
- Documentation: Wiki

# 📄 License

This project is licensed under the GNU General Public License v3.0 - see the LICENSE file for details.

### GPL v3 Summary

- ✅ **Freedom to use** - Use the software for any purpose
- ✅ **Freedom to study** - Examine and modify the source code  
- ✅ **Freedom to share** - Redistribute copies
- ✅ **Freedom to improve** - Distribute modified versions
- ⚠️ **Copyleft** - Derivative works must also be GPL v3 licensed
- ⚠️ **Source disclosure** - Modified versions must include source code

For commercial use or integration into proprietary software, please contact the maintainer.

# 🏆 Acknowledgments

- CrowdSec Team: For the excellent security platform
- CheckMK Community: For monitoring infrastructure
- Contributors: All community contributors and testers
