#!/bin/bash

echo "Starting VPN server..."
/opt/src/run.sh "$@" &
VPN_PID=$!

echo "Waiting for configs to generate..."
sleep 10

echo "Applying Windows L2TP fix..."
printf "require-mschap-v2\nrefuse-pap\nrefuse-chap\nrefuse-mschap\nnodeflate\nnobsdcomp\nmtu 1280\nmru 1280\n" > /etc/ppp/options.xl2tpd
killall xl2tpd
xl2tpd

echo "Applying Android IKEv2 fix..."
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

echo "VPN is ready (Windows + Android fixes applied)"

wait $VPN_PID
