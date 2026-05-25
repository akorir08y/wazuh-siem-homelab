# Troubleshooting Wazuh Deployment

## Agent Won’t Connect

Symptom: Agent appears as “Disconnected” in the dashboard.

Possible causes and solutions:

1. Incorrect manager IP 
   - On the agent, check `/var/ossec/etc/ossec.conf`.  
   - Verify the `<address>` tag contains your Wazuh manager’s static IP.  
   - Correct and restart: 

```sudo systemctl restart wazuh-agent```

2. Firewall blocking ports 1514/1515 (UDP)  
   - Ensure your cloud firewall or local `ufw` allows inbound UDP on 1514 (agent → manager) and 1515 (manager → agent).  
   - Example: 

```sudo ufw allow 1514/udp; sudo ufw allow 1515/udp```

3. Agent registration missing  
   - Re‑run the agent deployment command from the dashboard.  
   - The command includes `WAZUH_MANAGER='YOUR_SERVER_IP'`.

---
## Cannot Access Wazuh Dashboard

Symptom: Browser shows “connection refused” or timeout.

Solutions:
- Check that port 443 (HTTPS) is open in your firewall.  
- Confirm the Wazuh dashboard service is running:  

```sudo systemctl status wazuh-dashboard```  

- Verify the URL: `https://<YOUR_SERVER_IP>` (not `http`).  
- If using a self‑signed certificate, your browser will show a warning – proceed manually.

## Forgot Admin Password

The passwords are stored in the `wazuh-passwords.txt` file that was generated during installation.  
If you lost it, you can reset the password using the `wazuh-passwords-tool.sh`:

```
sudo /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh -u admin -p NEW_PASSWORD
```