# Tuning Wazuh to Forward Alerts via Email

This guide explains how to configure Wazuh to send email notifications for critical security events. You’ll learn how to:

- Set up a Postfix SMTP relay (using Gmail as an example)
- Configure generic and granular email alert options in `ossec.conf`
- Create custom rules that trigger email alerts
- Forward real‑time Apache web server alerts

> Why email alerts?  
> While the Wazuh dashboard provides full visibility, email notifications ensure you don’t miss high‑severity events (e.g., brute force attacks, rootkit detections) – even when you’re away from the console.

---

## Prerequisites

- A working Wazuh manager (see [`install-guide.md`](install-guide.md))
- An email account that supports SMTP (Gmail, Outlook, or your organisation’s mail server)
- Ubuntu 22.04 on the Wazuh manager (Postfix will run locally)

---

## Step 1 – Install and Configure Postfix as an SMTP Relay

Wazuh’s built‑in email feature sends mail through a local SMTP server. We’ll use Postfix to relay messages to an external SMTP service (e.g., Gmail).

### 1.1 Install Postfix and dependencies

sudo apt update
sudo apt install -y postfix mailutils libsasl2-2 ca-certificates libsasl2-modules

When the installation menu appears, select “No configuration” (we will edit the config manually).

### 1.2 Backup and create the main configuration


sudo cp /usr/share/postfix/main.cf.debian /etc/postfix/main.cf

Edit /etc/postfix/main.cf:

sudo nano /etc/postfix/main.cf

Append or modify the following lines (replace with your own SMTP details – here we use Gmail as an example):
conf

relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
smtp_use_tls = yes
compatibility_level = 2

### 1.3 Add SMTP authentication credentials

Create /etc/postfix/sasl_passwd:


sudo nano /etc/postfix/sasl_passwd

Add one line (replace with your email and password/app‑specific password):
text

[smtp.gmail.com]:587 wazuhtest@gmail.com:your_app_password

    Security tip: For Gmail, enable 2‑factor authentication and generate an App Password. Do not use your regular password.

Now generate the hash database and secure the files:


sudo postmap /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

### 1.4 Restart Postfix and test

sudo systemctl restart postfix

Send a test email:

echo "Wazuh Postfix test" | mail -s "Test from Wazuh manager" your_destination@example.com

If the test arrives, Postfix is ready.
---

## Step 2 – Configure Wazuh Manager for Email Alerts

Edit the Wazuh manager configuration file:


sudo nano /var/ossec/etc/ossec.conf

### 2.1 Global email settings

Add or modify the <global> section:

<global>
  <email_notification>yes</email_notification>
  <smtp_server>localhost</smtp_server>
  <email_from>wazuhtest@gmail.com</email_from>
  <email_to>admin@example.com</email_to>
  <email_maxperhour>60</email_maxperhour>
</global>

    smtp_server – localhost because Postfix runs on the same host.

    email_from – must match the account used in Postfix sasl_passwd.

    email_to – default recipient (can be overridden by granular settings).

    email_maxperhour – maximum emails per hour; set high enough to avoid queuing critical alerts.

### 2.2 Global alert level threshold (optional)


<alerts>
  <email_alert_level>12</email_alert_level>
</alerts>

Only alerts with level ≥ 12 will trigger an email unless a rule contains the <options>alert_by_email</options> flag.

### 2.3 Granular email rules (per rule ID or group)

Add an <email_alerts> block inside <ossec_config> (after the <global> section).
For example, to send immediate emails for two specific rule IDs to multiple recipients:

<email_alerts>
  <email_to>security_team@example.com</email_to>
  <email_to>admin@example.com</email_to>
  <rule_id>30309, 100001</rule_id>
  <do_not_delay />
</email_alerts>

    do_not_delay – send immediately (no batching).

    You can also filter by level, group, or agent.
---

## Step 3 – Custom Rules That Trigger Email Alerts

In this example we create rules that watch for Apache web server attacks (invalid login attempts and brute‑force patterns).

### 3.1 Enable Apache log monitoring on the agent

On the Wazuh agent (the machine running Apache), edit /var/ossec/etc/ossec.conf and add:

<localfile>
  <log_format>apache</log_format>
  <location>/var/log/apache2/access.log</location>
</localfile>
<localfile>
  <log_format>apache</log_format>
  <location>/var/log/apache2/error.log</location>
</localfile>

Restart the agent:


sudo systemctl restart wazuh-agent

###  3.2 Add custom rules on the Wazuh manager

Edit the manager’s local rules file:

sudo nano /var/ossec/etc/rules/local_rules.

Append these rules:


<!-- Override the default Apache "invalid user" rule to force email alerts -->
<rule id="30309" level="7" overwrite="yes">
  <if_sid>30301</if_sid>
  <id>AH01618|AH01808|AH01790</id>
  <options>alert_by_email</options>
  <description>Apache: Attempt to login using a non-existent user.</description>
  <group>invalid_login,apache,email_alert</group>
</rule>

<!-- Custom composite rule: multiple authentication failures in 2 minutes -->
<rule id="100001" level="12" frequency="8" timeframe="120">
  <if_matched_sid>30310</if_matched_sid>
  <description>Apache: Multiple user authentication failures (potential brute force).</description>
  <group>authentication_failed,apache,brute_force,email_alert</group>
</rule>

    Rule 30309 uses alert_by_email – it will send an email even though its level (7) is below email_alert_level (12).

    Rule 100001 triggers when rule 30310 (Apache authentication failure) fires 8 times within 120 seconds. Its level is 12, so it also sends email via the global threshold.

### 3.3 Restart the Wazuh manager

sudo systemctl restart wazuh-manager
---

## Step 4 – Testing Email Alerts

### 4.1 Simulate an invalid login attempt on Apache

From a test machine, run:

curl -u fakeuser:wrongpass http://<APACHE_SERVER_IP>/

Or simply browse to http://<APACHE_SERVER_IP>/ and enter nonsense credentials if a login dialog appears.

### 4.2 Check the Wazuh dashboard

    Log into the dashboard and search for rule.id:30309 or rule.id:100001.

    Confirm the alerts are generated.

### 4.3 Verify email delivery

Within seconds, the configured recipients should receive an email similar to:
text

Wazuh Alert
Rule: 30309 - Apache: Attempt to login using a non-existent user.
Level: 7
Agent: ubuntu-apache (192.168.1.50)
Location: /var/log/apache2/error.log
Description: AH01618: user fakeuser not found

If you trigger 8 failures in 2 minutes, rule 100001 sends an email with level 12.
---

## Step 5 – Fine‑Tuning and Maintenance
Reduce duplicate alerts

Add a <email_maxperhour> value that balances urgency and load. For critical production, set to 360 (one per 10 seconds on average).
Use different recipients for different rule groups


<email_alerts>
  <email_to>webteam@example.com</email_to>
  <rule_group>apache</rule_group>
</email_alerts>
<email_alerts>
  <email_to>security@example.com</email_to>
  <rule_level>15</rule_level>
</email_alerts>

###### Disable email alerts for known false positives

In your local rules, you can add <options>no_email_alert</options> to suppress noise.
Monitor Postfix logs

###### If emails are not being sent, inspect:

sudo tail -f /var/log/mail.log

Common issues: incorrect app password, TLS certificates, or firewall blocking port 587