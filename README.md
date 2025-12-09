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

1️⃣ Install Proxmox and configure secure defaults

  -> Create a User<br/>
  -> update and install repositories<br/>
  -> Install Fail2Ban: https://github.com/fail2ban/fail2ban<br/>
  -> Set up automatic updating:<br/>

```
apt install unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades
```

  -> Set up Tailscale and follow the steps to set up a remote connection: https://tailscale.com/kb/1174/install-debian-bookworm

      
2️⃣ Create VPN LXC (Debian)

Install Wireguard and edit the config file (e.g ProtonVPN)

Create internal bridge (vmbr99) for isolated routing between both LXCs and one for it so be reached on the network.

> [!NOTE]
> Choose an ip address that is free to act as the bridge, e.g. 192.168.99.1/24<br/>
> Make it static


My Network interfaces for this VPN LXC are:<br/>
  
  Network Adress of the VPN LXC (static):<br/>
  -> Name: eth0<br/>
  -> Bridge: vmbr0<br/>
  -> IPv4/CIDR:192.168.0.28/24<br/>
  -> Gateway (IPv4): 192.168.0.1<br/>

  Bridged Network to Stremio (static):<br/>
  -> Name: eth1<br/>
  -> Bridge: vmbr99<br/>
  -> IPv4/CIDR: 192.168.99.1/24<br/>
  NO GATEWAY<br/>

3️⃣ Create a Stremio LXC attached to the private VPN bridge and one network to stream locally.

  My Network interfaces for this Stremio LXC are:<br/>
  
  Network Adress of the LXC (static):<br/>
  -> Name: eth0<br/>
  -> Bridge: vmbr0<br/>
  -> IPv4/CIDR: 192.168.0.29/24<br/>
  NO GATEWAY<br/>
  
  Bridged Network to VPN (static):<br/>
  -> Name: eth1<br/>
  -> Bridge: vmbr99<br/>
  -> IPv4/CIDR:192.168.99.2/24<br/>
  -> Gateway (IPv4):192.168.99.1<br/>

4️⃣ Run Stremio Docker container: https://github.com/Stremio/server-docker

5️⃣ Test: verify Stremio has only VPN-based internet access

6️⃣ Harden the system with firewall rules and access control + configure NAT and disable IPv6

7️⃣ Create a script to handle automatic setting up of a Wireguard connection on startup / Boot and then removing the non-vpn outbound connection (see point following point 5.)


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

(1). Create the VPN bootstrap script
Inside the VPN LXC, create:

```
sudo nano /usr/local/bin/vpn-dns-lock.sh
```

(2). Enter the following script:
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

Then, make it executable:

```
sudo chmod +x /usr/local/bin/vpn-dns-lock.sh
```
(3). Prevent Systemd-Resolved from overwriting DNS:

Enter:
```
chattr +i /etc/resolv.conf
```

(4). Create a Systemd Service:
Enter:
```
sudo nano /etc/systemd/system/vpn-dns-lock.service
```

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
