#!/bin/sh
#
# Entware installer script for Synology routers
# Soft-float
# Tested only on RT2600ac in Wireless Router mode
#
# 2018, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#

vers=1.8 # 2018.10.18
syno_routers="MR2200ac RT2600ac RT1900ac" # Supported models

error()
{
  printf "\e[2J\e[1;1H\ec\n \e[1;31m"

  case $1 in
    1)
      printf "Permission denied!\n Please try again with 'root' user, instead of '$(whoami)'."
      ;;
    2)
      printf "The requested removal operation is in progress!\n Please wait about 5 minutes and try again."
      ;;
    3)
      printf "Sorry, but failed to detect any compatible Synology router!"
      ;;
    4)
      printf "Sorry, but failed to detect the internet connection!"
      ;;
    5)
      printf "Sorry, but failed to detect any compatible ext4 partition!"
      ;;
    6)
      printf "Sorry, but not enough free space to prepare the Entware environment!"
      ;;
    7)
      printf "Sorry, but failed to detect any existing Entware installation!"
      ;;
    8)
      printf "Failed to detect any modifications in the router internal filesystem!"
  esac

  printf "\n\n The script is ended without any effect!\e[0m\n\n"
  exit $1
} >&2

errd()
{
  printf "\n \e[1;31mSorry, but failed to download an essential file!\e[0m\n\n"
  exit 8
} >&2

setup()
{
  grep -q ^PATH=.*:/opt/bin:/opt/sbin$ /root/.profile || sed -i "/^PATH=/s/$/:\/opt\/bin:\/opt\/sbin/" /root/.profile
  sfile=/usr/local/etc/rc.d/entware.sh
  csum=e8621939146763c9e4195e5702b6138b # Avoid unnecessary write operations on the internal eMMC chip

  if [ -s $sfile ] && [ "$(python -c "import hashlib ; print(hashlib.md5(open('$sfile', 'rb').read()).hexdigest())")" =  "$csum" ] # 'md5sum' is missing from the router system
  then touch -m $sfile # Close the already running startup script
  else cat << EOF >$sfile # Internal SWAP priority is 999
#!/bin/sh

entware()
{
  lmt="\$(date -ur $sfile)"
  tout=30

  while :
  do
    for dir in /volumeUSB*
    do
      for mp in \$dir/*
      do
        [ -f \$mp/entware/etc/init.d/rc.unslung ] && [ "\${1:0:10}" != /volumeUSB -o "\$mp" = "\$1" ] || continue

        [ ! -h /opt ] || [ "\$(readlink /opt)" != "\$mp/entware" ] && {
            rm -rf /opt
            ln -s \$mp/entware /opt
          }

        [ -e /opt/swapfile ] && swapon -p 1000 /opt/swapfile
        [ ! -f /opt/etc/init.d/S20openvpn ] || lsmod | grep -q ^tun || insmod /lib/modules/tun.ko
        /opt/etc/init.d/rc.unslung start
        exit 0
      done
    done

    [ \$((tout--)) -eq 0 ] && break
    sleep 10s
    [ "\$(date -ur $sfile)" = "\$lmt" ] || break
  done
}

[ "\$1" = start ] && entware \$2 >/dev/null 2>&1 &
EOF
  fi

  [ -x $sfile ] || chmod +x $sfile
  sync
  $sfile start $1
  printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The opkg package manager is ready,\n just perform a logout from this SSH session, and login again.\e[0m\n\n"
  exit 0
}

remove()
{
  [ -h /opt ] || [ -f /usr/local/etc/rc.d/entware.sh ] || grep -q :/opt/bin:/opt/sbin /root/.profile || {
      [ "$1" ] && return || error 8
    }

  rm /opt /usr/local/etc/rc.d/entware.sh
  sed -i "s/:\/opt\/bin:\/opt\/sbin//" /root/.profile
  sync
}

[ $(id -u) -eq 0 ] || error 1
[ -e /usr/local/etc/rc.d/entware_remove.sh ] && error 2
egrep -sq $(printf "$syno_routers" | sed -e s/^/^/ -e "s/ /|^/g") /proc/sys/kernel/syno_hw_version || error 3
ping -c 1 www.google.com >/dev/null 2>&1 || error 4
printf "\e[2J\e[1;1H\ec\n\e[1mEntware installer script for Synology routers v$vers by Kendek\n\n 1\e[0m - Install and setup a new Entware environment\n \e[1m2\e[0m - Setup the existing Entware directory\n \e[1m3\e[0m - Remove all modifications from the router internal filesystem\n \e[1m4\e[0m - Completely remove the Entware environment and reboot the router\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-4]: " o

  case $o in
    1)
      mlst="$(mount | grep /volumeUSB.*ext4 | cut -d " " -f 3)" # Compatible only with ext4
      [ "$mlst" ] || error 5

      [ $(echo "$mlst" | wc -l) -eq 1 ] && mp=$mlst || {
          cnt=0

          for mp in $mlst
          do [ $((++cnt)) -eq 1 ] && mpts="  \e[1m1\e[0m - $mp/entware (default)" || mpts="$mpts\n  \e[1m$cnt\e[0m - $mp/entware"
          done

          printf "\n Place to install:\n\n$mpts\n\n"
          mp=""

          while :
          do
            read -p "Select an option [1-$cnt]: " o
            [ "$o" ] || o=1

            for i in $(seq 1 $cnt)
            do [ "$i" = "$o" ] && {
                mp=$(echo "$mlst" | sed -n ${i}p)
                break
              }
            done

            [ "$mp" ] && break
          done
        }

      [ $(df $mp | awk "NR==2 {printf \$4}") -lt 1572864 ] && error 6 # 1.5 GiB free space check
      edir=$mp/entware # Install directory on the external device
      [ -e $edir ] && mv $edir ${edir}_$(tr -dc a-zA-Z0-9 </dev/urandom | head -c 16) # Backup the existing data
      mkdir $edir

      [ ! -h /opt ] || [ "$(readlink /opt)" != "$mp/entware" ] && {
          rm -rf /opt
          ln -s $mp/entware /opt
        }

      cd /opt
      wget -O install.sh http://bin.entware.net/armv7sf-k3.2/installer/generic.sh || errd
      sh install.sh
      rm install.sh
      [ -f bin/opkg ] || errd
      while read -n 1 -t 1 ; do : ; done # Flush input buffer
      printf "\e[2J\e[1;1H\ec\n Create swapfile:\n\n  \e[1m1\e[0m - 256 MiB\n  \e[1m2\e[0m - 512 MiB (default)\n  \e[1m3\e[0m -   1 GiB\n  \e[1m4\e[0m - None\n\n"

      while :
      do
        read -p "Select an option [1-4]: " o

        [ "$o" = 4 ] || {
            case $o in
              1)
                size=256
                ;;
              ""|2)
                size=512
                ;;
              3)
                size=1024
                ;;
              *)
                continue
            esac

            dd if=/dev/zero of=swapfile bs=1M count=$size # 'fallocate' is missing from the router system
            chmod 0600 swapfile
            mkswap swapfile
          }

        break
      done

      setup $mp
      ;;
    2)
      for dir in /volumeUSB*
      do
        for mp in $dir/*
        do [ -f $mp/entware/bin/opkg ] && setup
        done
      done

      error 7
      ;;
    3)
      remove
      printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The services have not been stopped, the Entware directory is still intact.\n\n Please reboot the router before delete anything.\e[0m\n\n"
      exit 0
      ;;
    4)
      sfile=/usr/local/etc/rc.d/entware_remove.sh # Startup script for removing the Entware directory from the external device

      cat << EOF >$sfile
#!/bin/sh

remove()
{
  tout=30

  while :
  do
    for dir in /volumeUSB*
    do
      for mp in \$dir/*
      do
        [ -f \$mp/entware/etc/init.d/rc.unslung ] || continue
        edir=\$mp/entware_\$(tr -dc a-zA-Z0-9 </dev/urandom | head -c 16)
        mv \$mp/entware \$edir
        rm -rf \$edir
        return
      done
    done

    [ \$((tout--)) -eq 0 ] && break
    sleep 10s
  done
}

[ "\$1" = start ] && {
    remove
    rm $sfile
    sync
  } >/dev/null 2>&1 &
EOF

      chmod +x $sfile
      remove -
      printf "\e[2J\e[1;1H\ec\n \e[1mThe router is rebooting now...\n\n Please do not unplug the external storage device(s).\e[0m\n\n"
      reboot
      exit 0
      ;;
    ""|0)
      echo
      exit 0
  esac
done
