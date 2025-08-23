# CrowdSec Monitoring Plugin for CheckMK

A CheckMK local plugin to monitor CrowdSec LAPI server status, including bouncer connectivity, machine heartbeats, and active decisions.

## Features

- **Bouncer Monitoring**: Track API pull status and connectivity of all registered bouncers
- **Machine Monitoring**: Monitor heartbeat status of CrowdSec agents
- **Decision Statistics**: Count active decisions and blocked IPs
- **Alerting**: Configurable warning and critical thresholds
- **Multi-Architecture**: Supports centralized CrowdSec deployments

## Requirements

- CheckMK Agent installed on CrowdSec LAPI server
- CrowdSec installed and running
- `cscli` command available in system PATH
- Bash shell environment

## Installation

1. **Download the plugin**:
```bash
wget https://raw.githubusercontent.com/somnium78/crowdsec_monitoring/main/crowdsec_monitoring
```

2. Install to CheckMK local plugins directory:
```bash
sudo cp crowdsec_monitoring /usr/lib/check_mk_agent/local/
sudo chmod +x /usr/lib/check_mk_agent/local/crowdsec_monitoring
```

3. Test the plugin:
```bash
sudo /usr/lib/check_mk_agent/local/crowdsec_monitoring
```

4. Restart CheckMK agent:
```bash
sudo systemctl restart check-mk-agent
```

5. Discover services in CheckMK:
   - Go to CheckMK Web Interface
   - Navigate to Setup → Hosts → [Your Host]
   - Run Service Discovery
   - Add the discovered CrowdSec services

# Configuration
## Thresholds

Edit the plugin file to adjust monitoring thresholds:
```bash
# Warning threshold for API pulls (seconds)
WARN_THRESHOLD=300    # 5 minutes

# Critical threshold for API pulls (seconds)  
CRIT_THRESHOLD=900    # 15 minutes
```

## CrowdSec Path

The plugin automatically detects cscli in standard locations:
- /usr/bin/cscli
- /usr/local/bin/cscli
- /bin/cscli
- /opt/crowdsec/bin/cscli


# Monitored Services
## CrowdSec Bouncer Services

    Service Name: CrowdSec Bouncer [bouncer-name]
    Metrics: last_pull (seconds since last API pull)
    States:
    OK: API pull within warning threshold
    WARN: API pull between warning and critical threshold
    CRIT: API pull exceeds critical threshold or bouncer invalid

## CrowdSec Machine Services

    Service Name: CrowdSec Machine [machine-name]
    Metrics: heartbeat_seconds (seconds since last heartbeat)
    States:
    OK: Heartbeat within warning threshold
    WARN: Heartbeat between warning and critical threshold
    CRIT: Heartbeat exceeds critical threshold or machine not validated

## CrowdSec Overview Service

    Service Name: CrowdSec Overview
    Metrics:
    active_decisions: Number of active IP bans
    active_bouncers: Number of valid bouncers
    active_machines: Number of validated machines
    State: Always OK (informational)

# Example Output
```
<<<crowdsec_bouncers>>>
OK CrowdSec_Bouncer_opnsense-firewall last_pull=45 Last pull 45s ago | IP: 10.1.1.1, Type: crowdsec-firewall-bouncer
WARN CrowdSec_Bouncer_old-bouncer last_pull=420 Last pull 420s ago | IP: 10.1.1.5, Type: crowdsec-firewall-bouncer
CRIT CrowdSec_Bouncer_offline-bouncer last_pull=1800 Last pull 1800s ago | IP: 10.1.1.10, Type: crowdsec-firewall-bouncer

<<<crowdsec_machines>>>
OK CrowdSec_Machine_mx1.example.com heartbeat_seconds=28 Heartbeat 28s ago | IP: 10.1.1.199, OS: Ubuntu/24.04
OK CrowdSec_Machine_ns2.example.com heartbeat_seconds=15 Heartbeat 15s ago | IP: 10.1.1.200, OS: Debian GNU/Linux/12

<<<crowdsec_stats>>>
OK CrowdSec_Overview active_decisions=71;active_bouncers=3;active_machines=2 Active: 71 decisions, 3 bouncers, 2 machines
```

# Architecture Support

This plugin is designed for centralized CrowdSec deployments:

    LAPI Server: Central server running CrowdSec Local API (where this plugin runs)
    Agents: Remote machines analyzing logs and sending decisions to LAPI
    Bouncers: Firewall/proxy systems pulling decisions from LAPI

# Troubleshooting
## Plugin not working

1. Check cscli availability:
```bash
which cscli
cscli bouncers list
```

2. Test plugin manually:
```bash
sudo /usr/lib/check_mk_agent/local/crowdsec_monitoring
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
ls -la /usr/lib/check_mk_agent/local/crowdsec_monitoring
```

## Incorrect timestamps

- Ensure system time is synchronized (NTP)
- Check timezone configuration
- Verify CrowdSec is running and accessible

# Contributing

1. Fork the repository
2. Create a feature branch (git checkout -b feature/amazing-feature)
3. Commit your changes (git commit -m 'Add amazing feature')
4. Push to the branch (git push origin feature/amazing-feature)
5. Open a Pull Request

# License

This project is licensed under the MIT License - see the LICENSE file for details.

# Changelog
## v1.0.0

- Initial release
- Bouncer monitoring with API pull tracking
- Machine monitoring with heartbeat tracking
- Decision statistics
- Configurable thresholds
- Automatic cscli path detection

# Support

    Issues: GitHub Issues
    Discussions: GitHub Discussions

# Related Projects

    CrowdSec - The main CrowdSec project
    CheckMK - IT infrastructure monitoring

