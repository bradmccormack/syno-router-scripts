#!/bin/sh
#
# MiniDLNA (ReadyMedia) installer script for Synology routers
# Compatible with Entware (soft-float) and Ubuntu chroot (hard-float)
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
      printf "Sorry, but failed to detect the internet connection!"
      ;;
    4)
      printf "Sorry, but failed to detect any existing Entware environment!\n Please run 'sh entware_install.sh' command."
      ;;
    5)
      printf "Sorry, but failed to detect any existing Ubuntu chroot environment!\n Please run 'sh ubuntu_install.sh' command."
      ;;
    6)
      printf "The MiniDLNA is already installed!"
      ;;
    7)
      printf "The MiniDLNA is already installed on Ubuntu!\n Secondary installation is not a good idea."
      ;;
    8)
      printf "The MiniDLNA is already installed on Entware!\n Secondary installation is not a good idea."
      ;;
    9)
      printf "Sorry, but not enough free space to install the MiniDLNA!"
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
  cat << EOF >$1 # 'notify_interval=90000' to avoid disconnections
# port for HTTP (descriptions, SOAP, media transfer) traffic
port=8200

# network interfaces to serve, comma delimited
network_interface=lbr0

# specify the user account name or uid to run as
#user=root

# set this to the directory you want scanned.
# * if you want multiple directories, you can have multiple media_dir= lines
# * if you want to restrict a media_dir to specific content types, you
#   can prepend the types, followed by a comma, to the directory:
#   + "A" for audio  (eg. media_dir=A,/home/jmaggard/Music)
#   + "V" for video  (eg. media_dir=V,/home/jmaggard/Videos)
#   + "P" for images (eg. media_dir=P,/home/jmaggard/Pictures)
#   + "PV" for pictures and video (eg. media_dir=PV,/home/jmaggard/digital_camera)
media_dir=$2

# set this to merge all media_dir base contents into the root container
# note: the default is no
#merge_media_dirs=no

# set this if you want to customize the name that shows up on your clients
friendly_name=Synology

# set this if you would like to specify the directory where you want MiniDLNA to store its database and album art cache
db_dir=$3

# set this if you would like to specify the directory where you want MiniDLNA to store its log file
log_dir=$4

# set this to change the verbosity of the information that is logged
# each section can use a different level: off, fatal, error, warn, info, or debug
log_level=general,artwork,database,inotify,scanner,metadata,http,ssdp,tivo=off

# this should be a list of file names to check for when searching for album art
# note: names should be delimited with a forward slash ("/")
#album_art_names=Cover.jpg/cover.jpg/AlbumArtSmall.jpg/albumartsmall.jpg/AlbumArt.jpg/albumart.jpg/Album.jpg/album.jpg/Folder.jpg/folder.jpg/Thumb.jpg/thumb.jpg

# set this to no to disable inotify monitoring to automatically discover new files
# note: the default is yes
inotify=yes

# set this to yes to enable support for streaming .jpg and .mp3 files to a TiVo supporting HMO
#enable_tivo=no

# set this to beacon to use legacy broadcast discovery method
# defauts to bonjour if avahi is available
#tivo_discovery=bonjour

# set this to strictly adhere to DLNA standards.
# * This will allow server-side downscaling of very large JPEG images,
#   which may hurt JPEG serving performance on (at least) Sony DLNA products.
#strict_dlna=no

# default presentation url is http address on port 80
#presentation_url=http://www.mylan/index.php

# notify interval in seconds. default is 895 seconds.
notify_interval=90000

# serial and model number the daemon will report to clients
# in its XML description
#serial=12345678
#model_number=1

# specify the path to the MiniSSDPd socket
#minissdpdsocket=/var/run/minissdpd.sock

# use different container as root of the tree
# possible values:
#   + "." - use standard container (this is the default)
#   + "B" - "Browse Directory"
#   + "M" - "Music"
#   + "V" - "Video"
#   + "P" - "Pictures"
#   + Or, you can specify the ObjectID of your desired root container (eg. 1$F for Music/Playlists)
# if you specify "B" and client device is audio-only then "Music/Folders" will be used as root
root_container=B

# always force SortCriteria to this value, regardless of the SortCriteria passed by the client
#force_sort_criteria=+upnp:class,+upnp:originalTrackNumber,+dc:title

# maximum number of simultaneous connections
# note: many clients open several simultaneous connections while streaming
#max_connections=50

# set this to yes to allow symlinks that point outside user-defined media_dirs.
#wide_links=no
EOF
}

[ $(id -u) -eq 0 ] || error 1
egrep -sq $(printf "$syno_routers" | sed -e s/^/^/ -e "s/ /|^/g") /proc/sys/kernel/syno_hw_version || error 2
ping -c 1 www.google.com >/dev/null 2>&1 || error 3
printf "\e[2J\e[1;1H\ec\n\e[1mMiniDLNA (ReadyMedia) installer script for Synology routers v$vers by Kendek\n\n 1\e[0m - Install through the existing Entware environment\n \e[1m2\e[0m - Install through the existing Ubuntu chroot environment\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-2]: " o

  case $o in
    1)
      [ -f /opt/bin/opkg ] || error 4
      [ -f /opt/bin/minidlna ] && error 6
      [ -f /ubuntu/usr/sbin/minidlnad ] && error 7
      [ $(df /opt | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check
      [ -s /opt/etc/minidlna.conf ] && pset=1 || pset="" # Do not override previous settings when reinstall
      /opt/bin/opkg update
      /opt/bin/opkg upgrade
      /opt/bin/opkg install minidlna
      [ -f /opt/bin/minidlna ] || errd
      [ "$pset" ] || setting /opt/etc/minidlna.conf /opt/.. /opt/var/minidlna /opt/var/minidlna
      /opt/etc/init.d/S90minidlna start
      break
      ;;
    2)
      [ -f /ubuntu/usr/bin/apt ] || error 5
      [ -f /ubuntu/usr/sbin/minidlnad ] && error 6
      [ -f /opt/bin/minidlna ] && error 8
      [ $(df /ubuntu | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check
      [ -s /ubuntu/etc/minidlna.conf ] && pset=1 || pset="" # Do not override previous settings when reinstall
      chroot /ubuntu /usr/bin/apt update 2>/dev/null
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated dist-upgrade -y
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated install minidlna --no-install-recommends -y
      chroot /ubuntu /usr/bin/apt clean
      [ -f /ubuntu/usr/sbin/minidlnad ] || errd
      [ "$pset" ] || setting /ubuntu/etc/minidlna.conf /mnt/HDD /var/cache/minidlna /var/log

      cat << EOF >/ubuntu/autostart/minidlna.sh
#!/bin/sh

[ "\$(pidof minidlnad)" ] || minidlnad
EOF

      chmod +x /ubuntu/autostart/minidlna.sh
      chroot /ubuntu /autostart/minidlna.sh >/dev/null 2>&1
      break
      ;;
    ""|0)
      echo
      exit 0
  esac
done

sync
printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The MiniDLNA (ReadyMedia) WebUI is available on 'http://$(ifconfig lbr0 | egrep -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -1):8200'.\e[0m\n\n"
