# Proof of Concept: Wazuh SIEM Active Response Against Known Malicious Actors

## Objective

Demonstrate how a Wazuh‑based SIEM/EDR can automatically detect an incoming connection from an IP address listed in a known threat intelligence feed (Alienvault IP reputation database) and immediately block that IP using a firewall‑drop active response.

## Environment

| Component       | OS / Platform        | Role                                                                 |
|----------------|----------------------|----------------------------------------------------------------------|
| Wazuh Server    | RHEL / Rocky / Alma   | Central manager, custom CDB list, rule engine, active response       |
| Ubuntu Endpoint | Ubuntu 22.04 LTS      | Wazuh agent + Apache web server (simulated target)                  |
| Attacker Endpoint | RHEL (any Linux)     | Simulates a malicious source – its IP is added to the reputation DB |

> Note: In a real scenario, the reputation list contains thousands of known malicious IPs. This PoC manually appends the “attacker” IP to the list to trigger the rule.

---
## Step 1 – Ubuntu Endpoint: Prepare the Agent and Apache

### 1.1 Install Apache web server

```
sudo apt update
sudo apt install apache2 -y
```

### 1.2 (Optional) Configure firewall to allow web traffic
```
sudo ufw status
sudo ufw app list
sudo ufw allow 'Apache'
```

### 1.3 Verify Apache is running

```
sudo systemctl status apache2 --no-pager
```

### 1.4 Test access from local browser or curl

```
curl http://localhost
```

Or from another machine:
```
curl http://<UBUNTU_IP>
```

### 1.5 Configure Wazuh agent to monitor Apache access logs

Edit /var/ossec/etc/ossec.conf on the Ubuntu endpoint and add the following inside the <ossec_config> block (usually at the end, before the closing tag):
```
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/apache2/access.log</location>
</localfile>
```

### 1.6 Restart the Wazuh agent
```
sudo systemctl restart wazuh-agent
```
Now the agent will forward every Apache access log entry to the Wazuh server.

---
## Step 2 – Wazuh Server: Build a Reputation‑Based CDB List

These steps are performed on the Wazuh server (RHEL‑based).

### 2.1 Install wget (if missing)
```
sudo yum update && sudo yum install -y wget
```
### 2.2 Download the Alienvault IP reputation database
```
sudo wget https://iplists.firehol.org/files/alienvault_reputation.ipset -O /var/ossec/etc/lists/alienvault_reputation.ipset
```
### 2.3 Append the “attacker” endpoint IP address

Replace <ATTACKER_IP> with the actual IP of your simulated malicious host.
```
sudo echo "<ATTACKER_IP>" >> /var/ossec/etc/lists/alienvault_reputation.ipset
```
### 2.4 Download the conversion script (.ipset → .cdb)
```
sudo wget https://wazuh.com/resources/iplist-to-cdblist.py -O /tmp/iplist-to-cdblist.py
```
### 2.5 Convert the list to Wazuh CDB format
```
sudo /var/ossec/framework/python/bin/python3 /tmp/iplist-to-cdblist.py /var/ossec/etc/lists/alienvault_reputation.ipset /var/ossec/etc/lists/blacklist-alienvault
```
### 2.6 (Optional) Clean up temporary files
```
sudo rm -rf /var/ossec/etc/lists/alienvault_reputation.ipset
sudo rm -rf /tmp/iplist-to-cdblist.py
```
### 2.7 Set correct ownership and permissions
```
sudo chown wazuh:wazuh /var/ossec/etc/lists/blacklist-alienvault
```
---
## Step 3 – Configure Custom Rule and Active Response

### 3.1 Create a custom rule in local_rules.

Edit /var/ossec/etc/rules/local_rules. on the Wazuh server and add the following:


<group name="attack,">
  <rule id="100100" level="10">
    <if_group>web|attack|attacks</if_group>
    <list field="srcip" lookup="address_match_key">etc/lists/blacklist-alienvault</list>
    <description>IP address found in AlienVault reputation database.</description>
  </rule>
</group>

This rule triggers at level 10 whenever the source IP (srcip) of a web‑related alert matches an entry in our CDB list.

### 3.2 Include the CDB list in the main ossec.conf

Edit /var/ossec/etc/ossec.conf on the Wazuh server and add the blacklist-alienvault line inside the <ruleset> section:

<ossec_config>
  <ruleset>
    <!-- Default ruleset -->
    <decoder_dir>ruleset/decoders</decoder_dir>
    <rule_dir>ruleset/rules</rule_dir>
    <rule_exclude>0215-policy_rules.</rule_exclude>
    <list>etc/lists/audit-keys</list>
    <list>etc/lists/amazon/aws-eventnames</list>
    <list>etc/lists/security-eventchannel</list>
    <list>etc/lists/blacklist-alienvault</list>   <!-- Add this line -->

    <!-- User-defined ruleset -->
    <decoder_dir>etc/decoders</decoder_dir>
    <rule_dir>etc/rules</rule_dir>
  </ruleset>
</ossec_config>

### 3.3 Add active response block – firewall‑drop

Still in /var/ossec/etc/ossec.conf, add the following <active-response> block (inside <ossec_config>):

<active-response>
  <disabled>no</disabled>
  <command>firewall-drop</command>
  <location>local</location>
  <rules_id>100100</rules_id>
  <timeout>60</timeout>
</active-response>

firewall-drop – built‑in command that uses iptables to block the source IP.

location – local means execute on the agent that received the attack.

timeout – block only for 60 seconds (long enough to test; production values may be longer).

### 3.4 Restart the Wazuh manager

sudo systemctl restart wazuh-manager

---
## Step 4 – Verify the PoC

### 4.1 Simulate a malicious request

From the attacker endpoint (IP that was added to the blacklist), run a simple curl against the Ubuntu Apache server:

```
curl http://<UBUNTU_IP>/
```
### 4.2 Check the Wazuh dashboard

Log into the Wazuh dashboard → Security events.

Search for rule ID 100100.

You should see an alert with the description:
    IP address found in AlienVault reputation database.

### 4.3 Confirm active response

On the Ubuntu endpoint, check the current iptables rules:
```
sudo iptables -L INPUT -n --line-numbers
```
You should see a temporary DROP rule for the attacker’s IP (with a comment containing wazuh-firewall-drop).

The block lasts 60 seconds – after that the rule disappears automatically.

### 4.4 (Optional) Verify the block in real time

While the block is active, try the same curl from the attacker again. The connection will hang or time out.