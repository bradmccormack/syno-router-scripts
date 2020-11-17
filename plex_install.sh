#!/bin/sh
#
# Plex Media Server installer script for Synology routers
# Compatible with Entware and Ubuntu chroot
# Tested only on RT2600ac in Wireless Router mode
#
# 2018-2020, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#

vers=1.73 # 2020.11.17
plex_vers=1.20.5.3600-47c0d9038 # For download
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
      printf "The Plex Media Server is already installed on Ubuntu!\n Secondary installation is not a good idea."
      ;;
    7)
      printf "The Plex Media Server is already installed on Entware!\n Secondary installation is not a good idea."
      ;;
    8)
      printf "Sorry, but not enough free space to install the Plex Media Server!"
      ;;
    9)
      printf "Sorry, but failed to download the Plex Media Server version ${plex_vers%\-*}!\n Please update the installer."
  esac

  printf "\n\n The script is ended without any effect!\e[0m\n\n"
  exit $1
} >&2

setup()
{
  [ $(df . | awk "NR==2 {printf \$4}") -lt 524288 ] && error 8 # 512 MiB free space check
  wget -O plex.tar https://downloads.plex.tv/plex-media-server-new/$plex_vers/synology/PlexMediaServer-$plex_vers-armv7hf_neon.spk || error 9
  tar -xf plex.tar package.tgz
  rm plex.tar

  if [ -d $1/plexmediaserver ]
  then
    pidof PlexMediaServer >/dev/null && {
        killall PlexMediaServer
        cnt=40 # Plex can be slow

        while pidof PlexMediaServer >/dev/null && [ $((cnt--)) -ne 0 ]
        do usleep 500000
        done

        pidof PlexMediaServer >/dev/null && killall -9 PlexMediaServer
      }

    rm -rf $1/plexmediaserver/*
  else mkdir -p $1/plexmediaserver var/lib/plexmediaserver
  fi

  tar -xf package.tgz -C $1/plexmediaserver --exclude=dsm_config
  rm package.tgz
  ln -s "Plex Media Server" $1/plexmediaserver/PlexMediaServer # Lot of trouble because spaces
}

[ $(id -u) -eq 0 ] || error 1
egrep -sq $(printf "$syno_routers" | sed -e s/^/^/ -e "s/ /|^/g") /proc/sys/kernel/syno_hw_version || error 2
ping -c 1 www.google.com >/dev/null 2>&1 || error 3
printf "\e[2J\e[1;1H\ec\n\e[1mPlex Media Server installer script for Synology routers v$vers by Kendek\n\n 1\e[0m - Install into the existing Entware environment\n \e[1m2\e[0m - Install into the existing Ubuntu chroot environment\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-2]: " o

  case $o in
    1)
      [ -f /opt/bin/opkg ] || error 4
      [ -f /ubuntu/usr/lib/plexmediaserver/PlexMediaServer ] && error 6
      cd /opt
      setup lib

      cat << EOF >etc/init.d/S90plexmediaserver
#!/bin/sh

ENABLED=yes
PROCS=PlexMediaServer
ARGS=""
PREARGS=""
DESC=\$PROCS
PATH=/opt/lib/plexmediaserver:/opt/sbin:/opt/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/syno/sbin:/usr/syno/bin:/usr/local/sbin:/usr/local/bin

export LC_ALL=en_US.utf8 \\
       LANG=en_US.utf8 \\
       LD_LIBRARY_PATH=/opt/lib/plexmediaserver \\
       PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS=6 \\
       PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR=/opt/var/lib/plexmediaserver \\
       TMPDIR=/opt/tmp

ulimit -s 3000
. /opt/etc/init.d/rc.func
EOF

      chmod +x etc/init.d/S90plexmediaserver
      etc/init.d/S90plexmediaserver start
      break
      ;;
    2)
      [ -f /ubuntu/usr/bin/apt ] || error 5
      [ -f /opt/lib/plexmediaserver/PlexMediaServer ] && error 7
      cd /ubuntu
      setup usr/lib

      cat << EOF >autostart/plexmediaserver.sh
#!/bin/sh

pidof PlexMediaServer || {
    export LC_ALL=en_US.utf8 \\
           LANG=en_US.utf8 \\
           LD_LIBRARY_PATH=/usr/lib/plexmediaserver \\
           PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS=6 \\
           PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR=/var/lib/plexmediaserver \\
           TMPDIR=/var/tmp

    ulimit -s 3000
    /usr/lib/plexmediaserver/PlexMediaServer &
  }
EOF

      chmod +x autostart/plexmediaserver.sh
      chroot /ubuntu /autostart/plexmediaserver.sh >/dev/null 2>&1
      break
      ;;
    ""|0)
      echo
      exit 0
  esac
done

sync
printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The Plex Media Server WebUI is available on 'http://$(ifconfig lbr0 | egrep -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -1):32400/web'.\n\n Firewall rule for remote access:\n\n  Protocol   Source IP   Source port   Dest. IP   Dest. port   Action\n =====================================================================\n    TCP         All          All         SRM        32400      Allow\e[0m\n\n"
