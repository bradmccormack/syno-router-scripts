#!/bin/sh
#
# OpenVPN server installer script for Synology routers
# Compatible with Entware (soft-float) and Ubuntu chroot (hard-float)
# Tested only on RT2600ac in Wireless Router mode
#
# 2018, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#

vers=2.4 # 2018.05.19
easyrsa_vers=3.0.4 # For download
syno_routers="RT2600ac RT1900ac" # Supported models

error()
{
  printf "\e[2J\e[1;1H\ec\n \e[1;31m"

  case $1 in
    1)
      printf "Permission denied!\n Please try again with 'root' user, instead of '$(whoami)'."
      ;;
    2)
      printf "Sorry, but failed to detect any compatible Synology router!"
      ;;
    3)
      printf "Sorry, but failed to detect the internet connection!"
      ;;
    4)
      printf "Sorry, but failed to detect any existing Entware environment!\n Please run 'sh entware_install.sh' command."
      ;;
    5)
      printf "Sorry, but failed to detect any existing Ubuntu chroot environment!\n Please run 'sh ubuntu_install.sh' command."
      ;;
    6)
      printf "The OpenVPN is already installed!"
      ;;
    7)
      printf "The OpenVPN is already installed on Ubuntu!\n Secondary installation is not a good idea."
      ;;
    8)
      printf "The OpenVPN is already installed on Entware!\n Secondary installation is not a good idea."
      ;;
    9)
      printf "Sorry, but not enough free space to install the OpenVPN!"
      ;;
    10)
      printf "Sorry, but failed to detect any existing OpenVPN installation!"
  esac

  printf "\n\n The script is ended without any effect!\e[0m\n\n"
  exit $1
} >&2

errd()
{
  printf "\n \e[1;31mSorry, but failed to download an essential file!\e[0m\n\n"
  exit 11
} >&2

setup()
{
  chmod 700 $1 # Security reasons
  cd $1
  wget -O easyrsa.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v$easyrsa_vers/EasyRSA-$easyrsa_vers.tgz || errd
  ersa=$(tr -dc a-zA-Z0-9 </dev/urandom | head -c 16)
  mkdir $ersa
  tar -C $ersa -xf easyrsa.tgz --strip-components 1
  rm easyrsa.tgz
  cd $ersa

  cat << EOF >vars
set_var EASYRSA_ALGO ec
set_var EASYRSA_CURVE secp384r1
set_var EASYRSA_DIGEST sha384
set_var EASYRSA_REQ_CN $(tr -dc a-zA-Z0-9 </dev/urandom | head -c 16)
EOF

  ./easyrsa init-pki
  sname=$(tr -dc a-zA-Z0-9 </dev/urandom | head -c 16)
  cname=$(tr -dc a-zA-Z0-9 </dev/urandom | head -c 16)

  if [ "${1:1:1}" = o ]
  then
    [ "${PATH:$((${#PATH}-19)):19}" = :/opt/bin:/opt/sbin ] || PATH=$PATH:/opt/bin:/opt/sbin
    ./easyrsa --batch build-ca nopass
    ./easyrsa build-server-full $sname nopass
    ./easyrsa build-client-full $cname nopass
    EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
    /opt/sbin/openvpn --genkey --secret /opt/etc/openvpn/tls-crypt.key
  else chroot /ubuntu /bin/sh -c "cd /etc/openvpn/$ersa ; ./easyrsa --batch build-ca nopass ; ./easyrsa build-server-full $sname nopass ; ./easyrsa build-client-full $cname nopass ; EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl ; openvpn --genkey --secret /etc/openvpn/tls-crypt.key"
  fi

  mv pki/ca.crt pki/issued/$cname.crt pki/private/$cname.key pki/crl.pem $1
  mv pki/issued/$sname.crt ../server.crt
  mv pki/private/$sname.key ../server.key
  cd ..
  rm -rf $ersa

  cat << EOF >server.conf
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh none
topology subnet
server 10.8.0.0 255.255.255.0
client-to-client
duplicate-cn
keepalive 10 120
script-security 2
tmp-dir /dev/shm
auth-user-pass-verify auth.sh via-file
username-as-common-name
client-connect log.sh
crl-verify crl.pem
tls-crypt tls-crypt.key 0
ecdh-curve secp384r1
auth SHA384
ncp-disable
tls-server
tls-version-min 1.2
tls-cipher TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384
cipher AES-128-GCM
compress lz4-v2
max-clients 10
connect-freq 1 10
persist-key
persist-tun
fast-io
status status.log
log-append $2
verb 3
mute 10
explicit-exit-notify
EOF

  ddns=$(grep -m 1 hostname= /etc/ddns.conf | cut -d = -f 2)
  [ "$ddns" ] || ddns=$(wget -qO- v4.ifconfig.co) # Using external IP address as a backup

  cat << EOF >client.ovpn
client
dev tun
proto udp
remote $ddns 1194
connect-retry 2 300
resolv-retry 60
float
nobind
;route 192.168.0.0 255.255.0.0 vpn_gateway
;route 10.0.0.0 255.0.0.0 vpn_gateway
;redirect-gateway def1 bypass-dhcp
$(for ip in $(grep ^nameserver /etc/resolv.conf | egrep -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}") ; do echo ";dhcp-option DNS $ip" ; done)
persist-key
persist-tun
mute-replay-warnings
remote-cert-tls server
verify-x509-name $sname name
auth-user-pass
auth SHA384
tls-client
tls-version-min 1.2
tls-cipher TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384
cipher AES-128-GCM
compress lz4-v2
;setenv opt block-outside-dns
verb 3
explicit-exit-notify
<ca>
$(cat ca.crt)
</ca>
<cert>
$(cat $cname.crt)
</cert>
<key>
$(cat $cname.key)
</key>
<tls-crypt>
$(cat tls-crypt.key)
</tls-crypt>
EOF

  rm $cname.crt $cname.key

  if [ "${1:1:1}" = o ]
  then
    ln -sf server.conf openvpn.conf # Entware hard-coded to 'openvpn.conf'

    cat << EOF >auth.sh # 'mkpasswd' is missing from 'whois' package
#!/bin/sh

usr="\$(sed -n 1p \$1)"

grep -q "^\$usr\$" auth.users && {
    pwd="\$(grep "^\$usr:\\\$6\\\\$" /etc/shadow | cut -d : -f 2)"
    [ "\$pwd" ] && [ "\$(/usr/bin/python -c "import crypt ; print(crypt.crypt('\$(sed -n 2p \$1)', '\\\$6\\\$' + '\${pwd:3:8}'))")" = "\\\$6\\\$\${pwd:3}" ] && exit 0
  }

exit 1
EOF
  else cat << EOF >auth.sh
#!/bin/bash

usr="\$(sed -n 1p \$1)"

grep -q "^\$usr\$" auth.users && {
    pwd="\$(grep "^\$usr:\\\$6\\\\$" /mnt/Synology/etc/shadow | cut -d : -f 2)"
    [ "\$pwd" ] && [ "\$(mkpasswd -m sha-512 -S "\${pwd:3:8}" "\$(sed -n 2p \$1)")" = "\\\$6\\\$\${pwd:3}" ] && exit 0
  }

exit 1
EOF
  fi

  cat << EOF >log.sh # Check and reduce the log file size during client connections
#!/bin/sh

log="\$(grep ^log-append server.conf | cut -d " " -f 2- | sed -e "s/^\\"\(.*\)\\"\$/\\1/" -e "s/^'\(.*\)'\$/\\1/")"

[ -s "\$log" ] && [ \$(wc -l "\$log" | cut -d " " -f 1) -ge 10000 ] && {
    tail -n 8000 "\$log" >"\$log.tmp"
    cat "\$log.tmp" >"\$log"
    rm "\$log.tmp"
  }

exit 0
EOF

  [ "$3" ] || {
      users
      touch $odir/openvpn.log # OpenVPN would create the log without read permissions
    }

  chmod +x auth.sh log.sh
  sed -e "/^;ro/d" -e "s/^;//" client.ovpn >$odir/${rname}_all-traffic.ovpn
  sed -e "/^;re/d" -e "/^;dh/d" -e "/^;se/d" -e "s/^;//" client.ovpn >$odir/${rname}_local-traffic.ovpn
}

users()
{
  ulst=""

  while read l
  do case ${l:0:5} in
      admin|guest)
        ;;
      *)
        printf "$l" | grep -q :\\$6\$ && ulst="$ulst${l%%:*}\n"
    esac
  done </etc/shadow

  [ "$ulst" ] && {
      alst="admin\n"

      while :
      do
        printf "\e[2J\e[1;1H\ec\n \e[1mUsers who will be able to connect using an OpenVPN client:\e[0m\n\n"

        while read u
        do printf "  $u\n"
        done << EOF
$(printf "$alst")
EOF

        printf "\n \e[1mAdd or remove a user:\e[0m\n\n"
        cnt=0

        while read u
        do printf "  \e[1m$((++cnt))\e[0m - $u\n"
        done << EOF
$(printf "$ulst")
EOF

        printf "\n \e[1m0\e[0m - Continue (default)\n\n"

        while :
        do
          read -p "Select an option [0-$cnt]: " o

          case $o in
            [1-$cnt])
              usr="$(printf "$ulst" | sed -n ${o}p)"
              printf "$alst" | grep -q "^$usr$" && alst="$(printf "$alst" | sed "/^$usr$/d")\n" || alst="$alst$usr\n"
              break
              ;;
            ""|0)
              printf "$alst" >auth.users
              cred="an allowed user's"
              return 0
          esac
        done
      done
    }

  echo admin >auth.users
  cred="the admin's"
  return 1
}

okill()
{
  [ "$(pidof openvpn)" ] && {
      killall openvpn 2>/dev/null
      cnt=10

      while [ "$(pidof openvpn)" ] && [ $((cnt--)) -ne 0 ]
      do sleep 1s
      done

      [ "$(pidof openvpn)" ] && killall -9 openvpn
    }
}

[ $(id -u) -eq 0 ] || error 1
rname="$(head -c 8 /proc/sys/kernel/syno_hw_version 2>/dev/null)"
printf "$rname" | egrep -q $(printf "$syno_routers" | sed "s/ /|/g") || error 2
ping -c 1 www.google.com >/dev/null 2>&1 || error 3
printf "\e[2J\e[1;1H\ec\n\e[1mOpenVPN server installer script for Synology routers v$vers by Kendek\n\n 1\e[0m - Install through the existing Entware environment\n \e[1m2\e[0m - Install through the existing Ubuntu chroot environment\n \e[1m3\e[0m - Renew the existing certificates, keys and config files\n \e[1m4\e[0m - Re-set the existing list of allowed users\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-4]: " o

  case $o in
    1)
      [ -f /opt/bin/opkg ] || error 4
      [ -f /opt/sbin/openvpn ] && error 6
      [ -f /ubuntu/usr/sbin/openvpn ] && error 7
      [ $(df /opt | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check
      /opt/bin/opkg update
      /opt/bin/opkg upgrade
      /opt/bin/opkg install ca-certificates coreutils-mktemp openvpn-openssl
      [ -f /opt/sbin/openvpn ] || errd
      odir=$(readlink /opt | sed "s/\/entware//")
      setup /opt/etc/openvpn /opt/../openvpn.log
      lsmod | grep -q ^tun || insmod /lib/modules/tun.ko
      /opt/etc/init.d/S20openvpn start
      break
      ;;
    2)
      [ -f /ubuntu/usr/bin/apt ] || error 5
      [ -f /ubuntu/usr/sbin/openvpn ] && error 6
      [ -f /opt/sbin/openvpn ] && error 8
      [ $(df /ubuntu | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check
      chroot /ubuntu /usr/bin/apt update 2>/dev/null
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated dist-upgrade -y
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated install ca-certificates kmod openvpn whois --no-install-recommends -y
      chroot /ubuntu /usr/bin/apt clean
      [ -f /ubuntu/usr/sbin/openvpn ] || errd
      odir=$(readlink /ubuntu | sed "s/\/ubuntu//")
      setup /ubuntu/etc/openvpn /mnt/HDD/openvpn.log

      cat << EOF >/ubuntu/autostart/openvpn.sh
#!/bin/sh

[ "\$(pidof openvpn)" ] || {
    lsmod | grep -q ^tun || insmod /mnt/Synology/lib/modules/tun.ko
    service openvpn start
  }
EOF

      chmod +x /ubuntu/autostart/openvpn.sh
      chroot /ubuntu /autostart/openvpn.sh >/dev/null 2>&1
      break
      ;;
    3)
      if [ -d /opt/etc/openvpn ] && [ -f /opt/etc/init.d/S20openvpn ]
      then
        okill
        odir=$(readlink /opt | sed "s/\/entware//")
        setup /opt/etc/openvpn /opt/../openvpn.log -
        /opt/etc/init.d/S20openvpn start
      elif [ -d /ubuntu/etc/openvpn ] && [ -f /ubuntu/autostart/openvpn.sh ]
      then
        okill
        odir=$(readlink /ubuntu | sed "s/\/ubuntu//")
        setup /ubuntu/etc/openvpn /mnt/HDD/openvpn.log -
        [ -x /ubuntu/autostart/openvpn.sh ] && chroot /ubuntu /autostart/openvpn.sh >/dev/null 2>&1
      else error 10
      fi

      sync
      printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The new .ovpn files are successfully created in the '$odir'.\n\n all-traffic:   redirect all traffic through VPN\n local-traffic: LAN access only, the internet traffic will not be redirected\e[0m\n\n"
      exit 0
      ;;
    4)
      if [ -d /opt/etc/openvpn ] && [ -f /opt/etc/init.d/S20openvpn ]
      then cd /opt/etc/openvpn
      elif [ -d /ubuntu/etc/openvpn ] && [ -f /ubuntu/autostart/openvpn.sh ]
      then cd /ubuntu/etc/openvpn
      else error 10
      fi

      users
      rv=$?
      sync

      [ $rv -eq 1 ] && printf "\e[2J\e[1;1H\ec\n \e[1;31mThere are no created users in the SRM.\e[0m\n\n \e[1mThe default 'admin' is the only who will be able to connect using an OpenVPN\n client.\e[0m\n\n" \
                    || printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The allowed users list has been successfully changed.\n Use an allowed user's credentials for client authentication.\e[0m\n\n"

      exit 0
      ;;
    ""|0)
      echo
      exit 0
  esac
done

sync
printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The .ovpn files are successfully created in the '$odir'.\n Use $cred credentials for client authentication.\n\n all-traffic:   redirect all traffic through VPN\n local-traffic: LAN access only, the internet traffic will not be redirected\n\n Please set the following firewall rules in the SRM:\n\n  Protocol        Source IP        Source port   Dest. IP   Dest. port   Action\n ===============================================================================\n    UDP              All               All         SRM         1194      Allow\n  TCP/UDP   10.8.0.0/255.255.255.0     All         All         All       Allow\n\n Note that you may not be able to connect if the router is behind a\n carrier-grade NAT!\e[0m\n\n"
