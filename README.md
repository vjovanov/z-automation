# Zlatibor Home Automation System

This repository contains a complete Raspberry Pi-based home automation system with:
- Home Assistant integration
- Z-Wave device control
- Heating system automation
- Security/motion alerts
- Remote monitoring capabilities

## System Architecture

### Core Services
- `hass-daemon.sh` - Manages Home Assistant as a systemd service
- `heating-daemon.sh` - Controls dual heating system (gas + electrical)
- `heating.py` - Implements PID control logic with:
  - Temperature hysteresis (0.5°C delta)
  - Time-based electricity tariff optimization
  - Pump control synchronization
- `relay-control.py` - Manages 8-channel relay board via GPIO
- `report-motion.sh` - Sends SMS alerts via MessageBird API when motion detected

### Home Assistant Configuration
- `configuration.yaml` - Main config with:
  - Z-Wave network setup
  - System monitoring sensors
  - Shell command integrations
  - Custom Z-Wave visualization panel
- `automations.yaml` - Key automations including:
  - Motion-triggered security alerts
  - Alarm status reminders
  - Temperature control workflows
- `customize.yaml` - Localized UI customizations (Serbian language)
- Device-specific configurations for:
  - Aeotec ZW100 multisensors
  - Aeotec ZW095 energy meter
  - Dark Sky weather integration

### Installation & Management
- `install-all.sh` - Complete setup including:
  - Required packages (python-rpi.gpio, nmap, etc)
  - Service installations
  - Permission configurations
- `uninstall-all.sh` - Clean removal of all services
- `upgrade-hass.sh` - Home Assistant upgrade procedure

## Usage Guide

### First-Time Setup
```bash
sudo ./install-all.sh
```

### Monitoring Services
```bash
# Check heating system status
sudo systemctl status heating-daemon

# View relay states
cat /home/pi/relays/*

# Check Home Assistant logs
tail -f /home/homeassistant/.homeassistant/home-assistant.log
```

### Security System
Configure motion alerts by editing:
```bash
sudo nano /home/pi/alarm/report-motion.sh
```

Key parameters:
- MessageBird API key
- Recipient phone numbers
- Alert message content

### Heating Control
Manual override options:
```bash
# Set desired temperature (16-25°C)
echo 20 > /home/pi/heating/desired-temperature

# Enable/disable heating types
echo 1 > /home/pi/heating/gas-heating-switch
echo 0 > /home/pi/heating/electrical-heating-switch

# Enable cheap electricity mode (00:01-08:00 only)
echo 1 > /home/pi/heating/cheap-electricity-heating
```

## Maintenance

### Upgrading Home Assistant
```bash
sudo ./upgrade-hass.sh
```

### Backup Configuration
```bash
tar czvf hass-backup-$(date +%Y%m%d).tar.gz /home/homeassistant/.homeassistant/
```

For detailed documentation:
https://www.home-assistant.io/docs/
