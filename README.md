# Hardened Home Server Setup (Proxmox + VPN Streaming + Modular LXC Stack)

## Content:
1.[Overview](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--overview)<br/>
2.[Architecture Diagram (ASCII)](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--architecture-diagram-ascii)<br/>
3.[How it works](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--how-it-works)<br/>
3.[Setup Summary](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--setup-summary)<br/>
3.[Systemd Auto-Start Integration](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--systemd-auto-start-integration)<br/>
3.[Setting up a hardened Firewall](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--setting-up-a-hardened-firewall)<br/>
3.[Architecture Diagram (ASCII)](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--overview)<br/>
3.[Architecture Diagram (ASCII)](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--overview)<br/>




## 1. 📦 Overview

This project documents a hardened, media streaming server that uses Stremio which I built as a gift.
The system is designed for security, modularity, and expandability, using Proxmox VE as the hypervisor.

In it's current configuration, it runs:

--> 📡 VPN LXC – Runs ProtonVPN-CLI / WireGuard and acts as a gateway.

--> 📺 Stremio LXC – Runs the Stremio server, sending all outbound traffic through the VPN container.

Network routing is handled using policy-based routing, iptables, and Proxmox container configuration.

A future-proof architecture that allows adding LXC containers for Home Assistant, Frigate, and other home-automation services

The goal of the project was to build a privacy-focused streaming and automation environment that can grow over time without compromising security.

This Github Project aims to give others a guide on how to setup such a streaming server and for myself as a repository to copy the code if i want to replicate this server for other relatives with ease without having to rebuild and reconfigure everything from scratch.

## 2. 🖼️Architecture Diagram (ASCII)
```
                ┌─────────────────────────┐
                │     Proxmox Host        │   <--- VPN Connection via Tailscale
                │  (Bridged Network, LXC  │        for remote Management/ Access
                │    management)          │                     │
                │  - Fail2Ban             │                     │
                │  - Tailscale VPN        │                     │
                │  - Netdata              │                     │    ┌───────────────────┐
                └─────▲─────▲─────▲───────┘                     └────► My remote Network │
                        │   │     │                                  └───────────────────┘
                        │   │     └────────────────────────────────────────────┐
           ┌────────────┘   └───────────────────────┐                          │
           │                                        │                          │
   ┌───────┴───────────┐                    ┌───────┴───────┐     ┌────────────┴────────────┐
   │    VPN LXC        │   Bridged Network  │   Stremio LXC │     │  Lightweight ARCH Linux │
   │ wg0: 192.168.0.28 │ <────────────────> │ No direct WAN │     │  for remote access      │
   │ VPN DNS           │                    │ Uses VPN LXC  │     │  of network devices     │
   │                   │                    │               │     │  e.g. router interface  │
   └───────▲───────────┘                    └───────────────┘     │  to add IP reservations │
           │                                       │              │  for future LXCs        │
           │                                       │              └─────────────────────────┘ 
           │                                       │
    ┌────────────┐                 ┌────────────────────────────────┐ 
    │  Internet  │                 │          192.168.0.X           │
    └────────────┘                 │ Internal Network for Streaming │
                                   │    on Smart TV/ IPad / etc     │
                                   └────────────────────────────────┘
```

## 3. How It Works
-  Proxmox as the Core

The Proxmox host manages all LXCs and provides hardware virtualization, backups, and isolation features.

-  📡 VPN LXC (Gateway Container)

This LXC contains the VPN client (e.g., ProtonVPN running on wireguard WireGuard).
It exposes a private internal interface to the Stremio LXC via a separate bridge (vmbr99) in my case but this is up to you.

Responsibilities:

Handles all outbound internet traffic for the Stremio LXC

Provides region-unlocked streaming access

Acts as the secure gateway for dependent containers

-  📺 Stremio LXC

This container runs Docker with a Stremio Server instance.
It has no direct internet route — its only network path goes through the VPN LXC (vmbr99).

Benefits:

Enforced privacy

Streaming addon geolocation freedom


## 4.📋Setup Summary

1️⃣ **Install Proxmox and configure secure defaults**

  -> Create a Sudo User<br/>
  
  -> Disable enterprise repos
  <br/>
Datacenter -> Proxmox -> Repositories -> (under the 'Components' section) Diasable all Repositories with 'enterprise' or 'pve-enterprise'

<br/>
  -> Update and install repositories:

  ```
  sudo apt update
  sudo apt full-upgrade -y
  ```
<br/>

Optional: Clean unused old repos:

```
sudo apt autoremove -y
sudo apt clean
```

<br/>

  -> Install Fail2Ban: (https://github.com/fail2ban/fail2ban)<br/>

<br/>

```
sudo apt install -y fail2ban
```
<br/>

Enable and start the service:
```
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

<br/>

Check with:
```
sudo systemctl status fail2ban
```

<br/>

  -> Set up automatic updating:<br/>

```
apt install unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades
```

<br/>

  -> Set up Tailscale and follow the steps to set up a remote connection: https://tailscale.com/kb/1174/install-debian-bookworm
<br/>

2️⃣ **Create VPN LXC (Debian)**

Settings for my VPN LXC:



| Setting       | Value         |
| ------------- | ------------- |
| Cores         | 1             |
| RAM           | 1 GB          |
| Storage       | 20 GB         |
| OS Type       | Debian 64     |
| Unprivileged  | NO            |
| Privileged    | YES           |
| Start at boot | YES           |



Install Wireguard and edit the config file (e.g ProtonVPN)

Create internal bridge (vmbr99) for isolated routing between both LXCs and one for it so be reached on the network.

> [!NOTE]
> Choose an ip address that is free to act as the bridge, e.g. 192.168.99.1/24<br/>
> Make it static

<br/>
My Network interfaces for this VPN LXC are:<br/>

![Eth0_Network-VPN](contentimages/eth0vpn.png)
 

<br/>

  ![Eth1_Network-VPN](contentimages/eth1vpn.png)


<br/>

3️⃣ **Create a Stremio LXC attached to the private VPN bridge and one network to stream locally**

  My Network interfaces for this Stremio LXC are:<br/>

![Eth0_Network-Stremio](contentimages/eth0stremio.png)
  

  <br/>

![Eth1_Network-Stremio](contentimages/eth1stremio.png)


<br/>

4️⃣ **Run Stremio Docker container: https://github.com/Stremio/server-docker**


> [!NOTE]
> Docker must be installed first:
> https://docs.docker.com/engine/install/debian/

<br/>


5️⃣ **Test: verify Stremio has only VPN-based internet access**

6️⃣ **Harden the system with firewall rules and access control + configure NAT and disable IPv6**

  Disable IPv6:

  In both the VPN LXC and Stremio LXC, edit the /etc/sysctl.conf file:

<br/>

```
sudo nano /etc/sysctl.conf
```

<br/>

Add these lines:
```
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
```
<br/>

- Any entries in the /etc/sysctl.conf file are applied automatically on boot.

<br/>

- Reload the sysctl settings:
```
sudo sysctl -p
```

<br/>

Confirm with:


```
sysctl net.ipv6.conf.all.disable_ipv6
sysctl net.ipv6.conf.default.disable_ipv6
```

<br/>

- Should return '1'


### Set up NAT and IPv4 forwarding rules:

<br/>

> [!NOTE]
> 🛠 Prerequisites for VPN & Stremio LXC Firewall
> Before applying the firewall and NAT rules, make sure the following packages and services are installed and enabled in both LXC's:

<br/>

```
# Update package lists
sudo apt update

# Install iptables, persistent rules, and nftables
sudo apt install -y iptables iptables-persistent nftables

# Enable and start persistent rule service
sudo systemctl enable --now netfilter-persistent

# Enable and start nftables service (optional, used by wg-quick chains)
sudo systemctl enable --now nftables
```

<br/>

**VPN-LXC:**

<br/>

📡 VPN LXC Firewall & NAT Rules

These commands configure the VPN LXC to securely route traffic from other containers through WireGuard:

Forward traffic between the host interface (eth1) and WireGuard (wg0).

Masquerade (NAT) all container traffic so it exits via the VPN.

Block DNS leaks by forcing DNS queries through the WireGuard server.

Persist rules on boot using netfilter-persistent.

Extra wg-quick nftables chains are automatically created to mark UDP packets and protect the WireGuard IP.

IPv6 is disabled to prevent leaks, so no IPv6 rules are needed.

<br/>
📡 Set up NAT and IPv4 forwarding rules
<br/>

Allow forwarding between the LXC's network interface (replace eth1 with your actual interface name) and the WireGuard interface:
```
iptables -A FORWARD -i eth1 -o wg0 -j ACCEPT
iptables -A FORWARD -i wg0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

<br/>

Enable IPv4 masquerading so all container traffic goes out through the VPN:
```
iptables -t nat -A POSTROUTING -s 192.168.99.0/24 -o wg0 -j MASQUERADE
```

<br/>

⛔ DNS-blocking rule (to prevent DNS leaks). This ensures DNS is forced through the WireGuard server.

```
iptables -A OUTPUT -p tcp --dport 53 ! -d 10.2.0.1 -j REJECT
iptables -A OUTPUT -p udp --dport 53 ! -d 10.2.0.1 -j REJECT
```

<br/>
> [!NOTE]
> No IPv6 rules are needed and can be skipped, because we disabled IPv6 completely already to avoid any leaks.

<br/>

💾 Make the rules persistent on boot

```
netfilter-persistent save
```
<br/>

**Stremio-LXC:**

📡 VPN and DNS Rules for Stremio LXC
<br/>

These commands configure the Stremio LXC to route all traffic through the WireGuard VPN and prevent DNS leaks:

Forward traffic between the LXC’s network interface and the WireGuard interface.

Masquerade (NAT) all container traffic so it exits via the VPN.

Force DNS through the WireGuard server by rejecting any other DNS requests.

Make rules persistent so they survive reboots.

No IPv6 rules are needed since IPv6 is disabled to avoid leaks.

<br/>
Allow forwarding between Stremio LXC network and WireGuard

```
iptables -A FORWARD -i eth1 -o wg0 -j ACCEPT
iptables -A FORWARD -i wg0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

Masquerade (NAT) for IPv4. This ensures all traffic from your Stremio LXC goes out through the WireGuard VPN.

```
iptables -t nat -A POSTROUTING -s 192.168.99.0/24 -o wg0 -j MASQUERADE
```

⛔ DNS-blocking rule (to prevent DNS leaks). This ensures DNS is forced through the WireGuard server.

```
iptables -A OUTPUT -p tcp --dport 53 ! -d 10.2.0.1 -j REJECT
iptables -A OUTPUT -p udp --dport 53 ! -d 10.2.0.1 -j REJECT
```
<br/>

💾 Make the rules persistent on boot

```
netfilter-persistent save
```


7️⃣ **Create a script to handle automatic setting up of a Wireguard connection on startup / Boot and then removing the non-vpn outbound connection (see point following point 5.)**

8️⃣ **Set the Start/ shutdown order to make sure the VPN LXC boots first, then Stremio second**
    Uder each LXC in the Proxmox node -> Options -> Start/ Shutdown order -> Edit (VPN-LXC=1, Stremio-LXC=2)

<br/>

## 5.🗒️Systemd Auto-Start Integration

The following will show the steps I took to make a custom script that automatically runs on every boot. It ensures:

- No DNS leaks

- The VPN DNS is only used after the VPN tunnel is up

- All DNS traffic is blocked unless it goes to the VPN DNS

- The system temporarily uses a public DNS to bring up the VPN interface

- Fully automatic on boot via systemd

This tutorial assumes:

- Your ProtonVPN LXC runs WireGuard (wg0)

- VPN DNS is: 10.2.0.1

- Temporary DNS for bootstrapping: 1.1.1.1 (cloudflare)

<br/>

(1). Create the VPN bootstrap script
Inside the VPN LXC, create:

<br/>

```
sudo nano /usr/local/bin/vpn-dns-lock.sh
```

<br/>

(2). Enter the following script:
<br/>

```
#!/bin/bash
# vpn-dns-lock.sh

WG_IF="wg0"
VPN_DNS="10.2.0.1"
TEMP_DNS="1.1.1.1"
WAIT_TIMEOUT=15

# 1. Set temporary DNS to bootstrap VPN
echo "nameserver $TEMP_DNS" > /etc/resolv.conf
echo "[INFO] Temporary DNS $TEMP_DNS set."

# 2. Bring up WireGuard if not already up
if ! wg show $WG_IF &>/dev/null; then
    echo "[INFO] Bringing up WireGuard interface $WG_IF..."
    wg-quick up $WG_IF
fi

# 3. Wait until VPN DNS responds
echo "[INFO] Waiting for VPN DNS $VPN_DNS..."
for i in $(seq 1 $WAIT_TIMEOUT); do
    if dig @"$VPN_DNS" google.com +short &>/dev/null; then
        echo "[INFO] VPN DNS reachable!"
        break
    fi
    sleep 1
done

# 4. Switch resolv.conf to VPN DNS
echo "nameserver $VPN_DNS" > /etc/resolv.conf
echo "[INFO] Switched to VPN DNS $VPN_DNS."

# 5. Apply DNS leak protection
iptables -C OUTPUT ! -d $VPN_DNS -p udp --dport 53 -j REJECT 2>/dev/null || \
iptables -I OUTPUT ! -d $VPN_DNS -p udp --dport 53 -j REJECT
iptables -C OUTPUT ! -d $VPN_DNS -p tcp --dport 53 -j REJECT 2>/dev/null || \
iptables -I OUTPUT ! -d $VPN_DNS -p tcp --dport 53 -j REJECT
echo "[INFO] DNS leak protection applied."
```

<br/>

Then, make it executable:

<br/>

```
sudo chmod +x /usr/local/bin/vpn-dns-lock.sh
```
<br/>

(3). Prevent Systemd-Resolved from overwriting DNS:

<br/>

Enter:
```
chattr +i /etc/resolv.conf
```

<br/>

(4). Create a Systemd Service:
Enter:
```
sudo nano /etc/systemd/system/vpn-dns-lock.service
```

<br/>

Then paste in:

```
# /etc/systemd/system/vpn-dns-lock.service
[Unit]
Description=VPN DNS Lock
After=network-online.target wg-quick@wg0.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vpn-dns-lock.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

<br/>

Enable and start (automatically start on every boot):
```
sudo systemctl enable vpn-dns-lock.service
sudo systemctl start vpn-dns-lock.service
```

What this ensures against:<br/><br/>
✔ DNS leaks<br/>
✔ LXC trying to use LAN DNS during boot<br/>
✔ Apps resolving via host (Proxmox) DNS<br/>
✔ Fallback DNS hijacking<br/>
✔ Fail-open scenarios when VPN temporarily drops<br/>

<br/>

## 6. 🧱🛡️Set up a hardened Firewall to:


- General Policy: Drop all inbound traffic by default; allow only explicitly defined connections.

![Firewall Rules](contentimages/Firewallrules.png)

Apply the above shown Firewall rules on the Host-level under Proxmox->Firewall->Add.

> [!IMPORTANT]
> Important here is to keep the Block all other connections as the very last rule to avoid locking yourtself out!




## 7. ✅Final test for any DNS / IP Leaks from both containers:

![Testing VPN](contentimages/vpn-lxc-test.png)

Then a quick check using an online IP lookup tool:

![IP location](contentimages/vpn-location.png)


It works! All routing goes through my VPN including any DNS queries!

## 8. Final checks / hardening

- Harden kernel sysctls

  Check current sysctls:
```
sysctl net.ipv4.ip_forward
sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.all.accept_redirects
sysctl net.ipv4.conf.all.send_redirects
```
<br/>

Harden with;
```
cat <<EOF >> /etc/sysctl.conf
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF

sysctl -p
```
<br/>

- Check if Tailscale is active
```
tailscale status
```
<br/>
Look for:

Your host device name

Correct 100.x.x.x IP

<br/>

- Check open ports;
```
- ss -tuln
```

<br/>

Expected outoput:

8006 (web GUI)

22 (SSH – ideally LAN only)

3128 (only if using proxy)

tailscaled (port 41641/udp)

Maybe VPN LXC bridges

<br/>

- Check SSH security:
  Check SSH config;
```
grep -E "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config
```

<br/>

  Ideally should show:

```
PermitRootLogin no
PasswordAuthentication no
```

<br/>

  Check if SSH is listening on the LAN only:
```
ss -tulpn | grep ssh
```

<br/>

> [!IMPORTANT]
> If you get 0.0.0.0:22, it means SSH is listening on all interfaces
> Should be restricted to LAN or to LAN + Tailscale only

<br/>

  If it is listening on all interfaces; change with:
```
nano /etc/ssh/sshd_config
```

<br/>

Then add/ replace with:
```
ListenAddress 192.168.0.10   # LAN IP
ListenAddress 100.x.x.x      # Proxmox's own Tailscale IP
```

<br/>

Finally, restart the ssh daemon:
```
systemctl restart sshd
```

<br/>

- Check if unattended-upgrades is installed
```
systemctl status unattended-upgrades
```

<br/>

Look for:
Active: active (running)

- Check AppArmor security
```
aa-status
```

- Check if Proxmox enterprise repo is removed / disabled
```
cat /etc/apt/sources.list.d/pve-enterprise.list
```


It should be commented out:
```
# deb https://enterprise.proxmox.com ...
```

- Check your firewall drop policy:
```
grep policy /etc/pve/firewall/cluster.fw
grep policy /etc/pve/nodes/$(hostname)/host.fw
```

## 8. Future Expansion

The architecture supports adding more containers, such as:

Home Assistant (home automation)

Frigate NVR (AI IP camera processing)

Pi-hole or AdGuard Home (DNS filtering)

Media servers (Jellyfin/Plex)

Backup systems (UrBackup, Syncthing, etc.)
