#!/bin/sh
#
# Ubuntu chroot environment installer script for Synology routers
# Hard-float - VFPv3-D16
# Tested only on RT2600ac in Wireless Router mode
#
# 2019-2020, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#
#
# Compatible Ubuntu distributions: 18.04.4 LTS
#                                  19.10
#                                  20.04 LTS latest daily build
#

vers=1.24 # 2020.02.21
syno_routers="MR2200ac RT2600ac" # Supported models

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
      printf "A Ubuntu chroot environment is already active!\n Please shut it down before creating a new one.\n\n BE CAREFUL, do not delete the Ubuntu directory!\n Run this script again and select the option 4."
      ;;
    6)
      printf "Sorry, but failed to detect any compatible ext4 partition!"
      ;;
    7)
      printf "Sorry, but not enough free space to prepare the Ubuntu chroot environment!"
      ;;
    8)
      printf "Sorry, but failed to detect any existing Ubuntu installation!"
      ;;
    9)
      printf "Failed to detect any modifications in the router internal filesystem!"
  esac

  printf "\n\n The script is ended without any effect!\e[0m\n\n"
  exit $1
} >&2

errd()
{
  printf "\n \e[1;31mSorry, but failed to download an essential file!\e[0m\n\n"
  exit 9
} >&2

setup()
{
  grep -q "^alias uroot=\"chroot /ubuntu /bin/bash\"$" /root/.profile || cat << EOF >>/root/.profile
alias uroot="chroot /ubuntu /bin/bash"
alias apt="chroot /ubuntu /usr/bin/apt"
alias apt-upgrade="apt update ; apt full-upgrade ; apt autoremove --purge ; apt clean"
EOF

  sfile=/usr/local/etc/rc.d/ubuntu.sh
  csum=9bdc3d3cdcd06d5dd550ca5620abbb1e # Avoid unnecessary write operations on the internal eMMC chip

  if [ -s $sfile ] && [ "$(python -c "import hashlib ; print(hashlib.md5(open('$sfile', 'rb').read()).hexdigest())")" =  "$csum" ] # 'md5sum' is missing from the router system
  then touch -m $sfile # Close the already running startup script
  else cat << EOF >$sfile # Internal SWAP priority is 999
#!/bin/sh

ubuntu()
{
  lmt="\$(date -ur $sfile)"
  tout=30

  while :
  do
    for dir in /volumeUSB*
    do
      for mp in \$dir/*
      do
        [ -f \$mp/ubuntu/bin/bash ] && [ "\${1:0:10}" != /volumeUSB -o "\$mp" = "\$1" ] || continue

        [ ! -h /ubuntu ] || [ "\$(readlink /ubuntu)" != "\$mp/ubuntu" ] && {
            rm -rf /ubuntu
            ln -s \$mp/ubuntu /ubuntu
          }

        grep "/ubuntu/dev " /proc/mounts || {
            mount -t devtmpfs -o rw,nosuid,relatime,mode=755 dev /ubuntu/dev
            mount -t devpts -o rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=000 pts /ubuntu/dev/pts
            mount -t tmpfs -o rw,nosuid,nodev,relatime shm /ubuntu/dev/shm
            mount -t proc proc /ubuntu/proc
            mount -t tmpfs -o rw,nosuid,noexec,relatime,mode=755 run /ubuntu/run
            mount -t sysfs sys /ubuntu/sys
            mount -t debugfs debug /ubuntu/sys/kernel/debug
            mount -t securityfs security /ubuntu/sys/kernel/security
            mount -t tmpfs tmp /ubuntu/tmp
            mount --bind / /ubuntu/mnt/Synology
            mount --bind /volume1 /ubuntu/mnt/Internal
            mount --bind \$mp /ubuntu/mnt/HDD
            [ -e /ubuntu/swapfile ] && swapon -p 1000 /ubuntu/swapfile
          }

        for a in /ubuntu/autostart/*
        do [ -x \$a ] && chroot /ubuntu "\${a:7}"
        done

        exit 0
      done
    done

    [ \$((tout--)) -eq 0 ] && break
    sleep 10s
    [ "\$(date -ur $sfile)" = "\$lmt" ] || break
  done
}

[ "\$1" = start ] && ubuntu \$2 >/dev/null 2>&1 &
EOF
  fi

  [ -x $sfile ] || chmod +x $sfile
  setsid $sfile start $1

  until
    sleep 1s
    [ -f /ubuntu/usr/bin/apt ] && [ "$(readlink /ubuntu)" = "$1/ubuntu" ]
  do :
  done

  chroot /ubuntu /usr/bin/apt update
  chroot /ubuntu /usr/bin/apt full-upgrade -y
  chroot /ubuntu /usr/bin/apt install locales -y
  chroot /ubuntu /usr/bin/apt autoremove --purge -y
  chroot /ubuntu /usr/bin/apt clean
  [ -f /ubuntu/usr/sbin/locale-gen ] || errd
  chroot /ubuntu /usr/sbin/locale-gen en_US.UTF-8
  sync
  printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The chroot environment (alias 'uroot') is ready,\n just perform a logout from this SSH session, and login again.\e[0m\n\n"
  exit 0
}

remove()
{
  [ -h /ubuntu ] || [ -f /usr/local/etc/rc.d/ubuntu.sh ] || grep -qe "^alias uroot=" -e "^alias apt=" -e "^alias apt-upgrade=" /root/.profile || {
      [ "$1" ] && return || error 9
    }

  rm /ubuntu /usr/local/etc/rc.d/ubuntu.sh
  sed -ie "/^alias uroot=/d" -e "/^alias apt=/d" -e "/^alias apt-upgrade=/d" /root/.profile
  sync
}

[ $(id -u) -eq 0 ] || error 1
[ -e /usr/local/etc/rc.d/ubuntu_remove.sh ] && error 2
egrep -sq $(printf "$syno_routers" | sed -e s/^/^/ -e "s/ /|^/g") /proc/sys/kernel/syno_hw_version || error 3
ping -c 1 www.google.com >/dev/null 2>&1 || error 4
printf "\e[2J\e[1;1H\ec\n\e[1mUbuntu installer script for Synology routers v$vers by Kendek\n\n 1\e[0m - Install and setup a new Ubuntu chroot environment\n \e[1m2\e[0m - Setup the existing Ubuntu directory\n \e[1m3\e[0m - Remove all modifications from the router internal filesystem\n \e[1m4\e[0m - Completely remove the Ubuntu chroot environment and reboot the router\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-4]: " o

  case $o in
    1)
      mlst="$(mount)"
      printf "$mlst" | grep -q " /ubuntu/" && error 5
      mlst="$(printf "$mlst" | grep /volumeUSB.*ext4 | cut -d " " -f 3)" # Compatible only with ext4
      [ "$mlst" ] || error 6

      [ $(echo "$mlst" | wc -l) -eq 1 ] && mp=$mlst || {
          cnt=0

          for mp in $mlst
          do [ $((++cnt)) -eq 1 ] && mpts="  \e[1m1\e[0m - $mp/ubuntu (default)" || mpts="$mpts\n  \e[1m$cnt\e[0m - $mp/ubuntu"
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

      [ $(df $mp | awk "NR==2 {printf \$4}") -lt 1572864 ] && error 7 # 1.5 GiB free space check
      printf "\n Ubuntu version:\n\n  \e[1m1\e[0m - 18.04.4 LTS Bionic Beaver (default)\n  \e[1m2\e[0m - 19.10 Eoan Ermine\n  \e[1m3\e[0m - 20.04 LTS Focal Fossa (latest daily build)\n\n"

      while :
      do
        read -p "Select an option [1-3]: " o

        case $o in
          ""|1)
            vers=18.04.4
            name=bionic
            ;;
          2)
            vers=19.10
            name=eoan
            ;;
          3)
            vers=20.04
            name=focal
            ;;
          *)
            continue
        esac

        break
      done

      udir=$mp/ubuntu # Install directory on the external device
      [ -e $udir ] && mv $udir ${udir}_$(tr -dc a-zA-Z0-9 </dev/urandom | head -c 16) # Backup the existing data
      mkdir $udir
      cd $udir
      wget -O ubuntu.tar.gz http://cdimage.ubuntu.com/ubuntu-base/$([ $vers = 20.04 ] && printf daily/current/$name || printf releases/$vers/release/ubuntu-base-$vers)-base-armhf.tar.gz || errd
      tar -xf ubuntu.tar.gz
      rm ubuntu.tar.gz

      cat << EOF >etc/apt/sources.list
deb http://ports.ubuntu.com/ubuntu-ports $name main multiverse restricted universe
deb http://ports.ubuntu.com/ubuntu-ports $name-security main multiverse restricted universe
deb http://ports.ubuntu.com/ubuntu-ports $name-updates main multiverse restricted universe
deb http://ports.ubuntu.com/ubuntu-ports $name-backports main multiverse restricted universe
EOF

      mkdir autostart mnt/HDD mnt/Internal mnt/Synology # The files in 'autostart' directory are automatically executed when the router is started
      rm etc/resolv.conf etc/localtime # Required for internet connection and local time (OpenVPN log)
      ln -s /mnt/Synology/etc/resolv.conf etc/resolv.conf
      ln -s /mnt/Synology/etc/localtime etc/localtime
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

            hdparm --fallocate $(( $size * 1024 )) swapfile # Use fallocate for fast allocation
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
        do [ -f $mp/ubuntu/bin/bash ] && setup $mp
        done
      done

      error 8
      ;;
    3)
      remove
      printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The services have not been stopped, the Ubuntu directory is still intact.\n\n Please reboot the router before delete anything.\e[0m\n\n"
      exit 0
      ;;
    4)
      sfile=/usr/local/etc/rc.d/ubuntu_remove.sh # Startup script for removing the Ubuntu directory from the external device

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
        [ -f \$mp/ubuntu/bin/bash ] || continue
        udir=\$mp/ubuntu_\$(tr -dc a-zA-Z0-9 </dev/urandom | head -c 16)
        mv \$mp/ubuntu \$udir
        rm -rf \$udir
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
