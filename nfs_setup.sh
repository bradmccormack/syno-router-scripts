#!/bin/sh
#
# NFS server setup script for Synology routers
# Tested only on RT2600ac in Wireless Router mode
#
# 2018, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#

vers=1.5 # 2018.05.19
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
      printf "Failed to detect any modifications in the router internal filesystem!"
  esac

  printf "\n\n The script is ended without any effect!\e[0m\n\n"
  exit $1
} >&2

[ $(id -u) -eq 0 ] || error 1
egrep -sq $(printf "$syno_routers" | sed -e s/^/^/ -e "s/ /|^/g") /proc/sys/kernel/syno_hw_version || error 2
printf "\e[2J\e[1;1H\ec\n\e[1mNFS server setup script for Synology routers v$vers by Kendek\n\n 1\e[0m - Setup NFSv4.1 share for the currently mounted external devices\n \e[1m2\e[0m - Remove all modifications from the router internal filesystem\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-2]: " o

  case $o in
    1)
      grep -q ^nfsv4_enable=no /etc/nfs/syno_nfs_conf && sed -i s/^nfsv4_enable=no/nfsv4_enable=yes/ /etc/nfs/syno_nfs_conf
      grep -q "/usr/sbin/nfsd \$N$" /usr/syno/etc/rc.sysv/S83nfsd.sh && sed -i "s/\/usr\/sbin\/nfsd \$N$/\/usr\/sbin\/nfsd \$N -V 4.1/" /usr/syno/etc/rc.sysv/S83nfsd.sh
      exp=""

      for mp in $(grep " /volumeUSB" /proc/mounts | cut -d " " -f 2 | cut -d / -f 2-3 | sort -u)
      do exp="$exp/$mp *(rw,mp,async,insecure,insecure_locks,no_root_squash,anonuid=1024,anongid=100)\n"
      done

      printf "$exp" >/etc/exports
      sfile=/usr/local/etc/rc.d/nfs.sh
      csum=68353465971859096b0d906e99503ea3 # Avoid unnecessary write operations on the internal eMMC chip

      [ -s $sfile ] && [ "$(python -c "import hashlib ; print(hashlib.md5(open('$sfile', 'rb').read()).hexdigest())")" =  "$csum" ] || cat << EOF >$sfile # 'md5sum' is missing from the router system
#!/bin/sh

nfs()
{
  mpts="\$(cut -d " " -f 1 /etc/exports)"
  num=\$(echo "\$mpts" | wc -l)
  lmt="\$(date -ur /etc/exports)"
  tout=30

  while :
  do
    mlst="\$(cat /proc/mounts)"
    cnt=0

    for mp in \$mpts
    do
      printf "\$mlst" | grep " \$mp " || break
      let ++cnt
    done

    [ \$((tout--)) -eq 0 ] || [ "\$(date -ur /etc/exports)" != "\$lmt" ] && exit 0
    [ \$num -eq \$cnt ] && break
    sleep 10s
  done

  /usr/syno/etc/rc.sysv/S83nfsd.sh start
}

[ "\$1" = start ] && [ -s /etc/exports ] && nfs >/dev/null 2>&1 &
EOF

      [ -x $sfile ] || chmod +x $sfile
      /usr/syno/etc/rc.sysv/S83nfsd.sh restart
      break
      ;;
    2)
      [ -f /etc/exports ] || [ -f /usr/local/etc/rc.d/nfs.sh ] || grep -q ^nfsv4_enable=yes /etc/nfs/syno_nfs_conf || grep -q "/usr/sbin/nfsd \$N -V 4.1" /usr/syno/etc/rc.sysv/S83nfsd.sh || error 3
      rm /etc/exports /usr/local/etc/rc.d/nfs.sh
      sed -i s/^nfsv4_enable=yes/nfsv4_enable=no/ /etc/nfs/syno_nfs_conf
      sed -i "s/\/usr\/sbin\/nfsd \$N -V 4.1/\/usr\/sbin\/nfsd \$N/" /usr/syno/etc/rc.sysv/S83nfsd.sh
      break
      ;;
    ""|0)
      echo
      exit 0
  esac
done

sync
printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\e[0m\n\n"
[ -f /etc/exports ] || exit 0
printf " \e[1mExample mount command(s):\e[0m\n\n"
ip="$(ifconfig lbr0 | egrep -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -1)"

for mp in $(cut -d " " -f 1 /etc/exports)
do echo "  mount.nfs -o vers=4,minorversion=1 $ip:$mp /mnt"
done

echo
