#!/bin/bash
#
# Author:   Payne Zheng <zzuai520@live.com>
# Date:     2018-06-11 14:29:58
# Location: Shenzhen
# Desc:     DO THE RIGHT THING
#

# Ensure to be root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Ensure there are the prerequisites
for i in openvpn unzip wget sed; do
  which $i > /dev/null
  if [ "$?" -ne 0 ]; then
    echo "Miss $i"
    yum install $i -y
    #exit
  fi
done

base_path=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


printf "\n################## Server informations ##################\n"

read -p "Server Hostname/IP: " ip_server

read -p "OpenVPN protocol (tcp or udp) [tcp]: " openvpn_proto

if [[ -z $openvpn_proto ]]; then
  openvpn_proto="tcp"
fi

read -p "Port [443]: " server_port

if [[ -z $server_port ]]; then
  server_port="443"
fi

printf "\n################## Certificates informations ##################\n"

read -p "Key size (1024, 2048 or 4096) [2048]: " key_size

read -p "Root certificate expiration (in days) [3650]: " ca_expire

read -p "Certificate expiration (in days) [3650]: " cert_expire

read -p "Country Name (2 letter code) [US]: " cert_country

read -p "State or Province Name (full name) [California]: " cert_province

read -p "Locality Name (eg, city) [San Francisco]: " cert_city

read -p "Organization Name (eg, company) [Copyleft Certificate Co]: " cert_org

read -p "Organizational Unit Name (eg, section) [My Organizational Unit]: " cert_ou

read -p "Email Address [me@example.net]: " cert_email

read -p "Common Name (eg, your name or your server's hostname) [ChangeMe]: " key_cn


printf "\n################## Creating the certificates ##################\n"

EASYRSA_RELEASES=( $(
  curl -s https://api.github.com/repos/OpenVPN/easy-rsa/releases | \
  grep 'tag_name' | \
  grep -E '3(\.[0-9]+)+' | \
  awk '{ print $2 }' | \
  sed 's/[,|"|v]//g'
) )
EASYRSA_LATEST=${EASYRSA_RELEASES[0]}

# Get the rsa keys
wget -q https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_LATEST}/EasyRSA-${EASYRSA_LATEST}.tgz
tar -xaf EasyRSA-${EASYRSA_LATEST}.tgz
mv EasyRSA-${EASYRSA_LATEST} /etc/openvpn/easy-rsa
rm -r EasyRSA-${EASYRSA_LATEST}.tgz
cd /etc/openvpn/easy-rsa

if [[ ! -z $key_size ]]; then
  export EASYRSA_KEY_SIZE=$key_size
fi
if [[ ! -z $ca_expire ]]; then
  export EASYRSA_CA_EXPIRE=$ca_expire
fi
if [[ ! -z $cert_expire ]]; then
  export EASYRSA_CERT_EXPIRE=$cert_expire
fi
if [[ ! -z $cert_country ]]; then
  export EASYRSA_REQ_COUNTRY=$cert_country
fi
if [[ ! -z $cert_province ]]; then
  export EASYRSA_REQ_PROVINCE=$cert_province
fi
if [[ ! -z $cert_city ]]; then
  export EASYRSA_REQ_CITY=$cert_city
fi
if [[ ! -z $cert_org ]]; then
  export EASYRSA_REQ_ORG=$cert_org
fi
if [[ ! -z $cert_ou ]]; then
  export EASYRSA_REQ_OU=$cert_ou
fi
if [[ ! -z $cert_email ]]; then
  export EASYRSA_REQ_EMAIL=$cert_email
fi
if [[ ! -z $key_cn ]]; then
  export EASYRSA_REQ_CN=$key_cn
fi

# Init PKI dirs and build CA certs
./easyrsa init-pki
./easyrsa build-ca nopass
# Generate Diffie-Hellman parameters
./easyrsa gen-dh
# Genrate server keypair
./easyrsa build-server-full server nopass

# Generate shared-secret for TLS Authentication
openvpn --genkey --secret pki/ta.key


printf "\n################## Setup OpenVPN ##################\n"

# Copy certificates and the server configuration in the openvpn directory
cp /etc/openvpn/easy-rsa/pki/{ca.crt,ta.key,issued/server.crt,private/server.key,dh.pem} "/etc/openvpn/"
#cp "$base_path/installation/server.conf" "/etc/openvpn/"
cat > /etc/openvpn/server.conf <<EOF
## GENERAL ##

# TCP or UDP, port 443, tunneling
mode server
proto tcp
port 443
dev tun

## KEY, CERTS AND NETWORK CONFIGURATION ##
# Identity
ca ca.crt
# Public key
cert server.crt
# Private key
key server.key
# Symmetric encryption
dh dh.pem
# Improve security (DDOS, port flooding...)
# 0 for the server, 1 for the client
tls-auth ta.key 0
# Encryption protocol
cipher AES-256-CBC

# Network
# Subnetwork, the server will be the 10.8.0.1 and clients will take the other ips
server 10.8.0.0 255.255.255.0

# Redirect all IP network traffic originating on client machines to pass through the OpenVPN server
push "redirect-gateway def1"

# Alternatives DNS (FDN)
push "dhcp-option DNS 80.67.169.12"
push "dhcp-option DNS 80.67.169.40"

# (OpenDNS)
# push "dhcp-option DNS 208.67.222.222"
# push "dhcp-option DNS 208.67.220.220"

# (Google)
# push "dhcp-option DNS 8.8.8.8"
# push "dhcp-option DNS 8.8.4.4"

# Ping every 10 seconds and if after 120 seconds the client doesn't respond we disconnect
keepalive 10 120
# Regenerate key each 5 hours (disconnect the client)
reneg-sec 18000

## SECURITY ##

# Downgrade privileges of the daemon
user nobody
group nogroup

# Persist keys (because we are nobody, so we couldn't read them again)
persist-key
# Don't close and re open TUN/TAP device
persist-tun
# Enable compression
comp-lzo

## LOG ##

# Verbosity
# 3/4 for a normal utilisation
verb 3
# Max 20 messages of the same category
mute 20
# Log gile where we put the clients status
status openvpn-status.log
# Log file
log-append /var/log/openvpn.log
# Configuration directory of the clients
client-config-dir ccd

## PASS ##

# Allow running external scripts with password in ENV variables
script-security 3

# Use the authenticated username as the common name, rather than the common name from the client cert
username-as-common-name
# Client certificate is not required 
verify-client-cert none
# Use the connection script when a user wants to login
auth-user-pass-verify scripts/login.sh via-env
# Maximum of clients
max-clients 50
# Run this scripts when the client connects/disconnects
client-connect scripts/connect.sh
client-disconnect scripts/disconnect.sh
EOF

mkdir "/etc/openvpn/ccd"
sed -i "s/port 443/port $server_port/" "/etc/openvpn/server.conf"

if [ $openvpn_proto = "udp" ]; then
  sed -i "s/proto tcp/proto $openvpn_proto/" "/etc/openvpn/server.conf"
fi

nobody_group=$(id -ng nobody)
sed -i "s/group nogroup/group $nobody_group/" "/etc/openvpn/server.conf"

printf "\n################## Setup firewall ##################\n"

# Make ip forwading and make it persistent
echo 1 > "/proc/sys/net/ipv4/ip_forward"
echo "net.ipv4.ip_forward = 1" >> "/etc/sysctl.conf"

# Get primary NIC device name
primary_nic=`route | grep '^default' | grep -o '[^ ]*$'`

# Iptable rules
iptables -I FORWARD -i tun0 -j ACCEPT
iptables -I FORWARD -o tun0 -j ACCEPT
iptables -I OUTPUT -o tun0 -j ACCEPT

iptables -A FORWARD -i tun0 -o $primary_nic -j ACCEPT
iptables -t nat -A POSTROUTING -o $primary_nic -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $primary_nic -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.8.0.2/24 -o $primary_nic -j MASQUERADE
