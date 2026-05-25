# Wazuh SIEM / EDR Installation Guide

## Prerequisites

Before you begin, ensure you have:

- A server (physical or VM) with **4 CPU cores, 16GB RAM, 100GB SSD** (minimum)
- **Ubuntu 22.04** installed
- A **static IP address** for the server

> **Pro Tip:** Test this in a personal or non‑critical environment first.

---

## Step-by-Step Installation

### Step 1: Download the Installation Files

Navigate to `/opt`, create a `Wazuh` directory, and download the official installer and configuration file.

cd /opt
sudo mkdir Wazuh
cd Wazuh
curl -sO https://packages.wazuh.com/4.13/wazuh-install.sh
curl -sO https://packages.wazuh.com/4.13/config.yml

### Step 2: Download the Installation Files

1. Find your server's static IP:

ip addr show eth0

2. Edit the configuration file: 

sudo nano config.yml

3. Replace every <internal static ip address> placeholder with your actual IP. It should look like this:

nodes:
  indexer:
    - name: node-1
      ip: "192.168.1.100"      # Your IP here
  server:
    - name: wazuh-1
      ip: "192.168.1.100"      # And here
  dashboard:
    - name: dashboard
      ip: "192.168.1.100"      # And here

Save and exit (Ctrl+X, then Y, then Enter).
---

### Step 3: Generate Certificates and Passwords

1. Run the certificate generation script:

sudo bash wazuh-install.sh --generate-config-files

2. Important: Extract and save the generated passwords immediately:

sudo tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt

Store this output in a secure place (e.g., a password manager).

### Step 4: Run the Full Installation

Execute the main installation. This is an all-in-one installation of the Wazuh Server, Dashboard and Manager (this will take a few minutes):
---

### Step 5: Configure Firewall Rules

1. Open the required ports for your Wazuh server:

Port	 Protocol	    Purpose
443	     TCP	        Web dashboard (HTTPS)
1514	 UDP	        Agents report activity
1515	 UDP	        Server communication back to agents

2. How to open these depends on your environment:

    Cloud providers (GCP, AWS, Azure): use “Firewall Rules” or “Security Groups”

    On‑premises / local: use ufw or firewalld

Example using ufw (Ubuntu)

sudo ufw allow 443/tcp
sudo ufw allow 1514/udp
sudo ufw allow 1515/udp
sudo ufw enable
---

### Step 6: Deploy Agents on Your Other Computers

1. Open a browser and go to https://YOUR_SERVER_IP

2. Log in with username admin and the password saved earlier

3. Navigate to Agents → Deploy new agent

4. Select the target operating system (e.g., Linux Ubuntu)

5. Copy and run the commands shown on the dashboard. They will resemble:

wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.13.1-1_amd64.deb && sudo WAZUH_MANAGER='YOUR_SERVER_IP' WAZUH_AGENT_GROUP='default' dpkg -i ./wazuh-agent_4.13.1-1_amd64.deb

sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

6. Once the agent starts, it will appear as “Active” in your Wazuh dashboard.

7. Troubleshooting Agent Connections:

8. Edit /var/ossec/etc/ossec.conf on the agent and verify the <address> tag matches your server IP. Then restart:

sudo systemctl restart wazuh-agent
---

### Step 7: Set Up Log Rotation and Maintenance

Wazuh already includes some log rotation defaults, but you can customise it.

#### Adjust Wazuh Indexer JVM Options (optional)

sudo nano /etc/wazuh-indexer/jvm.options

1. Set heap size (example for 16GB RAM) Properties:

-Xms2048m
-Xmx2048m

2. Enable GC log rotation (add this line):

-Xlog:gc*,gc+age*=trace:file=/var/log/wazuh-indexer/gc.log:utctime,level,tags:filecount=5,filesize=50m

3. Restart the Wazuh Manager after changes:

sudo systemctl restart wazuh-manager

#### Create a Log Rotation File for Archives

sudo nano /etc/logrotate.d/wazuh-archives

/var/ossec/logs/archives/archives.log /var/ossec/logs/archives/archives.json {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 wazuh wazuh
    postrotate
        /usr/bin/systemctl restart wazuh-manager
    endscript
}

#### Create a Log Rotation File for the Indexer

sudo nano /etc/logrotate.d/wazuh-indexer

/var/log/wazuh-indexer/*.log {
    weekly
    rotate 3
    compress
    missingok
    notifempty
    create 0640 wazuh-indexer wazuh-indexer
    postrotate
        systemctl try-restart wazuh-indexer
    endscript
}


#### Automated Cleanup with Cron (Optional)

Remove alert/archive files older than 14 days weekly:

sudo crontab -e

0 0 * * mon find /var/ossec/logs/alerts/ -type f -mtime +14 -exec rm -f {} \;
0 0 * * mon find /var/ossec/logs/archives/ -type f -mtime +14 -exec rm -f {} \;