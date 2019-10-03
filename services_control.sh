#!/bin/sh
#
# Services control script for Synology routers
# Compatible only with the other scripts from the collection
# Tested only on RT2600ac in Wireless Router mode
#
# 2018-2019, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#

vers=2.4 # 2019.10.03
syno_routers="MR2200ac RT2600ac RT1900ac" # Supported models

# Service name : Entware startup script : and package name : and process name : Ubuntu startup script : and package name : and process name
table="\
Transmission:S88transmission:transmission-daemon-openssl transmission-remote-openssl transmission-web:transmission-daemon transmission.sh:transmission.sh:transmission-daemon transmission-cli:transmission-daemon transmission.sh
WireGuard:S50wireguard:WG:WG:wireguard.sh:WG:WG
OpenVPN:S20openvpn:openvpn-openssl:openvpn:openvpn.sh:openvpn:openvpn
MiniDLNA:S90minidlna:minidlna:minidlna:minidlna.sh:minidlna:minidlnad
Gerbera:S90gerbera:gerbera:gerbera:gerbera.sh:gerbera:gerbera
Plex Media Server:S90plexmediaserver:PLEX:PlexMediaServer:plexmediaserver.sh:PLEX:PlexMediaServer
Shell In A Box:S88shellinaboxd:shellinabox:shellinaboxd:shellinabox.sh:shellinabox:shellinaboxd"

error()
{
  printf "\e[2J\e[1;1H\ec\n \e[1;31m"

  case $1 in
    1)
      printf "Permission denied!\n Please try again with 'root' user, instead of '$(whoami)'."
      ;;
    2)
      printf "Sorry, but failed to detect any compatible Synology router!"
  esac

  printf "\n\n The script is ended without any effect!\e[0m\n\n"
  exit $1
} >&2

pkill()
{
  # WireGuard is running in the kernel space, the wireguard-go daemon is shutting down if the interface is deleted
  [ "$1" = WG ] && {
      ifconfig wg0 >/dev/null 2>&1 && ip link del wg0 && lsmod | grep -q ^wireguard && rmmod wireguard.ko
      return 0
    }

  pidof $1 || return 0
  killall $1
  cnt=40 # Plex can be slow

  while pidof $1 && [ $((cnt--)) -ne 0 ]
  do usleep 500000
  done

  pidof $1 && killall -9 $1
} >/dev/null 2>&1

pdetect()
{
  [ "$1" = WG ] && cmd="ifconfig wg0" || cmd="pidof $1" # WireGuard and the wireguard-go daemon is detectable with the wg0 interface

  $cmd >/dev/null 2>&1 && {
      echo "  running"
      t2="${t2}:running"
    } || {
      echo "  stopped"
      t2="${t2}:stopped"
    }
}

[ $(id -u) -eq 0 ] || error 1
egrep -sq $(printf "$syno_routers" | sed -e s/^/^/ -e "s/ /|^/g") /proc/sys/kernel/syno_hw_version || error 2
mlen=0

while read n
do [ ${#n} -gt $mlen ] && mlen=${#n}
done << EOF
$(printf "$table" | cut -d : -f 1)
EOF

while :
do
  printf "\e[2J\e[1;1H\ec\n\e[1mServices control script for Synology routers v$vers by Kendek\e[0m\n\n"
  cnt=0 t2=""

  while read serv
  do
    let ++cnt
    name="${serv%%:*}"

    if path=/opt/etc/init.d/$(printf "$serv" | cut -d : -f 2) && [ -f $path ]
    then
      t2="$t2$name:"
      printf " \e[1m$cnt\e[0m - $name $(printf "%$(($mlen-${#name}))s") installed on Entware  "

      grep -q ^ENABLED=yes $path && {
          printf " enabled"
          t2="${t2}enabled"
        } || {
          printf disabled
          t2="${t2}disabled"
        }

      pname="$(printf "$serv" | cut -d : -f 4)"
      pdetect $pname
      t2="$t2:$path:$pname:E:$(printf "$serv" | cut -d : -f 3):/opt/bin/opkg remove --autoremove\n"
    elif path=/ubuntu/autostart/$(printf "$serv" | cut -d : -f 5) && [ -f $path ]
    then
      t2="$t2$name:"
      printf " \e[1m$cnt\e[0m - $name $(printf "%$(($mlen-${#name}))s") installed on Ubuntu   "

      [ -x $path ] && {
          printf " enabled"
          t2="${t2}enabled"
        } || {
          printf disabled
          t2="${t2}disabled"
        }

      pname="$(printf "$serv" | cut -d : -f 7)"
      pdetect $pname
      t2="$t2:$path:$pname:U:$(printf "$serv" | cut -d : -f 6):chroot /ubuntu /usr/bin/apt --allow-unauthenticated remove -y\n"
    elif [ "$name" = WireGuard ] && path=/usr/local/etc/rc.d/wireguard.sh && [ -f $path ]
    then
      t2="$t2$name:"
      printf " \e[1m$cnt\e[0m - $name $(printf "%$(($mlen-9))s") installed internally  "

      [ -x $path ] && {
          printf " enabled"
          t2="${t2}enabled"
        } || {
          printf disabled
          t2="${t2}disabled"
        }

      pdetect WG
      t2="$t2:$path:WG:I:WG\n"
    else
      echo " # - $name $(printf "%$(($mlen-${#name}))s") not installed"
      t2="$t2\n"
    fi
  done << EOF
$table
EOF

  printf " \e[1m0\e[0m - Quit (default)\n\n"

  while :
  do
    read -p "Select an option [0-$cnt]: " o

    case $o in
      [1-$cnt])
        [ "$(printf "$t2" | sed -n ${o}p)" ] || continue
        name="$(printf "$t2" | awk -F : "NR==$o {printf \$1}")"
        ss=$(printf "$t2" | awk -F : "NR==$o {printf \$2}")
        ps=$(printf "$t2" | awk -F : "NR==$o {printf \$3}")

        case $(printf "$t2" | awk -F : "NR==$o {printf \$6}") in
          E)
            loc="Entware ($(readlink /opt))"
            ;;
          U)
            loc="Ubuntu ($(readlink /ubuntu))"
            ;;
          I)
            loc="Internal storage (/volume1)"
        esac

        printf "\e[2J\e[1;1H\ec\n Service:  \e[1m$name\e[0m\n Location: \e[1m$loc\e[0m\n Status:   \e[1m$ss\e[0m\n Process:  \e[1m$ps\e[0m \n\n  \e[1m1\e[0m - "
        cnt=1

        [ "$ss" = enabled ] && {
            printf "Disable\n  \e[1m$((++cnt))\e[0m - "
            [ "$ps" = running ] && printf Stop || printf Start
          } || {
            printf Enable
            [ "$ps" = running ] && printf "\n  \e[1m$((++cnt))\e[0m - Stop"
          }

        printf "\n  \e[1m$((++cnt))\e[0m - Uninstall\n  \e[1m0\e[0m - Cancel (default)\n\n"

        while :
        do
          read -p "Select an option [0-$cnt]: " o2

          case $o2 in
            1)
              path=$(printf "$t2" | awk -F : "NR==$o {printf \$4}")

              if [ "$ss" = enabled ]
              then
                pkill "$(printf "$t2" | awk -F : "NR==$o {printf \$5}")"

                if [ "${loc:0:1}" = E ]
                then
                  sed -i s/^ENABLED=yes/ENABLED=no/ $path
                  [ "$name" = Transmission ] && sed -i s/^ENABLED=yes/ENABLED=no/ $path-blist
                else chmod -x $path
                fi
              elif [ "${loc:0:1}" = E ]
              then
                if [ "$name" = OpenVPN ]
                then lsmod | grep -q ^tun || insmod /lib/modules/tun.ko
                elif [ "$name" = Transmission ]
                then
                  sed -i s/^ENABLED=no/ENABLED=yes/ $path-blist
                  setsid $path-blist start
                fi

                sed -i s/^ENABLED=no/ENABLED=yes/ $path
                setsid $path start
              else
                chmod +x $path

                if [ "${loc:0:1}" = U ]
                then setsid chroot /ubuntu ${path:7} >/dev/null 2>&1
                else
                  setsid /usr/local/etc/rc.d/wireguard.sh start
                  usleep 500000
                fi
              fi

              sync
              break
              ;;
            $cnt)
              pkill "$(printf "$t2" | awk -F : "NR==$o {printf \$5}")"
              pkgs="$(printf "$t2" | awk -F : "NR==$o {printf \$7}")"

              # WireGuard and Plex have been installed outside the packages system
              case $pkgs in
                WG)
                  case ${loc:0:1} in
                    E)
                      rm -f /opt/bin/wg /opt/bin/wireguard-go /opt/etc/init.d/S50wireguard /opt/lib/modules/wireguard.ko
                      ;;
                    U)
                      rm -f /ubuntu/autostart/wireguard.sh /ubuntu/usr/local/bin/wg /ubuntu/usr/local/bin/wireguard-go /ubuntu/usr/local/lib/modules/wireguard.ko
                      ;;
                    I)
                      rm -rf /usr/local/etc/rc.d/wireguard.sh /volume1/WireGuard
                      sed -i "s/:\/volume1\/WireGuard\/bin//" /root/.profile
                  esac

                  ;;
                PLEX)
                  if [ "${loc:0:1}" = E ]
                  then rm -rf /opt/etc/init.d/S90plexmediaserver /opt/lib/plexmediaserver
                  else rm -rf /ubuntu/autostart/plexmediaserver.sh /ubuntu/usr/lib/plexmediaserver
                  fi

                  ;;
                *)
                  $(printf "$t2" | awk -F : "NR==$o {printf \$8}") $pkgs

                  if [ "${loc:0:1}" = U ]
                  then
                    chroot /ubuntu /usr/bin/apt --allow-unauthenticated autoremove --purge -y # Purge only the dependecies
                    rm $(printf "$t2" | awk -F : "NR==$o {printf \$4}")
                  elif [ "$name" = Transmission ]
                  then rm /opt/etc/init.d/S88transmission-blist /opt/transmission.sh
                  fi
              esac

              sync
              break
              ;;
            2)
              if [ "$ps" = running ]
              then pkill "$(printf "$t2" | awk -F : "NR==$o {printf \$5}")"
              else
                path=$(printf "$t2" | awk -F : "NR==$o {printf \$4}")

                case ${loc:0:1} in
                  E)
                    [ "$name" = OpenVPN ] && {
                        lsmod | grep -q ^tun || insmod /lib/modules/tun.ko
                      } || {
                        [ "$name" = Transmission ] && setsid $path-blist start
                      }

                    setsid $path start
                    ;;
                  U)
                    setsid chroot /ubuntu ${path:7} >/dev/null 2>&1
                    ;;
                  I)
                    setsid /usr/local/etc/rc.d/wireguard.sh start
                    usleep 500000
                esac
              fi

              break
              ;;
            ""|0)
              break
          esac
        done

        break
        ;;
      ""|0)
        echo
        exit 0
    esac
  done
done
