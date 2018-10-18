#!/bin/sh
#
# Scripts collection executor for Synology routers
# https://gitlab.com/Kendek/syno-router-scripts
#
# 2018, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#

vers=1.4 # 2018.10.18
syno_routers="MR2200ac RT2600ac RT1900ac" # Supported models
dlink=https://gitlab.com/Kendek/syno-router-scripts/raw/master/ # Download from here

# File names in order
scripts="\
entware_install.sh
ubuntu_install.sh
transmission_install.sh
openvpn_install.sh
minidlna_install.sh
gerbera_install.sh
plex_install.sh
nfs_setup.sh
services_control.sh"

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
  esac

  printf "\n\n The script is ended without any effect!\e[0m\n\n"
  exit $1
} >&2

errd()
{
  printf "\n \e[1;31mSorry, but failed to download an essential file!\e[0m\n\n"
  exit 4
} >&2

[ $(id -u) -eq 0 ] || error 1
egrep -sq $(printf "$syno_routers" | sed -e s/^/^/ -e "s/ /|^/g") /proc/sys/kernel/syno_hw_version || error 2
ping -c 1 www.google.com >/dev/null 2>&1 || error 3

while :
do
  printf "\e[2J\e[1;1H\ec\n\e[1mScripts collection executor for Synology routers v$vers by Kendek\e[0m\n\n"
  cnt=0

  for s in $scripts
  do printf " \e[1m$((++cnt))\e[0m - $s\n"
  done

  printf " \e[1m0\e[0m - Quit (default)\n\n"

  while :
  do
    read -p "Select an option [0-$cnt]: " o

    case $o in
      [1-$cnt])
        script="$(wget -O - $dlink$(printf "$scripts" | sed -n ${o}p))"
        [ "$script" ] || errd
        sh -c "$script"
        while read -n 1 -t 1 ; do : ; done # Flush input buffer
        read -sn 1 -p "$(printf "\e[1mPress any key to continue\e[0m") "
        break
        ;;
      ""|0)
        echo
        exit 0
    esac
  done
done
