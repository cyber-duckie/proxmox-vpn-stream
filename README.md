# Hardened Home Server Setup (Proxmox + VPN Streaming + Modular LXC Stack)

## Content Overview:
1.[📦Overview](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--overview)<br/>
2.[🗺️Architecture Diagram (ASCII)](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--architecture-diagram-ascii)<br/>
3.[⚙️How it works](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--how-it-works)<br/>
4.[🏗️Setup Guide](https://github.com/cyber-duckie/hardend-home-server/blob/main/README.md#1--setup-guide)<br/>
  4.1[🧑‍💻🔒Install Proxmox and configure secure defaults](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#41-install-proxmox-and-configure-secure-defaults))<br/>
  4.2[📡Create a VPN LXC](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#42-create-vpn-lxc))<br/>
  4.3[🎬Create a Stremio LXC](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#43-create-a-stremio-lxc-attached-to-the-private-vpn-bridge-and-one-network-to-stream-locally))<br/>
  4.4[🐳⚡Install Docker and run the Stremio Server](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#44-install-docker-and-run-the-stremio-server)<br/>
  4.5[🚫🌐Disable IPv6](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#45-disable-ipv6)<br/>
  4.6[🌐Set up NAT and IPv4 forwarding rules](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#set-up-nat-and-ipv4-forwarding-rules)<br/>
  4.7[⚡⚙️Create a script to handle automatic setting up of a Wireguard connection on startup / Boot and then removing the non-vpn outbound connection](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#46-create-a-script-to-handle-automatic-setting-up-of-a-wireguard-connection-on-startup--boot-and-then-removing-the-non-vpn-outbound-connection)<br/>
  4.8[⏱️🔁Set the Start/ shutdown order](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#47-set-the-start-shutdown-order-to-make-sure-the-vpn-lxc-boots-first-then-stremio-second))<br/>
  4.9[🔥🧱Set up a hardened Firewall](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#48-set-up-a-hardened-firewall)<br/>
5.[🔍🌐Final test for any DNS / IP Leaks](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#5-final-test-for-any-dns--ip-leaks-from-both-containers)<br/>
6.[🛡️Final Checks / Hardening](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#6-final-checks--hardening)<br/>
7.[🚀Future Expansion](https://github.com/cyber-duckie/hardend-home-server/tree/main?tab=readme-ov-file#7-future-expansion)<br/>





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

## 2.  🗺️Architecture Diagram (ASCII)
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


## 4.📋Setup Guide 🏗

### 4.1 Install Proxmox and configure secure defaults

- 🧑‍💻 Create a Sudo User<br/>

```
adduser newusername
```
You will be asked to generate a new password for this account.

Add the user to the sudo group:

```
usermod -aG sudo newusername
```

Switch to the new user:

```
su - newusername
```

Test sudo privileges:

```
sudo whoami
```


<br/>

- ❌ Disable enterprise repos:

Datacenter -> Proxmox -> Repositories -> (under the 'Components' section) Diasable all Repositories with 'enterprise' or 'pve-enterprise'

<br/>
- Update and install repositories:

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

- 🔒 Install Fail2Ban: (https://github.com/fail2ban/fail2ban)<br/>

<br/>

```
sudo apt install -y fail2ban
```
<br/>

🔄 Enable and start the service:
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

- 🔄 Set up automatic updating:<br/>

```
apt install unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades
```

<br/>

- 🔗 Set up Tailscale and follow the steps to set up a remote connection:
  https://tailscale.com/kb/1174/install-debian-bookworm
<br/>

### 4.2 Create VPN LXC

Settings for my VPN LXC:

| Setting ⚙️      | Value 💻        |
| ------------- | ------------- |
| Cores         | 1             |
| RAM           | 1 GB          |
| Storage       | 40 GB         |
| OS Type       | Debian 64     |
| Unprivileged  | NO            |
| Privileged    | YES           |
| Start at boot | YES           |
| Nameserver    | 1.1.1.1       |

> [!NOTE]
> Make sure the VPN LXC is Privileged, otheriwse there will be routing issues

<br/>

Install Wireguard and edit the config file (e.g ProtonVPN)

Create internal bridge (vmbr99) for isolated routing between both LXCs and one for it so be reached on the network.

<br/>

> [!NOTE]
> Choose an ip address that is free to act as the bridge, e.g. 192.168.99.1/24
> Make it static

<br/>
My Network interfaces for this VPN LXC are:<br/>

![Eth0_Network-VPN](contentimages/eth0vpn.png)
 

<br/>

  ![Eth1_Network-VPN](contentimages/eth1vpn.png)


<br/>

### 4.3 Create a Stremio LXC attached to the private VPN bridge and one network to stream locally

Settings for my Stremio LXC:

| Setting ⚙️      | Value 💻        |
| ------------- | ------------- |
| Cores         | 2             |
| RAM           | 3.5 GB        |
| Storage       | 50 GB         |
| OS Type       | Debian 64     |
| Unprivileged  | YES           |
| Privileged    | NO            |
| Start at boot | YES           |
| Nesting       | YES           |
| Nameserver    | 10.2.0.1      |

  My Network interfaces for this Stremio LXC are:<br/>

![Eth0_Network-Stremio](contentimages/eth0stremio.png)
  

  <br/>

![Eth1_Network-Stremio](contentimages/eth1stremio.png)


<br/>

### 4.4 Install Docker and run the Stremio Server

<br/>


Install docker 🐳

```
sudo apt install -y docker.io
```

<br/>

Enable and start the Docker service so it runs on boot:
```
sudo systemctl enable --now docker
```
<br/>


Check that Docker is active:
```
sudo systemctl status docker
```

<br/>

Then; pull the docker image:

```
docker pull stremio/server
```

<br/>

🚀 Start Stremio server:

```
docker run -d \
  --name stremio-server \
  -p 11470:11470 \
  -v /path/to/stremio/config:/root/.stremio \
  stremio/stremio-server
```

<br/>


Verify that the stremio-server container is up and running:
```
docker ps
```


Thenn check that you can reach it via your webbrowser on port 11470 of that LXC IP:

e.g. 192.168.0.29:114770

<br/>
 
### 4.5 Disable IPv6

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


### 4.6 Set up NAT and IPv4 forwarding rules:

<br/>

> [!NOTE]
> 🛠 Prerequisites for VPN & Stremio LXC Firewall:<br/>
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

🌐🔐 VPN LXC Firewall & NAT Rules

These commands configure the VPN LXC to securely route traffic from other containers through WireGuard:

✅Forward traffic between the host interface (eth1) and WireGuard (wg0).

✅Masquerade (NAT) all container traffic so it exits via the VPN.

✅Block DNS leaks by forcing DNS queries through the WireGuard server.

✅Persist rules on boot using netfilter-persistent.

✅Extra wg-quick nftables chains are automatically created to mark UDP packets and protect the WireGuard IP.

✅IPv6 is disabled to prevent leaks, so no IPv6 rules are needed.

<br/>
📡 Set up NAT and IPv4 forwarding rules on the VPN LXC
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

<br/>

### 4.7 Create a script to handle automatic setting up of a Wireguard connection on startup / Boot and then removing the non-vpn outbound connection

⚙️**Systemd Auto-Start Integration**⚙️

The following will show the steps I took to make a custom script that automatically runs on every boot. It ensures:

✅No DNS leaks

✅The VPN DNS is only used after the VPN tunnel is up

✅All DNS traffic is blocked unless it goes to the VPN DNS

✅The system temporarily uses a public DNS to bring up the VPN interface

✅Fully automatic on boot via systemd

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


### 4.8 Set the Start/ shutdown order
This makes sure that the VPN LXC boots first, then Stremio second so it can build a connection seamlessly

    Under each LXC in the Proxmox node -> Options -> Start/ Shutdown order -> Edit (VPN-LXC=1, Stremio-LXC=2)

### 4.9 🔥🧱Set up a hardened Firewall


- General Policy: Drop all inbound traffic by default; allow only explicitly defined connections.

![Firewall Rules](contentimages/Firewallrules.png)

Apply the above shown Firewall rules on the Host-level under Proxmox->Firewall->Add.

> [!IMPORTANT]
> Important here is to keep the Block all other connections as the very last rule to avoid locking yourtself out!
**Test: verify Stremio has only VPN-based internet access**

<br/>

## 5. ✅Final test for any DNS / IP Leaks from both containers

![Testing VPN](contentimages/vpn-lxc-test.png)

Then a quick check using an online IP lookup tool:

![IP location](contentimages/vpn-location.png)


It works! All routing goes through my VPN including any DNS queries!

## 6. Final checks / Hardening

- 🛡 Harden kernel sysctls

  Check current sysctls:
```
sysctl net.ipv4.ip_forward
sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.all.accept_redirects
sysctl net.ipv4.conf.all.send_redirects
```
<br/>

If necessary, harden with;
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

- 🔗 Check if Tailscale is active
```
tailscale status
```
<br/>
Look for:

Your host device name

Correct 100.x.x.x IP

<br/>

- 🔒 Check open ports;
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

- 🔑 Check SSH security:
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

- 🔑🌐 Check if SSH is listening on the LAN only:
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

- 🧩 Check if unattended-upgrades is installed
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

- 🔥🧱 Check your firewall drop policy:
```
grep policy /etc/pve/firewall/cluster.fw
grep policy /etc/pve/nodes/$(hostname)/host.fw
```

## 7. Future Expansion

The architecture supports adding more containers, such as:

Home Assistant (home automation)

Frigate NVR (AI IP camera processing)

Pi-hole or AdGuard Home (DNS filtering)

Media servers (Jellyfin/Plex)

Backup systems (UrBackup, Syncthing, etc.)
