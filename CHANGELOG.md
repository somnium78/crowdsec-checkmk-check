# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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