#!/bin/sh
#
# WireGuard server installer script for Synology routers
# Compatible with Entware (soft-float) and Ubuntu chroot (hard-float)
# Tested only on RT2600ac in Wireless Router mode
#
# 2019-2023, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#
#
# NOTE: only IPv4 since the routers have limited IPv6 NAT support
#

vers=1.11 # 2023.02.24
syno_routers="RT6600ax WRX560 MR2200ac RT2600ac RT1900ac" # Supported models

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
      printf "The WireGuard is already installed in the router's internal storage!\n Secondary installation is not a good idea."
      ;;
    10)
      printf "Sorry, but not enough free space to install the WireGuard!"
      ;;
    11)
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
    chk)
      [ -s /volume1/WireGuard/lib/modules/wireguard.ko ] || [ -s /volume1/WireGuard/bin/wireguard-go ] && {
          [ "${2:1:1}" = v ] || error 9
          grep -q ^PATH=.*:/volume1/WireGuard/bin /root/.profile || return 1
          error 6
        }

      [ $(df $2 | awk "NR==2 {printf \$4}") -lt 262144 ] && error 10 # 256 MiB free space check
      return 0
      ;;
    ddns)
      local ddns=$(grep -m 1 hostname= /etc/ddns.conf | cut -d = -f 2)
      [ "$ddns" ] && printf $ddns || wget -qO- v4.ifconfig.co # Using external IP address as a backup
      ;;
    dns)
      for ip in $(grep ^nameserver /etc/resolv.conf | egrep -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}") ; do printf "$ip, " ; done | sed "s/, $//g"
      ;;
    tmpf)
      tmpf=/tmp/WG_$(tr -dc a-zA-Z0-9 </dev/urandom | head -c 16)/$rname.conf
      (umask 177 ; mkdir ${tmpf%/*})
      ;;
    zpng)
      if [ "${2:1:1}" = v ]
      then qrc="$(qrencode -t ansiutf8 <$tmpf)" # Show QR code at the end
      else
        [ "$4" ] && rm $odir/${rname}_wg-client*.zip $odir/${rname}_wg-client*.png 2>/dev/null
        zip -j $odir/${rname}_wg-client$3 $tmpf # Can be imported in the Android app
        qrencode -o $odir/${rname}_wg-client$3.png <$tmpf # Can be scanned from the Android app
      fi

      rm -rf ${tmpf%/*}
      ;;
    set)
      ifconfig wg0 >/dev/null 2>&1 && \
        if [ "$go" ] && [ "${wg:1:1}" = u ]
        then chroot /ubuntu /usr/local/bin/wg setconf wg0 /usr/local/etc/wireguard/wg0.conf & usleep 100000 && kill $!
        else $wg setconf wg0 $cdir/wg0.conf & usleep 100000 && [ "$go" ] && kill $!
        fi 2>/dev/null
      ;;
    qrc)
      while read -n 1 -t 1 ; do : ; done # Flush input buffer
      read -sn 1 -p "$(printf "\e[1mPress any key to show the client's $([ "$2" ] && printf "new ")QR code.\e[0m") "
      printf "\e[2J\e[1;1H\ec$qrc\n"
      ;;
    env)
      if [ -s /opt/lib/modules/wireguard.ko ] || [ -s /opt/bin/wireguard-go ]
      then
        [ "$2" ] && odir=$(readlink /opt | sed "s/\/entware//")
        return 0
      elif [ -s /ubuntu/usr/local/lib/modules/wireguard.ko ] || [ -s /ubuntu/usr/local/bin/wireguard-go ]
      then
        [ "$2" ] && odir=$(readlink /ubuntu | sed "s/\/ubuntu//")
        return 1
      elif [ -s /volume1/WireGuard/lib/modules/wireguard.ko ] || [ -s /volume1/WireGuard/bin/wireguard-go ]
      then return 2
      else error 11
      fi
  esac
}

setting()
{
  wg=$1$2/wg
  cdir=$1$3/wireguard
  pkey1=$($wg genkey) pkey2=$($wg genkey)
  get tmpf

  cat << EOF >$cdir/wg0.conf
[Interface]
PrivateKey = $pkey1
ListenPort = 51820

[Peer]
PublicKey = $(printf $pkey2 | $wg pubkey)
AllowedIPs = 10.7.0.2/32
EOF

  # Mtu 1432 because 1492 PPPoE max - 20 IPv4 header - 8 UDP header - 4 type - 4 key index - 8 nonce - 16 authentication tag
  cat << EOF >$tmpf
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
  wget -O $2$3/wg $([ "$rname" = RT6600ax ] && printf bit.ly/3xNJOIw || printf bit.ly/3EAf5Cz) || errd
  chmod +x $2$3/wg

  ifconfig wg0 >/dev/null 2>&1 && {
      [ -S /var/run/wireguard/wg0.sock ] && rm /var/run/wireguard/wg0.sock || ip link del wg0
    }

  if [ "$go" ]
  then
    wget -O $2$3/wireguard-go $([ "$rname" = RT6600ax ] && printf bit.ly/3HTBRHM || printf bit.ly/3RubriT) || errd
    chmod +x $2$3/wireguard-go
  else
    [ -d $2$4 ] || mkdir $2$4
    wget -O $2$4/wireguard.ko goo.gl/$([ "$rname" = RT2600ac ] && printf 8mQdtn || printf rmKsWr) || errd
  fi

  if [ $1 -eq 2 ]
  then lsmod | grep -q ^wireguard && rmmod wireguard.ko
  else
    [ -d $2$5/wireguard ] || (umask 177 ; mkdir $2$5/wireguard)
    setting $2 $3 $5
  fi
}

[ $(id -u) -eq 0 ] || error 1
rname="$(head -c 8 /proc/sys/kernel/syno_hw_version 2>/dev/null)"
printf "$rname" | egrep -q $(printf "$syno_routers" | sed "s/ /|/g") || error 2
ping -c 1 www.google.com >/dev/null 2>&1 || error 3
#[ "$rname" = RT1900ac ] && go=1 || go="" # Using wireguard-go on RT1900ac
go=1 # Using wireguard-go on all supported models
qrc=""
printf "\e[2J\e[1;1H\ec\n\e[1mWireGuard server installer script for Synology routers v$vers by Kendek\n\n 1\e[0m - Install through the existing Entware environment\n \e[1m2\e[0m - Install through the existing Ubuntu chroot environment\n \e[1m3\e[0m - Install to the router's internal storage or repair missing wg utility\n \e[1m4\e[0m - Update the $([ "$go" ] && printf "wireguard-go daemon binary" || printf "wireguard.ko kernel module") and the wg utility\n \e[1m5\e[0m - Add an additional peer and $([ -d /volume1/WireGuard ] && printf "show the client's QR code" || printf "create .zip and .png files")\n \e[1m6\e[0m - Reinitialize the current configuration\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-6]: " o

  case $o in
    1)
      [ -f /opt/bin/opkg ] || error 4
      [ -s /opt/lib/modules/wireguard.ko ] || [ -s /opt/bin/wireguard-go ] && error 6
      [ -s /ubuntu/usr/local/lib/modules/wireguard.ko ] || [ -s /ubuntu/usr/local/bin/wireguard-go ] && error 7
      get chk /opt
      odir=$(readlink /opt | sed "s/\/entware//")
      setup 1 /opt /bin /lib/modules /etc

      cat << EOF >/opt/etc/init.d/S50wireguard
#!/bin/sh

ENABLED=yes

[ "\$ENABLED" = yes ] || {
    printf "\\n \\e[1mDisabled\\e[0m\\n\\n"
    exit 1
  }

start()
{
  $([ "$go" ] && printf "lsmod | grep -q ^tun || insmod /lib/modules/tun.ko\n  /opt/bin/wireguard-go wg0 >/dev/null 2>&1" || printf "ip link add wg0 type wireguard") && \\
  ip addr add 10.7.0.1/24 dev wg0 && \\
  /opt/bin/wg setconf wg0 /opt/etc/wireguard/wg0.conf$([ "$go" ] && printf " & usleep 100000 && (kill \$! 2>/dev/null || true)") && \\
  ip link set wg0 up && \\
  ifconfig wg0 mtu 1432 txqueuelen 1000 && \\
  printf "\\n \\e[1mDone\\e[0m\\n\\n" || {
      printf "\\n \\e[1;31mFailed!\\e[0m\\n\\n" >&2
      exit 3
    }
}

case \$1 in
  start)
    ifconfig wg0 >/dev/null 2>&1 && printf "\\n \\e[1mAlready running!\\e[0m\\n\\n" || $([ "$go" ] && printf start || printf "{\n%8sinsmod /opt/lib/modules/wireguard.ko\n%8sstart\n%6s}\n")
    ;;
  stop)
    ! ifconfig wg0 >/dev/null 2>&1 && printf "\\n \\e[1mAlready stopped!\\e[0m\\n\\n" || {
        $([ "$go" ] && printf "rm /var/run/wireguard/wg0.sock" || printf "ip link del wg0 && rmmod wireguard.ko") && printf "\\n \\e[1mDone\\e[0m\\n\\n" || {
            printf "\\n \\e[1;31mFailed!\\e[0m\\n\\n" >&2
            exit 4
          }
      }
    ;;
  restart)
    ifconfig wg0 >/dev/null 2>&1 && $([ "$go" ] && printf "rm /var/run/wireguard/wg0.sock && usleep 100000" || printf "ip link del wg0 || insmod /opt/lib/modules/wireguard.ko")
    start
    ;;
  *)
    printf "\\n \\e[1;31mUsage: \$0 {start|stop|restart}\\e[0m\\n\\n" >&2
    exit 2
esac
EOF

      chmod +x /opt/etc/init.d/S50wireguard
      setsid /opt/etc/init.d/S50wireguard start
      break
      ;;
    2)
      [ -f /ubuntu/usr/bin/apt ] || error 5
      [ -s /ubuntu/usr/local/lib/modules/wireguard.ko ] || [ -s /ubuntu/usr/local/bin/wireguard-go ] && error 6
      [ -s /opt/lib/modules/wireguard.ko ] || [ -s /opt/bin/wireguard-go ] && error 8
      get chk /ubuntu

      [ -f /ubuntu/bin/ip ] && [ -f /ubuntu/bin/kmod ] && [ -f /ubuntu/sbin/ifconfig ] || {
          chroot /ubuntu /usr/bin/apt update 2>/dev/null
          chroot /ubuntu /usr/bin/apt --allow-unauthenticated full-upgrade -y
          chroot /ubuntu /usr/bin/apt --allow-unauthenticated install iproute2 kmod net-tools --no-install-recommends -y
          chroot /ubuntu /usr/bin/apt clean
        }

      odir=$(readlink /ubuntu | sed "s/\/ubuntu//")
      setup 1 /ubuntu /usr/local/bin /usr/local/lib/modules /usr/local/etc

      cat << EOF >/ubuntu/autostart/wireguard.sh
#!/bin/sh

ifconfig wg0 || {
    $([ "$go" ] && printf "lsmod | grep -q ^tun || insmod /mnt/Synology/lib/modules/tun.ko\n%4swireguard-go wg0" || printf "insmod /usr/local/lib/modules/wireguard.ko\n%4sip link add wg0 type wireguard")
    ip addr add 10.7.0.1/24 dev wg0
    wg setconf wg0 /usr/local/etc/wireguard/wg0.conf$([ "$go" ] && printf " & usleep 100000 && kill \$!")
    ip link set wg0 up
    ifconfig wg0 mtu 1432 txqueuelen 1000
  }
EOF

      chmod +x /ubuntu/autostart/wireguard.sh
      setsid chroot /ubuntu /autostart/wireguard.sh >/dev/null 2>&1
      break
      ;;
    3)
      [ -s /opt/lib/modules/wireguard.ko ] || [ -s /opt/bin/wireguard-go ] && error 8
      [ -s /ubuntu/usr/local/lib/modules/wireguard.ko ] || [ -s /ubuntu/usr/local/bin/wireguard-go ] && error 7
      get chk /volume1
      rv=$?

      [ $rv -eq 0 ] && {
          mkdir -p /volume1/WireGuard/bin /volume1/WireGuard/etc
          [ "$go" ] || mkdir /volume1/WireGuard/lib
          setup 1 /volume1 /WireGuard/bin /WireGuard/lib/modules /WireGuard/etc

          cat << EOF >/usr/local/etc/rc.d/wireguard.sh
#!/bin/sh

wireguard()
{
  ifconfig wg0 || {
      $([ "$go" ] && printf "lsmod | grep -q ^tun || insmod /lib/modules/tun.ko\n%6s/volume1/WireGuard/bin/wireguard-go wg0" || printf "insmod /volume1/WireGuard/lib/modules/wireguard.ko\n%6sip link add wg0 type wireguard")
      ip addr add 10.7.0.1/24 dev wg0
      /volume1/WireGuard/bin/wg setconf wg0 /volume1/WireGuard/etc/wireguard/wg0.conf$([ "$go" ] && printf " & usleep 100000 && kill \$!")
      ip link set wg0 up
      ifconfig wg0 mtu 1432 txqueuelen 1000
    }
}

[ "\$1" = start ] && wireguard >/dev/null 2>&1 &
EOF

          chmod +x /usr/local/etc/rc.d/wireguard.sh
          setsid /usr/local/etc/rc.d/wireguard.sh start
        }

      grep -q ^PATH=.*:/opt/bin:/opt/sbin$ /root/.profile && sed -i "s/:\/opt\//:\/volume1\/WireGuard\/bin:\/opt\//" /root/.profile || sed -i "/^PATH=/s/$/:\/volume1\/WireGuard\/bin/" /root/.profile
      [ $rv -eq 0 ] && break
      sync
      printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\e[0m\n\n The wg utility is ready, just perform a logout from this SSH session, and\n login again\e[0m\n\n"
      exit 0
      ;;
    4)
      msg=" and\n the WireGuard server is restarted"

      get env && {
          setup 2 /opt /bin /lib/modules
          grep -q ^ENABLED=yes /opt/etc/init.d/S50wireguard && setsid /opt/etc/init.d/S50wireguard start || msg=""
        } || {
          [ $? -eq 1 ] && {
              setup 2 /ubuntu /usr/local/bin /usr/local/lib/modules
              [ -x /ubuntu/autostart/wireguard.sh ] && setsid chroot /ubuntu /autostart/wireguard.sh >/dev/null 2>&1 || msg=""
            } || {
              setup 2 /volume1 /WireGuard/bin /WireGuard/lib/modules
              [ -x /usr/local/etc/rc.d/wireguard.sh ] && setsid /usr/local/etc/rc.d/wireguard.sh start || msg=""
            }
        }

      sync
      printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The $([ "$go" ] && printf "wireguard-go daemon binary" || printf "wireguard.ko kernel module") and the wg utility is successfully updated$msg.\e[0m\n\n"
      exit 0
      ;;
    5)
      get env o && {
          wg=/opt/bin/wg
          cdir=/opt/etc/wireguard
        } || {
          [ $? -eq 1 ] && {
              wg=/ubuntu/usr/local/bin/wg
              cdir=/ubuntu/usr/local/etc/wireguard
            } || {
              wg=/volume1/WireGuard/bin/wg
              cdir=/volume1/WireGuard/etc/wireguard
            }
        }

      pkey1=$(grep ^PrivateKey $cdir/wg0.conf | cut -d " " -f 3)
      cnum=$(($(grep PublicKey $cdir/wg0.conf | wc -l) + 2))
      pkey2=$($wg genkey)
      get tmpf

      cat << EOF >>$cdir/wg0.conf

[Peer]
PublicKey = $(printf $pkey2 | $wg pubkey)
AllowedIPs = 10.7.0.$cnum/32
EOF

      cat << EOF >$tmpf
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
      get set
      printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\e[0m\n\n"
      [ ! "$qrc" ] && printf "\e[1m The ${rname}_wg-client$cnum .png and .zip files are successfully created in the\n '$odir'.\e[0m\n\n" || get qrc
      exit 0
      ;;
    6)
      if get env o
      then setting /opt /bin /etc r
      elif [ $? -eq 1 ]
      then setting /ubuntu /usr/local/bin /usr/local/etc r
      else setting /volume1 /WireGuard/bin /WireGuard/etc
      fi

      sync
      get set
      printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\e[0m\n\n"
      [ ! "$qrc" ] && printf "\e[1m The new ${rname}_wg-client1 .png and .zip files are successfully created in\n the '$odir'.\e[0m\n\n" || get qrc n
      exit 0
      ;;
    ""|0)
      echo
      exit 0
  esac
done

sync
printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n $([ "$qrc" ] && printf "The wg utility is ready, just perform a logout from this SSH session, and\n login again" || printf "The ${rname}_wg-client1 .png and .zip files are successfully created in the\n '$odir'").\n\n Please set the following firewall rules in the SRM:\n\n  Protocol        Source IP        Source port   Dest. IP   Dest. port   Action\n ===============================================================================\n    UDP              All               All         SRM        51820      Allow\n  TCP/UDP   10.7.0.0/255.255.255.0     All         All         All       Allow\n\n Note that you may not be able to connect if the router is behind a\n carrier-grade NAT!\e[0m\n\n"
[ "$qrc" ] && get qrc || exit 0
