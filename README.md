# Docker IPsec VPN Fixes for Windows and Android

If you are running a Dockerized IPsec VPN server (such as `hwdsl2/ipsec-vpn-server`) and your Windows or Android devices fail to connect, the issue is usually not misconfiguration on your part. It comes from how these operating systems interact with the default Docker setup.

This guide explains the root causes and provides exact server-side fixes.

---

## Problem Overview

### Windows (L2TP/IPsec)

- Windows requires an internal encryption layer called MPPE-128.
- Many VPS kernels do not include the `ppp_mppe` module.
- As a result, the VPN server cannot satisfy Windows requirements.

Result: the connection drops immediately.

### Android (IKEv2)

- Modern Android versions no longer support L2TP.
- IKEv2 must be used instead.
- Default Docker configuration:
  - Requires certificate authentication
  - Uses internal Docker IP (for example 172.17.0.2)

Android expects a public identity. When it detects a mismatch, it rejects the connection silently.

Result: connection fails without a clear error.

---

## Prerequisites

Before applying the fixes, collect the following:

- `YOUR_CONTAINER_NAME` (use `docker ps`)
- `YOUR_PUBLIC_IP_OR_DOMAIN` (for example `123.123.123.123` or `example.duckdns.org`)
- `YOUR_PSK` (pre-shared key)

---

# Fix 1: Windows (L2TP/IPsec)

## Step 1: Update Server Configuration

```bash
docker exec -it YOUR_CONTAINER_NAME sh -c 'printf "require-mschap-v2\nrefuse-pap\nrefuse-chap\nrefuse-mschap\nnodeflate\nnobsdcomp\nmtu 1280\nmru 1280\n" > /etc/ppp/options.xl2tpd'
```

## Step 2: Restart Service

```bash
docker exec -it YOUR_CONTAINER_NAME killall xl2tpd
```

## Step 3: Configure Windows Client

1. Press Win + R and run `ncpa.cpl`
2. Right-click your VPN connection and open Properties
3. Open the Security tab
4. Apply the following settings:
   - Data encryption: Optional encryption
   - Allowed protocols: Microsoft CHAP Version 2 (MS-CHAP v2) only

---

# Fix 2: Android (IKEv2/IPsec PSK)

## Step 1: Rewrite IKEv2 Configuration

Replace `YOUR_PUBLIC_IP_OR_DOMAIN` before executing:

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

## Step 2: Restart IPsec

```bash
docker exec -it YOUR_CONTAINER_NAME ipsec restart
```

## Step 3: Configure Android Client

1. Open Settings → Network & Internet → VPN
2. Add a new VPN profile

Use the following values:

- Type: IKEv2/IPSec PSK
- Server address: YOUR_PUBLIC_IP_OR_DOMAIN
- IPSec identifier: same as server address
- Pre-shared key: YOUR_PSK

Note: The identifier must exactly match `leftid` from the configuration.

---

## Apple Devices

iOS, iPadOS, and macOS typically support L2TP/IPsec without strict MPPE enforcement.

They usually work with:

- Server address
- Username
- Password
- PSK (entered as “Secret”)

No additional changes are required.

---

## Summary

| Platform | Issue                   | Solution                                        |
|----------|-------------------------|-------------------------------------------------|
| Windows  | MPPE requirement        | Adjust PPP config and allow optional encryption |
| Android  | IKEv2 identity mismatch | Rewrite config and set public identifier        |

---

## Additional Checks

If connections still fail, verify:

- Firewall allows UDP ports 500, 4500, and 1701
- Correct PSK is used
- Server address and identifier match exactly
- Container is running and restarted after changes

