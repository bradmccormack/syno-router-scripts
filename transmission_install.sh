#!/bin/sh
#
# Transmission installer script for Synology routers
# Compatible with Entware (soft-float) and Ubuntu chroot (hard-float)
# Tested only on RT2600ac in Wireless Router mode
#
# 2018, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#

vers=1.9 # 2018.10.28
syno_routers="MR2200ac RT2600ac RT1900ac" # Supported models

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
      printf "The Transmission is already installed!"
      ;;
    7)
      printf "The Transmission is already installed on Ubuntu!\n Secondary installation is not a good idea."
      ;;
    8)
      printf "The Transmission is already installed on Entware!\n Secondary installation is not a good idea."
      ;;
    9)
      printf "Sorry, but not enough free space to install the Transmission!"
  esac

  printf "\n\n The script is ended without any effect!\e[0m\n\n"
  exit $1
} >&2

errd()
{
  printf "\n \e[1;31mSorry, but failed to download an essential file!\e[0m\n\n"
  exit 10
} >&2

setting()
{
  cat << EOF >$1
{
    "alt-speed-down": 5000,
    "alt-speed-enabled": false,
    "alt-speed-time-begin": 480,
    "alt-speed-time-day": 127,
    "alt-speed-time-enabled": false,
    "alt-speed-time-end": 1320,
    "alt-speed-up": 500,
    "bind-address-ipv4": "0.0.0.0",
    "bind-address-ipv6": "::",
    "blocklist-enabled": true,
    "blocklist-url": "http://list.iblocklist.com/?list=bt_level1",
    "cache-size-mb": 2,
    "dht-enabled": true,
    "download-dir": "$2",
    "download-queue-enabled": false,
    "download-queue-size": 5,
    "encryption": 1,
    "idle-seeding-limit": 10080,
    "idle-seeding-limit-enabled": false,
    "incomplete-dir": "$3",
    "incomplete-dir-enabled": true,
    "lazy-bitfield-enabled": true,
    "lpd-enabled": true,
    "message-level": 0,
    "peer-congestion-algorithm": "",
    "peer-id-ttl-hours": 6,
    "peer-limit-global": 500,
    "peer-limit-per-torrent": 100,
    "peer-port": 51413,
    "peer-port-random-high": 65535,
    "peer-port-random-low": 49152,
    "peer-port-random-on-start": false,
    "peer-socket-tos": "lowcost",
    "pex-enabled": true,
    "port-forwarding-enabled": true,
    "preallocation": 1,
    "prefetch-enabled": false,
    "queue-stalled-enabled": true,
    "queue-stalled-minutes": 30,
    "ratio-limit": 10,
    "ratio-limit-enabled": false,
    "rename-partial-files": false,
    "rpc-authentication-required": false,
    "rpc-bind-address": "0.0.0.0",
    "rpc-enabled": true,
    "rpc-host-whitelist": "",
    "rpc-host-whitelist-enabled": true,
    "rpc-password": "",
    "rpc-port": 9091,
    "rpc-url": "/transmission/",
    "rpc-username": "",
    "rpc-whitelist": "127.0.0.1,192.168.*.*,10.*.*.*",
    "rpc-whitelist-enabled": true,
    "scrape-paused-torrents-enabled": true,
    "script-torrent-added-enabled": false,
    "script-torrent-added-filename": "",
    "script-torrent-done-enabled": false,
    "script-torrent-done-filename": "",
    "seed-queue-enabled": false,
    "seed-queue-size": 10,
    "speed-limit-down": 10000,
    "speed-limit-down-enabled": false,
    "speed-limit-up": 1000,
    "speed-limit-up-enabled": false,
    "start-added-torrents": false,
    "trash-original-torrent-files": true,
    "umask": 0,
    "upload-slots-per-torrent": 20,
    "utp-enabled": true,
    "watch-dir": "$4",
    "watch-dir-enabled": true
}
EOF
}

[ $(id -u) -eq 0 ] || error 1
egrep -sq $(printf "$syno_routers" | sed -e s/^/^/ -e "s/ /|^/g") /proc/sys/kernel/syno_hw_version || error 2
ping -c 1 www.google.com >/dev/null 2>&1 || error 3
printf "\e[2J\e[1;1H\ec\n\e[1mTransmission installer script for Synology routers v$vers by Kendek\n\n 1\e[0m - Install through the existing Entware environment\n \e[1m2\e[0m - Install through the existing Ubuntu chroot environment\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-2]: " o

  case $o in
    1)
      [ -f /opt/bin/opkg ] || error 4
      [ -f /opt/bin/transmission-daemon ] && error 6
      [ -f /ubuntu/usr/bin/transmission-daemon ] && error 7
      [ $(df /opt | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check
      [ -s /opt/etc/transmission/settings.json ] && pset=1 || pset="" # Do not override previous settings when reinstall
      /opt/bin/opkg update
      /opt/bin/opkg upgrade
      /opt/bin/opkg install transmission-daemon-openssl transmission-remote-openssl transmission-web
      [ -f /opt/bin/transmission-daemon ] || errd
      (umask 0 ; mkdir -p /opt/../Torrent/Completed /opt/../Torrent/Incomplete /opt/../Torrent/Watchdir)
      [ "$pset" ] || setting /opt/etc/transmission/settings.json /opt/../Torrent/Completed /opt/../Torrent/Incomplete /opt/../Torrent/Watchdir

      cat << EOF >/opt/etc/init.d/S88transmission-blist # Update blocklist daily
#!/bin/sh

ENABLED=yes
PROCS=transmission.sh
ARGS=""
PREARGS=""
DESC=\$PROCS
PATH=/opt:/opt/sbin:/opt/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/syno/sbin:/usr/syno/bin:/usr/local/sbin:/usr/local/bin

. /opt/etc/init.d/rc.func
EOF

      cat << EOF >/opt/transmission.sh
#!/bin/sh

sleep 1m

while :
do
  transmission-remote --blocklist-update
  sleep 1d
done
EOF

      chmod +x /opt/etc/init.d/S88transmission-blist /opt/transmission.sh
      /opt/etc/init.d/S88transmission start
      setsid /opt/etc/init.d/S88transmission-blist start
      break
      ;;
    2)
      [ -f /ubuntu/usr/bin/apt ] || error 5
      [ -f /ubuntu/usr/bin/transmission-daemon ] && error 6
      [ -f /opt/bin/transmission-daemon ] && error 8
      [ $(df /ubuntu | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check
      [ -s /ubuntu/etc/transmission-daemon/settings.json ] && pset=1 || pset="" # Do not override previous settings when reinstall
      chroot /ubuntu /usr/bin/apt update 2>/dev/null
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated dist-upgrade -y
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated install transmission-daemon transmission-cli --no-install-recommends -y
      chroot /ubuntu /usr/bin/apt clean
      [ -f /ubuntu/usr/bin/transmission-daemon ] || errd
      (umask 0 ; mkdir -p /ubuntu/../Torrent/Completed /ubuntu/../Torrent/Incomplete /ubuntu/../Torrent/Watchdir)
      [ "$pset" ] || setting /ubuntu/etc/transmission-daemon/settings.json /mnt/HDD/Torrent/Completed /mnt/HDD/Torrent/Incomplete /mnt/HDD/Torrent/Watchdir

      cat << EOF >/ubuntu/autostart/transmission.sh # Update blocklist daily
#!/bin/sh

blist()
{
  sleep 1m

  while :
  do
    transmission-remote --blocklist-update
    sleep 1d
  done
}

pidof transmission-daemon || {
    transmission-daemon -g /etc/transmission-daemon
    blist &
  }
EOF

      chmod +x /ubuntu/autostart/transmission.sh
      setsid chroot /ubuntu /autostart/transmission.sh >/dev/null 2>&1
      break
      ;;
    ""|0)
      echo
      exit 0
  esac
done

sync
printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The Transmission WebUI is available on 'http://$(ifconfig lbr0 | egrep -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -1):9091'.\n\n Please set the following firewall rules in the SRM:\n\n  Protocol   Source IP   Source port   Dest. IP   Dest. port   Action\n =====================================================================\n  TCP/UDP       All          All         SRM        51413      Allow\e[0m\n\n"
