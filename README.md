# Docker IPsec VPN Fixes (Windows L2TP & Android IKEv2)

Fixes common issues with Docker IPsec VPN (`hwdsl2/ipsec-vpn-server`), including Windows L2TP connection drops and Android IKEv2/IPSec PSK failures.

Covers MPPE issues, leftid mismatch, and working server-side configurations, plus a persistent automated solution.

---

## Problem Overview

### Windows (L2TP/IPsec)

- Requires MPPE-128 encryption
- Many kernels lack `ppp_mppe`
- Server cannot satisfy Windows requirements

Result: connection drops immediately

### Android (IKEv2/IPsec)

- L2TP not supported on modern Android
- Default container:
  - Requires certificates
  - Uses internal Docker IP (e.g. 172.17.0.2)

Android expects a public identity and rejects mismatches

Result: connection fails silently

---

## Prerequisites

- `YOUR_CONTAINER_NAME` (`docker ps`)
- `YOUR_PUBLIC_IP_OR_DOMAIN`
- `YOUR_PSK`

---

# Manual Fixes

## Fix 1: Windows L2TP/IPsec Connection Drop

### Update Server Configuration

```bash
docker exec -it YOUR_CONTAINER_NAME sh -c 'printf "require-mschap-v2\nrefuse-pap\nrefuse-chap\nrefuse-mschap\nnodeflate\nnobsdcomp\nmtu 1280\nmru 1280\n" > /etc/ppp/options.xl2tpd'
```

### Restart Service

```bash
docker exec -it YOUR_CONTAINER_NAME killall xl2tpd
```

### Configure Windows Client

- Run `ncpa.cpl`
- VPN Properties → Security
- Data encryption: Optional
- Protocols: MS-CHAP v2 only

---

## Fix 2: Android IKEv2/IPsec PSK Connection Fix

### Rewrite IKEv2 Configuration

```bash
docker exec -it YOUR_CONTAINER_NAME sh -c 'cat > /etc/ipsec.d/ikev2.conf <<EOF
conn ikev2-psk
  auto=add
  ikev2=insist
  rekey=no
  pfs=no
  encapsulation=yes
  left=%defaultroute
  leftid=YOUR_PUBLIC_IP_OR_DOMAIN
  leftsubnet=0.0.0.0/0
  right=%any
  rightaddresspool=192.168.43.10-192.168.43.250
  authby=secret
  modecfgdns="8.8.8.8 8.8.4.4"
  dpddelay=30
  retransmit-timeout=300s
  ike=aes256-sha2,aes128-sha2,aes256-sha1,aes128-sha1
  phase2alg=aes_gcm-null,aes128-sha1,aes256-sha1,aes128-sha2,aes256-sha2
EOF'
```

### Restart IPsec

```bash
docker exec -it YOUR_CONTAINER_NAME ipsec restart
```

### Android Client Setup

- Type: IKEv2/IPSec PSK
- Server: YOUR_PUBLIC_IP_OR_DOMAIN
- Identifier: SAME as server
- PSK: YOUR_PSK

---

# Persistent Automated Fix (Recommended)

The `hwdsl2/ipsec-vpn-server` image regenerates configs on every restart, overwriting manual fixes.

This solution injects a wrapper script to apply fixes automatically at startup.

---

## Project Structure

```
.
├── Dockerfile
├── docker-compose.yml
├── apply-fixes.sh
├── vpn.env
└── README.md
```

---

## Step 1: Wrapper Script (apply-fixes.sh)

```bash
#!/bin/bash

/opt/src/run.sh "$@" &
VPN_PID=$!

sleep 10

# Windows fix
printf "require-mschap-v2\nrefuse-pap\nrefuse-chap\nrefuse-mschap\nnodeflate\nnobsdcomp\nmtu 1280\nmru 1280\n" > /etc/ppp/options.xl2tpd
killall xl2tpd
xl2tpd

# Android fix
TARGET_IP=${VPN_PUBLIC_IP:-"127.0.0.1"}

cat > /etc/ipsec.d/ikev2.conf <<EOF
conn ikev2-psk
  auto=add
  ikev2=insist
  rekey=no
  pfs=no
  encapsulation=yes
  left=%defaultroute
  leftid=$TARGET_IP
  leftsubnet=0.0.0.0/0
  right=%any
  rightaddresspool=192.168.43.10-192.168.43.250
  authby=secret
  modecfgdns="8.8.8.8 8.8.4.4"
  dpddelay=30
  retransmit-timeout=300s
  ike=aes256-sha2,aes128-sha2,aes256-sha1,aes128-sha1
  phase2alg=aes_gcm-null,aes128-sha1,aes256-sha1,aes128-sha2,aes256-sha2
EOF

ipsec restart

wait $VPN_PID
```

---

## Step 2: Dockerfile

```dockerfile
FROM hwdsl2/ipsec-vpn-server:latest

COPY apply-fixes.sh /apply-fixes.sh
RUN chmod +x /apply-fixes.sh

CMD ["/apply-fixes.sh"]
```

---

## Step 3: docker-compose.yml

```yaml
services:
  ipsec-vpn-server:
    build: .
    container_name: ipsec-vpn-server
    restart: always
    env_file:
      - ./vpn.env
    ports:
      - "500:500/udp"
      - "4500:4500/udp"
    privileged: true
    cap_add:
      - NET_ADMIN
    volumes:
      - /lib/modules:/lib/modules:ro
```

---

## Step 4: Environment File

```env
VPN_IPSEC_PSK=your_psk
VPN_USER=user
VPN_PASSWORD=password
VPN_PUBLIC_IP=your_ip_or_domain
```

---

## Usage

```bash
git clone https://github.com/yourusername/docker-ipsec-vpn-fixes.git
cd docker-ipsec-vpn-fixes
docker compose up -d --build
```

---

## Apple Devices

Works without modification using standard L2TP/IPsec settings

---

## Summary

| Platform | Issue | Solution |
|----------|------|----------|
| Windows  | MPPE required | Adjust PPP config |
| Android  | Identity mismatch | Rewrite IKEv2 config |
| All      | Config resets | Use wrapper script |

---

## Keywords

docker ipsec vpn, hwdsl2 vpn, ipsec vpn docker, l2tp windows vpn fix, ikev2 android vpn fix, vpn not connecting docker

