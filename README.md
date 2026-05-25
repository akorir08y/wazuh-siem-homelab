# Wazuh SIEM + EDR Homelab

## Overview
- Built a self-hosted, open-source security monitoring system (SIEM + EDR)
- Single-server all-in-one deployment on Ubuntu 22.04
- Monitors endpoints, logs, file changes, and suspicious activity

## Why I built this
- Demonstrate hands-on cybersecurity skills
- Create a cost-free security monitoring lab for learning
- Understand SIEM architecture without cloud vendor lock-in

## Architecture
- Wazuh Indexer (data storage/search)
- Wazuh Server/Manager (analysis & rules)
- Wazuh Dashboard (visualization)
- Agents installed on 2+ test VMs

## Technologies Used
- Wazuh 4.13
- Ubuntu 22.04 LTS
- VirtualBox / Cloud VM (specify which)
- Bash scripting
- Log rotation & cron jobs

## Setup Highlights
1. Configured static IP and firewall rules (ports 443, 1514, 1515)
2. Generated secure certs + passwords
3. Deployed agents to Linux endpoints
4. Enabled JSON and plaintext logging
5. Automated log cleanup with logrotate + cron

## Challenges & Solutions
- Issue: Agent wouldn't connect → fixed by verifying WAZUH_MANAGER IP in ossec.conf
- Issue: Dashboard inaccessible → opened port 443 in cloud firewall

## What I Learned
- SIEM vs EDR roles in security monitoring
- Linux service management (systemctl)
- Log lifecycle management
- Agent-server communication over UDP

## Future Improvements
- Add Windows agent
- Create custom detection rules
- Forward alerts to TheHive (SOAR)