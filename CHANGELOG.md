# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2025-08-30

### Changed
- **Bug**: filter double Bouncers 

## [1.1.0] - 2025-08-23

### 🚀 Major Release - Project Rename & Enhanced Monitoring

### Changed
- **BREAKING**: Project renamed from `crowdsec_monitoring` to `crowdsec-checkmk-check`
- **BREAKING**: Script renamed from `crowdsec_monitoring` to `crowdsec.sh`
- Enhanced GitHub repository structure with documentation

### Added
- **NEW SERVICE**: `CrowdSec_Scenarios` - Monitor attack types and patterns
  - HTTP attacks tracking (bad-user-agent, probing, CVE exploits)
  - Mail attacks tracking (HELO rejections, spam attempts)
  - Manual bans tracking (cscli, network bans)
- **NEW SERVICE**: `CrowdSec_Performance` - Monitor ipset performance
  - ipset count monitoring (threat feed integration)
  - Blocked IP entries count (total protected IPs)
- Enhanced error handling for missing dependencies (jq, ipset)
- Improved JSON parsing with fallback mechanisms
- Extended performance metrics collection

### Enhanced
- **Scenario Intelligence**: Detailed attack pattern analysis
- **Performance Monitoring**: ipset-based blocking efficiency
- **Threat Categorization**: HTTP vs Mail vs Manual interventions
- **Robustness**: Better handling of missing tools and empty datasets

### Technical Improvements
- Added `get_scenario_stats()` function for attack pattern analysis
- Added `get_ipset_stats()` function for performance monitoring  
- Enhanced JSON parsing with error handling
- Improved service naming consistency
- Better performance data collection

### Monitoring Capabilities
- **Total Services**: Up to 15+ services (Bouncers + Machines + Overview + Scenarios + Performance)
- **Attack Pattern Recognition**: Real-time scenario-based threat analysis
- **Performance Metrics**: ipset efficiency and blocking statistics
- **Comprehensive Coverage**: From individual bouncer health to global threat landscape

### Migration Guide
```bash
# Update from v1.0.x
wget https://raw.githubusercontent.com/somnium78/crowdsec-checkmk-check/v1.1.0/crowdsec.sh
sudo cp crowdsec.sh /usr/lib/check_mk_agent/local/
sudo chmod +x /usr/lib/check_mk_agent/local/crowdsec.sh
sudo rm /usr/lib/check_mk_agent/local/crowdsec_monitoring*  # Remove old script
```

## [1.0.1] - 2025-08-23

### Fixed
- **CRITICAL**: Added missing `<<<local>>>` header for CheckMK Local Plugin compatibility
- Plugin now correctly appears in CheckMK Service Discovery under "Local checks"
- Fixed CheckMK Agent output format for proper service recognition

### Changed
- Improved CheckMK Local Plugin format compliance
- Enhanced service detection reliability in CheckMK Web Interface

### Technical Details
- Added `echo '<<<local>>>'` header as first output line
- Maintains all existing functionality and GPL v3 license header
- No breaking changes to existing installations


## [1.0.0] - 2025-08-23

### Added
- Initial release of CrowdSec CheckMK monitoring plugin
- Bouncer monitoring with API pull status tracking
- Machine monitoring with heartbeat status tracking
- Decision statistics (active IP bans)
- Configurable warning and critical thresholds (300s/900s)
- Automatic cscli path detection
- Unicode table parsing support
- ISO 8601 timestamp parsing
- Relative time parsing (seconds, minutes)
- Service name sanitization for CheckMK compatibility

### Features
- Monitor 7 bouncer instances across multiple networks
- Track 4 CrowdSec agent machines
- Real-time decision count monitoring
- Multi-architecture support (Debian, Ubuntu, FreeBSD)
- Centralized LAPI server monitoring

### Technical Details
- Bash script compatible with CheckMK local plugins
- Supports CrowdSec v1.6.11+ and bouncer v0.0.32+
- Tested on Debian/Ubuntu systems
- GPL v3 licensed
