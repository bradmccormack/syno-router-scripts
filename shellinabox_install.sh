#!/bin/sh
#
# Shell In A Box installer script for Synology routers
# Compatible with Entware (soft-float) and Ubuntu chroot (hard-float)
# Tested only on RT2600ac in Wireless Router mode
#
# 2019, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#

vers=1.0 # 2019.10.03
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
      printf "The Shell In A Box is already installed!"
      ;;
    7)
      printf "The Shell In A Box is already installed on Ubuntu!\n Secondary installation is not a good idea."
      ;;
    8)
      printf "The Shell In A Box is already installed on Entware!\n Secondary installation is not a good idea."
      ;;
    9)
      printf "Sorry, but not enough free space to install the Shell In A Box!"
  esac

  printf "\n\n The script is ended without any effect!\e[0m\n\n"
  exit $1
} >&2

errd()
{
  printf "\n \e[1;31mSorry, but failed to download an essential file!\e[0m\n\n"
  exit 10
} >&2

[ $(id -u) -eq 0 ] || error 1
egrep -sq $(printf "$syno_routers" | sed -e s/^/^/ -e "s/ /|^/g") /proc/sys/kernel/syno_hw_version || error 2
ping -c 1 www.google.com >/dev/null 2>&1 || error 3
printf "\e[2J\e[1;1H\ec\n\e[1mShell In A Box installer script for Synology routers v$vers by Kendek\n\n 1\e[0m - Install through the existing Entware environment\n \e[1m2\e[0m - Install through the existing Ubuntu chroot environment\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-2]: " o

  case $o in
    1)
      [ -f /opt/bin/opkg ] || error 4
      [ -f /opt/sbin/shellinaboxd ] && error 6
      [ -f /ubuntu/usr/bin/shellinaboxd ] && error 7
      [ $(df /opt | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check
      /opt/bin/opkg update
      /opt/bin/opkg upgrade
      /opt/bin/opkg install shellinabox
      [ -f /opt/sbin/shellinaboxd ] || errd
      /opt/etc/init.d/S88shellinaboxd start
      break
      ;;
    2)
      [ -f /ubuntu/usr/bin/apt ] || error 5
      [ -f /ubuntu/usr/bin/shellinaboxd ] && error 6
      [ -f /opt/sbin/shellinaboxd ] && error 8
      [ $(df /ubuntu | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check
      [ -s /ubuntu/etc/default/shellinabox ] && pset=1 || pset="" # Do not override previous settings when reinstall
      chroot /ubuntu /usr/bin/apt update 2>/dev/null
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated full-upgrade -y
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated install net-tools openssh-client openssl shellinabox -y
      chroot /ubuntu /usr/bin/apt clean
      [ -f /ubuntu/usr/bin/shellinaboxd ] || errd
      [ "$pset" ] || sed -i "s/^SHELLINABOX_ARGS=.*/SHELLINABOX_ARGS=\"-t -s \\\\\"\/:SSH:\$(ifconfig lbr0 | egrep -o \"[0-9]{1,3}\\\.[0-9]{1,3}\\\.[0-9]{1,3}\\\.[0-9]{1,3}\" | head -1)\\\\\" --css \/etc\/shellinabox\/options-enabled\/00_White\\\ On\\\ Black.css --no-beep\"/g" /ubuntu/etc/default/shellinabox

      cat << EOF >/ubuntu/autostart/shellinabox.sh
#!/bin/sh

pidof shellinaboxd || service shellinabox start
EOF

      chmod +x /ubuntu/autostart/shellinabox.sh
      chroot /ubuntu /autostart/shellinabox.sh >/dev/null 2>&1
      break
      ;;
    ""|0)
      echo
      exit 0
  esac
done

sync
printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The Shell In A Box WebUI is available on 'http://$(ifconfig lbr0 | egrep -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -1):4200'.\n\n For secure remote access, please use the clientless WebVPN service with a\n wildcard certificate!\n\n Firewall rule for insecure remote access:\n\n  Protocol   Source IP   Source port   Dest. IP   Dest. port   Action\n =====================================================================\n    TCP         All          All         SRM         4200      Allow\e[0m\n\n"
