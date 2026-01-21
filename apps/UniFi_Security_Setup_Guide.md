# UniFi Network Security Setup Guide

A comprehensive guide for setting up a secure home network with VLAN segmentation on UniFi Dream Machine Pro (or similar UniFi gateway). This guide can be followed manually or with Claude's assistance via browser automation.

---

## Overview

This configuration creates three separate network segments to isolate devices by trust level:

| Network | VLAN ID | Subnet | Purpose |
|---------|---------|--------|---------|
| **LAN** | 1 | 192.168.1.0/24 | Trusted devices (computers, phones) |
| **IoT** | 20 | 192.168.20.0/24 | Smart home devices (lights, sensors, etc.) |
| **NoT** | 30 | 192.168.30.0/24 | Untrusted/Network of Things (cameras, appliances) |

**Security Goal:** IoT and NoT devices can access the internet but cannot access your trusted LAN devices or the router admin interface.

---

## Prerequisites

- UniFi Dream Machine Pro, UDM, or UniFi Gateway
- UniFi Access Point(s)
- Access to UniFi Network console (https://unifi.ui.com or local IP)
- Admin credentials

---

## Part 1: Create Networks (VLANs)

### Step 1: Access UniFi Console
1. Go to https://unifi.ui.com and log in
2. Select your UniFi console
3. Click **Settings** (gear icon) → **Networks**

### Step 2: Verify LAN Network
Your default LAN should already exist:
- **Name:** LAN
- **VLAN ID:** 1 (or none/native)
- **Subnet:** 192.168.1.0/24
- **DHCP:** Server enabled

### Step 3: Create IoT Network
1. Click **Create New Network**
2. Configure:
   - **Name:** `IoT`
   - **Router:** Your gateway device
   - **VLAN ID:** `20`
   - **Gateway IP/Subnet:** `192.168.20.1/24`
   - **DHCP Mode:** DHCP Server
   - **DHCP Range:** 192.168.20.6 - 192.168.20.254
3. Click **Add Network**

### Step 4: Create NoT Network
1. Click **Create New Network**
2. Configure:
   - **Name:** `NoT`
   - **Router:** Your gateway device
   - **VLAN ID:** `30`
   - **Gateway IP/Subnet:** `192.168.30.1/24`
   - **DHCP Mode:** DHCP Server
   - **DHCP Range:** 192.168.30.6 - 192.168.30.254
3. Click **Add Network**

---

## Part 2: Create WiFi Networks

### Step 1: Navigate to WiFi Settings
1. Go to **Settings** → **WiFi**

### Step 2: Main WiFi (Trusted Devices)
1. Click **Create New WiFi Network**
2. Configure:
   - **Name:** `YourMainWiFi` (choose your own SSID)
   - **Password:** Strong password (16+ characters recommended)
   - **Network:** Native Network (LAN)
   - **WiFi Band:** 2.4 GHz and 5 GHz
   - **Security Protocol:** WPA2/WPA3
3. Click **Add WiFi Network**

### Step 3: IoT WiFi
1. Click **Create New WiFi Network**
2. Configure:
   - **Name:** `YourIoTWiFi` (choose your own SSID)
   - **Password:** Strong password
   - **Network:** IoT (VLAN 20)
   - **WiFi Band:** 2.4 GHz (most IoT devices only support 2.4)
   - **Security Protocol:** WPA2
3. Click **Add WiFi Network**

### Step 4: Guest WiFi (Optional)
1. Click **Create New WiFi Network**
2. Configure:
   - **Name:** `YourGuestWiFi`
   - **Password:** Separate password for guests
   - **Network:** IoT (VLAN 20) or create separate Guest VLAN
   - **WiFi Band:** 2.4 GHz and 5 GHz
3. Click **Add WiFi Network**

---

## Part 3: Create Firewall Rules

Navigate to **Settings** → **Firewall & Security** → **Firewall Rules** (or **Traffic & Firewall Rules** in older UI)

### Important: Rule Order Matters!
Firewall rules are processed top-to-bottom. Allow rules should come before block rules.

---

### Rule 1: Allow Established and Related Traffic
**Purpose:** Allows return traffic for connections initiated from your network

| Setting | Value |
|---------|-------|
| Type | LAN In |
| Name | `Allow Established and Related` |
| Action | Accept |
| Protocol | All |
| Source | Any |
| Destination | Any |
| States | Established, Related |

---

### Rule 2: Allow NTP Requests
**Purpose:** Allows all devices to sync time (required for many IoT devices)

| Setting | Value |
|---------|-------|
| Type | LAN In |
| Name | `Accept All NTP Requests` |
| Action | Accept |
| Protocol | UDP |
| Source | All Local Addresses |
| Destination | Any |
| Port | 123 (NTP) |

---

### Rule 3: Allow LAN to Local Networks
**Purpose:** Allows trusted LAN devices to access all local networks

| Setting | Value |
|---------|-------|
| Type | LAN In |
| Name | `Allow LAN to Anywhere` |
| Action | Accept |
| Protocol | All |
| Source | LAN (192.168.1.0/24) |
| Destination | Local Networks |
| Port | Any |

---

### Rule 4: Block IoT from LAN
**Purpose:** Prevents IoT devices from accessing trusted devices

| Setting | Value |
|---------|-------|
| Type | LAN In |
| Name | `Block IoT from LAN` |
| Action | Drop |
| Protocol | All |
| Source | IoT (192.168.20.0/24) |
| Destination | LAN (192.168.1.0/24) |
| Port | Any |

---

### Rule 5: Block IoT from NoT
**Purpose:** Prevents IoT devices from accessing NoT network

| Setting | Value |
|---------|-------|
| Type | LAN In |
| Name | `Block IoT from NoT` |
| Action | Drop |
| Protocol | All |
| Source | IoT (192.168.20.0/24) |
| Destination | NoT (192.168.30.0/24) |
| Port | Any |

---

### Rule 6: Block NoT from All Local
**Purpose:** Prevents NoT devices from accessing any local network

| Setting | Value |
|---------|-------|
| Type | LAN In |
| Name | `Block All NoT` |
| Action | Drop |
| Protocol | All |
| Source | NoT (192.168.30.0/24) |
| Destination | All IP Addresses |
| Port | Any |

---

### Rule 7: Block Inter-VLAN Traffic (Catch-All)
**Purpose:** Blocks any remaining cross-VLAN traffic not explicitly allowed

| Setting | Value |
|---------|-------|
| Type | LAN In |
| Name | `Block inter-VLAN Traffic` |
| Action | Drop |
| Protocol | All |
| Source | Local Networks |
| Destination | Local Networks |
| Port | Any |

---

### Rule 8: Block IoT from Gateway
**Purpose:** Prevents IoT devices from accessing the router admin interface

| Setting | Value |
|---------|-------|
| Type | LAN Local |
| Name | `Block IoT to Gateways` |
| Action | Drop |
| Protocol | All |
| Source | IoT (192.168.20.0/24) |
| Destination | Gateway IP Addresses |
| Port | Any |

---

### Rule 9: Block NoT from Gateway
**Purpose:** Prevents NoT devices from accessing the router admin interface

| Setting | Value |
|---------|-------|
| Type | LAN Local |
| Name | `Block NoT to Gateway` |
| Action | Drop |
| Protocol | All |
| Source | NoT (192.168.30.0/24) |
| Destination | Gateway IP Addresses |
| Port | Any |

---

### Rule 10: Block Guests from Gateway
**Purpose:** Prevents guest devices from accessing the router admin interface

| Setting | Value |
|---------|-------|
| Type | LAN Local |
| Name | `Block Guests to GW` |
| Action | Drop |
| Protocol | All |
| Source | Guest Network (if separate) |
| Destination | Gateway IP Addresses |
| Port | Any |

---

## Part 4: Security Settings (IPS/IDS)

Navigate to **Settings** → **CyberSecure** (or **Security** → **Internet Threat Management**)

### Enable Intrusion Prevention System (IPS)

| Setting | Recommended Value |
|---------|-------------------|
| **Intrusion Prevention** | ON |
| **Detection Mode** | Notify and Block |
| **Selected Networks** | LAN, NoT, IoT (all networks) |

### Enable Detection Categories

| Category | Recommendation |
|----------|----------------|
| Botnets and Threat Intelligence | Enable ALL (5/5) |
| Viruses, Malware and Spyware | Enable ALL (4/4) |
| Hacking and Exploits | Enable ALL (5/5) |
| Peer to Peer and Dark Web | Enable ALL (3/3) |
| Attacks and Reconnaissance | Enable ALL (7/7) |
| Protocol Vulnerabilities | Enable ALL (12/12) |

### Additional Security Settings

| Setting | Recommended Value |
|---------|-------------------|
| Encrypted DNS | Auto or Predefined (Cloudflare/Quad9) |
| Block Page | Enabled |
| Identification | Device and Traffic |

---

## Part 5: Additional Recommendations

### Disable UPnP
1. Go to **Settings** → **Security** or **Internet**
2. Find **UPnP** setting
3. Turn it **OFF**

### Check for Firmware Updates
1. Go to **Settings** → **System** → **Updates**
2. Update all UniFi devices to latest firmware

### Enable 2FA on UniFi Account
1. Go to https://account.ui.com
2. Enable two-factor authentication

### Review Admin Users
1. Go to **Settings** → **Admins**
2. Remove any unused accounts
3. Ensure all admins have strong passwords and 2FA

---

## Optional Rules

### Allow Chromecast/AirPlay (if needed)
If you need casting to work across VLANs:

| Setting | Value |
|---------|-------|
| Type | LAN In |
| Name | `Allow Chromecast` |
| Action | Accept |
| Protocol | All |
| Source | Chromecast Group |
| Destination | Chromecast Group |

**Note:** You'll need to create a device group containing your Chromecast/Apple TV devices.

### Allow Home Assistant / MQTT (if using)
If you have Home Assistant on your LAN that needs to communicate with IoT devices:

| Setting | Value |
|---------|-------|
| Type | LAN In |
| Name | `Allow IoT to Home Assistant` |
| Action | Accept |
| Protocol | TCP |
| Source | IoT (192.168.20.0/24) |
| Destination | Home Assistant IP |
| Port | 8123, 1883 (MQTT) |

---

## Verification

After setup, verify your configuration:

### Test 1: IoT Internet Access
- Connect a device to IoT WiFi
- Confirm it can access the internet
- Confirm it receives an IP in 192.168.20.x range

### Test 2: IoT Isolation
- From an IoT device, try to ping 192.168.1.1 (LAN gateway)
- It should fail/timeout

### Test 3: LAN to IoT Access
- From a LAN device, try to ping an IoT device
- It should succeed (LAN can access IoT, but not vice versa)

### Test 4: Router Admin Access
- From an IoT device, try to access the router admin page
- It should fail

---

## Network Diagram

```
Internet
    │
    ▼
┌─────────────────────┐
│   Modem/Gateway     │
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│  UniFi Dream Machine│
│        Pro          │
│                     │
│  ┌───────────────┐  │
│  │ LAN (VLAN 1)  │  │──► Trusted devices (computers, phones)
│  │ 192.168.1.0/24│  │
│  └───────────────┘  │
│                     │
│  ┌───────────────┐  │
│  │ IoT (VLAN 20) │  │──► Smart home (lights, sensors, speakers)
│  │192.168.20.0/24│  │
│  └───────────────┘  │
│                     │
│  ┌───────────────┐  │
│  │ NoT (VLAN 30) │  │──► Cameras, untrusted appliances
│  │192.168.30.0/24│  │
│  └───────────────┘  │
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│   UniFi Access      │
│      Points         │
│                     │
│  • MainWiFi (LAN)   │
│  • IoTWiFi (VLAN 20)│
│  • GuestWiFi        │
└─────────────────────┘
```

---

## Troubleshooting

### Device can't connect to WiFi
- Verify WiFi network is broadcasting
- Check if device supports the WiFi band (2.4 GHz vs 5 GHz)
- Verify password is correct

### IoT device not working properly
- Some IoT devices need to discover devices on other networks
- May need to create specific allow rules for that device
- Check if device needs UPnP (not recommended, but some devices require it)

### Can't access router admin
- Make sure you're connected to the LAN network, not IoT
- Verify you haven't blocked your own access

### Chromecast/AirPlay not working
- Casting requires mDNS/Bonjour across VLANs
- Add specific allow rules for casting devices
- Consider enabling IGMP snooping

---

## Summary

This configuration provides:

✅ **Network Segmentation** - Separate VLANs for different trust levels

✅ **IoT Isolation** - Smart devices can't access your computers or router

✅ **Intrusion Prevention** - Active blocking of known threats

✅ **Defense in Depth** - Multiple layers of security

✅ **Internet Access** - All devices can still reach the internet

---

*Guide created for UniFi Network. Adjust network names, IPs, and specific rules based on your environment.*
