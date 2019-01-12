#!/bin/sh
#
# WireGuard server installer script for Linux 4.4.60 based Synology routers
# Compatible with Entware (soft-float) and Ubuntu chroot (hard-float)
# Tested only on RT2600ac in Wireless Router mode
#
# 2019, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#
#
# NOTE: only IPv4 since the router has limited IPv6 NAT support
#

vers=1.0 # 2019.01.12
syno_routers="MR2200ac RT2600ac" # Supported models, the RT1900ac has an older kernel

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
      printf "The WireGuard is already installed!"
      ;;
    7)
      printf "The WireGuard is already installed on Ubuntu!\n Secondary installation is not a good idea."
      ;;
    8)
      printf "The WireGuard is already installed on Entware!\n Secondary installation is not a good idea."
      ;;
    9)
      printf "Sorry, but not enough free space to install the WireGuard!"
      ;;
    10)
      printf "Sorry, but failed to detect any existing WireGuard installation!"
  esac

  printf "\n\n The script is ended without any effect!\e[0m\n\n"
  exit $1
} >&2

errd()
{
  printf "\n \e[1;31mSorry, but failed to download an essential file!\e[0m\n\n"
  exit 11
} >&2

get()
{
  case $1 in
    ddns)
      local ddns=$(grep -m 1 hostname= /etc/ddns.conf | cut -d = -f 2)
      [ "$ddns" ] && printf $ddns || wget -qO- v4.ifconfig.co # Using external IP address as a backup
      ;;
    dns)
      for ip in $(grep ^nameserver /etc/resolv.conf | egrep -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}") ; do printf "$ip, " ; done | sed "s/, $//g"
      ;;
    zpng)
      [ "$4" ] && rm $odir/${rname}_wg-client*.zip $odir/${rname}_wg-client*.png 2>/dev/null
      zip -j $odir/${rname}_wg-client$3 $2/${rname}.conf # Can be imported in the Android app
      qrencode -o $odir/${rname}_wg-client$3.png <$2/${rname}.conf # Can be scanned from the Android app
      rm $2/${rname}.conf
      ;;
    env)
      if [ -s /opt/lib/modules/wireguard.ko ]
      then
        [ "$2" ] && odir=$(readlink /opt | sed "s/\/entware//")
        return 0
      elif [ -s /ubuntu/usr/local/lib/modules/wireguard.ko ]
      then
        [ "$2" ] && odir=$(readlink /ubuntu | sed "s/\/ubuntu//")
        return 1
      else error 10
      fi
  esac
}

setting()
{
  wg=$1$2/wg
  cdir=$1$3/wireguard
  pkey1=$($wg genkey) pkey2=$($wg genkey)

  cat << EOF >$cdir/wg0.conf
[Interface]
PrivateKey = $pkey1
ListenPort = 51820

[Peer]
PublicKey = $(printf $pkey2 | $wg pubkey)
AllowedIPs = 10.7.0.2/32
EOF

  # Mtu 1432 because 1492 PPPoE max - 20 IPv4 header - 8 UDP header - 4 type - 4 key index - 8 nonce - 16 authentication tag
  cat << EOF >$cdir/${rname}.conf
[Interface]
PrivateKey = $pkey2
Address = 10.7.0.2/32
DNS = $(get dns)
MTU = 1432

[Peer]
Endpoint = $(get ddns):51820
PublicKey = $(printf $pkey1 | $wg pubkey)
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

  get zpng $cdir 1 $4
}

setup()
{
  wget -O $2$3/wg goo.gl/PVdfcq || errd
  chmod +x $2$3/wg
  [ -d $2$4 ] || mkdir $2$4
  wget -O $2$4/wireguard.ko goo.gl/$([ "$rname" = RT2600ac ] && printf 8mQdtn || printf rmKsWr) || errd

  if [ $1 -eq 1 ]
  then
    [ -d $2$5/wireguard ] || mkdir $2$5/wireguard
    setting $2 $3 $5
  elif lsmod | grep -q wireguard
  then
    ifconfig wg0 >/dev/null 2>&1 && ip link del wg0
    rmmod wireguard.ko
  fi
}

[ $(id -u) -eq 0 ] || error 1
rname="$(head -c 8 /proc/sys/kernel/syno_hw_version 2>/dev/null)"
printf "$rname" | egrep -q $(printf "$syno_routers" | sed "s/ /|/g") || error 2
ping -c 1 www.google.com >/dev/null 2>&1 || error 3
printf "\e[2J\e[1;1H\ec\n\e[1mWireGuard server installer script for Linux 4.4.60-based Synology routers\n%66sv$vers by Kendek\n 1\e[0m - Install through the existing Entware environment\n \e[1m2\e[0m - Install through the existing Ubuntu chroot environment\n \e[1m3\e[0m - Update the wireguard.ko kernel module and the wg utility\n \e[1m4\e[0m - Add an additional peer and create .zip and .png files\n \e[1m5\e[0m - Reinitialize the current configuration\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-5]: " o

  case $o in
    1)
      [ -f /opt/bin/opkg ] || error 4
      [ -f /opt/lib/modules/wireguard.ko ] && error 6
      [ -s /ubuntu/usr/local/lib/modules/wireguard.ko ] && error 7
      [ $(df /opt | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check
      odir=$(readlink /opt | sed "s/\/entware//")
      setup 1 /opt /bin /lib/modules /etc

      cat << EOF >/opt/etc/init.d/S50wireguard
#!/bin/sh

ENABLED=yes

[ "\$ENABLED" = no ] && {
    printf "\\n \\e[1mDisabled\\e[0m\\n\\n"
    exit 1
  }

start()
{
  ip link add wg0 type wireguard && \\
  ip addr add 10.7.0.1/24 dev wg0 && \\
  /opt/bin/wg setconf wg0 /opt/etc/wireguard/wg0.conf && \\
  ip link set wg0 up && \\
  ifconfig wg0 mtu 1432 txqueuelen 1000 && \\
  printf "\\n \\e[1mDone\\e[0m\\n\\n" >&2 || {
      printf "\\n \\e[1;31mFailed!\\e[0m\\n\\n" >&2
      exit 3
    }
}

case \$1 in
  start)
    ifconfig wg0 >/dev/null 2>&1 && printf "\\n \\e[1mAlready running!\\e[0m\\n\\n" || {
        insmod /opt/lib/modules/wireguard.ko
        start
      }
    ;;
  stop)
    ! ifconfig wg0 >/dev/null 2>&1 && printf "\\n \\e[1mAlready stopped!\\e[0m\\n\\n" || {
        ip link del wg0 && rmmod wireguard.ko && printf "\\n \\e[1mDone\\e[0m\\n\\n" >&2 || {
            printf "\\n \\e[1;31mFailed!\\e[0m\\n\\n" >&2
            exit 4
          }
      }
    ;;
  restart)
    ifconfig wg0 >/dev/null 2>&1 && ip link del wg0 || insmod /opt/lib/modules/wireguard.ko
    start
    ;;
  *)
    printf "\\n \\e[1;31mUsage: \$0 {start|stop|restart}\\e[0m\\n\\n" >&2
    exit 2
esac
EOF

      chmod +x /opt/etc/init.d/S50wireguard
      /opt/etc/init.d/S50wireguard start
      break
      ;;
    2)
      [ -f /ubuntu/usr/bin/apt ] || error 5
      [ -f /ubuntu/usr/local/lib/modules/wireguard.ko ] && error 6
      [ -s /opt/lib/modules/wireguard.ko ] && error 8
      [ $(df /ubuntu | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check

      [ -f /ubuntu/bin/ip ] && [ -f /ubuntu/bin/kmod ] && [ -f /ubuntu/sbin/ifconfig ] || {
          chroot /ubuntu /usr/bin/apt update 2>/dev/null
          chroot /ubuntu /usr/bin/apt --allow-unauthenticated dist-upgrade -y
          chroot /ubuntu /usr/bin/apt --allow-unauthenticated install iproute2 kmod net-tools --no-install-recommends -y
          chroot /ubuntu /usr/bin/apt clean
        }

      odir=$(readlink /ubuntu | sed "s/\/ubuntu//")
      setup 1 /ubuntu /usr/local/bin /usr/local/lib/modules /usr/local/etc

      cat << EOF >/ubuntu/autostart/wireguard.sh
#!/bin/sh

ifconfig wg0 || {
    insmod /usr/local/lib/modules/wireguard.ko
    ip link add wg0 type wireguard
    ip addr add 10.7.0.1/24 dev wg0
    wg setconf wg0 /usr/local/etc/wireguard/wg0.conf
    ip link set wg0 up
    ifconfig wg0 mtu 1432 txqueuelen 1000
  }
EOF

      chmod +x /ubuntu/autostart/wireguard.sh
      chroot /ubuntu /autostart/wireguard.sh >/dev/null 2>&1
      break
      ;;
    3)
      msg=" and\n the WireGuard server is restarted"

      get env && {
          setup 2 /opt /bin /lib/modules
          grep -q ^ENABLED=yes /opt/etc/init.d/S50wireguard && /opt/etc/init.d/S50wireguard start || msg=""
        } || {
          setup 2 /ubuntu /usr/local/bin /usr/local/lib/modules
          [ -x /ubuntu/autostart/wireguard.sh ] && chroot /ubuntu /autostart/wireguard.sh >/dev/null 2>&1 || msg=""
        }

      sync
      printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The wireguard.ko kernel module and the wg utility is successfully updated$msg.\e[0m\n\n"
      exit 0
      ;;
    4)
      get env o && {
          wg=/opt/bin/wg
          cdir=/opt/etc/wireguard
        } || {
          wg=/ubuntu/usr/local/bin/wg
          cdir=/ubuntu/usr/local/etc/wireguard
        }

      pkey1=$(grep ^PrivateKey $cdir/wg0.conf | cut -d " " -f 3)
      cnum=$(($(grep PublicKey $cdir/wg0.conf | wc -l) + 2))
      pkey2=$($wg genkey)

      cat << EOF >>$cdir/wg0.conf

[Peer]
PublicKey = $(printf $pkey2 | $wg pubkey)
AllowedIPs = 10.7.0.$cnum/32
EOF

      cat << EOF >$cdir/${rname}.conf
[Interface]
PrivateKey = $pkey2
Address = 10.7.0.$cnum/32
DNS = $(get dns)
MTU = 1432

[Peer]
Endpoint = $(get ddns):51820
PublicKey = $(printf $pkey1 | $wg pubkey)
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

      get zpng $cdir $((--cnum))
      sync
      ifconfig wg0 >/dev/null 2>&1 && $wg setconf wg0 $cdir/wg0.conf
      printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The ${rname}_wg-client$cnum .png and .zip files are successfully created in the\n '$odir'.\e[0m\n\n"
      exit 0
      ;;
    5)
      if get env o
      then setting /opt /bin /etc r
      else setting /ubuntu /usr/local/bin /usr/local/etc r
      fi

      sync
      ifconfig wg0 >/dev/null 2>&1 && $wg setconf wg0 $cdir/wg0.conf
      printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The new ${rname}_wg-client1 .png and .zip files are successfully created in\n the '$odir'.\e[0m\n\n"
      exit 0
      ;;
    ""|0)
      echo
      exit 0
  esac
done

sync
printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The ${rname}_wg-client1 .png and .zip files are successfully created in the\n '$odir'.\n\n Please set the following firewall rules in the SRM:\n\n  Protocol        Source IP        Source port   Dest. IP   Dest. port   Action\n ===============================================================================\n    UDP              All               All         SRM        51820      Allow\n  TCP/UDP   10.7.0.0/255.255.255.0     All         All         All       Allow\n\n Note that you may not be able to connect if the router is behind a\n carrier-grade NAT!\e[0m\n\n"
