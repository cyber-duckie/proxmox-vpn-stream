# Hardened Home Server Setup (Proxmox + VPN Streaming + Modular LXC Stack)
1. Overview

This project documents a hardened, all-round home server I built as a gift.
The system is designed for security, modularity, and expandability, using Proxmox VE as the hypervisor.
It includes:

A dedicated VPN LXC that acts as a secure, routed gateway

A Stremio Server LXC, running Stremio via Docker and routing all outbound traffic through the VPN

A future-proof architecture that allows adding LXC containers for Home Assistant, Frigate, and other home-automation services

The goal of the project was to build a privacy-focused streaming and automation environment that can grow over time without compromising security.

2. Architecture Diagram (ASCII)
```
                ┌─────────────────────────┐
                │     Proxmox Host        │   <--- VPN Connection via Tailscale
                │  (Bridged Network, LXC  │        for remote management/ access
                │    management)          │                      │
                └───────▲───────────▲─────┘                      └────► My remote Network
                        │           │
                        │           │
           ┌────────────┘           └───────────────┐
           │                                        │
   ┌───────┴───────────┐                    ┌───────┴─────────┐
   │    VPN LXC        │   Bridged Network  │    Stremio LXC  │
   │ wg0: 192.168.0.28 │ <────────────────> │ No direct WAN   │
   │ DNS: X.X.X.X      │                    │ Uses VPN LXC    │
   │ Torbox / AI       │                    │ AIostreams Addon│
   └───────▲───────────┘                    └─────────────────┘
           │                                       │
           │                                       │
           │                                       │
    ┌────────────┐                 ┌────────────────────────────────┐ 
    │  Internet  │                 │          192.168.0.X           │
    └────────────┘                 │ Internal Network for Streaming │
                                   │    on Smart TV/ IPad / etc     │
                                   └────────────────────────────────┘
```

3. How It Works
-  Proxmox as the Core

The Proxmox host manages all LXCs and provides hardware virtualization, backups, and isolation features.

-  VPN LXC (Gateway Container)

This LXC contains the VPN client (e.g., ProtonVPN, WireGuard).
It exposes a private internal interface to the Stremio LXC via a separate bridge.

Responsibilities:

Handles all outbound internet traffic

Provides region-unlocked streaming access

Acts as the secure gateway for dependent containers

-  Stremio LXC

This container runs Docker with a Stremio Server instance.
It has no direct internet route — its only network path goes through the VPN LXC.

Benefits:

Enforced privacy

Streaming addon geolocation freedom


4. Setup Summary

- Install Proxmox and configure secure defaults

- Create VPN LXC (Debian)

- Install and configure the VPN client (Wireguard using a ProtonVPN subscription)

- Create internal bridge (vmbr99) for isolated routing between both LXC

- Create Stremio LXC attached to the private VPN bridge, disable outbound internet connectivity

- Run Stremio Docker container

- Configure routing so Stremio uses the VPN as its gateway

- Test: verify Stremio has only VPN-based internet access

- Harden the system with firewall rules and access control + configure NAT and disable IPv6


5. Future Expansion

The architecture supports adding more containers, such as:

Home Assistant (home automation)

Frigate NVR (AI IP camera processing)

Pi-hole or AdGuard Home (DNS filtering)

Media servers (Jellyfin/Plex)

Backup systems (UrBackup, Syncthing, etc.)
