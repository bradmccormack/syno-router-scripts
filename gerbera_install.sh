#!/bin/sh
#
# Gerbera installer script for Synology routers
# Compatible with Entware (soft-float) and Ubuntu chroot (hard-float)
# Tested only on RT2600ac in Wireless Router mode
#
# 2018-2019, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#
#
# NOTE: issues with Samsung SMART TVs
#

vers=1.6 # 2019.07.21
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
      printf "The Gerbera is already installed!"
      ;;
    7)
      printf "The Gerbera is already installed on Ubuntu!\n Secondary installation is not a good idea."
      ;;
    8)
      printf "The Gerbera is already installed on Entware!\n Secondary installation is not a good idea."
      ;;
    9)
      printf "Sorry, but not enough free space to install the Gerbera!"
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
<?xml version="1.0" encoding="UTF-8"?>
<config version="2" xmlns="http://mediatomb.cc/config/2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://mediatomb.cc/config/2 http://mediatomb.cc/config/2.xsd">
  <!--
     See http://gerbera.io or read the docs for more
     information on creating and using config.xml configration files.
    -->
  <server>
    <ui enabled="yes" show-tooltips="yes">
      <accounts enabled="no" session-timeout="30">
        <account user="gerbera" password="gerbera"/>
      </accounts>
    </ui>
    <port>50500</port>
    <interface>lbr0</interface>
    <name>Synology</name>
    <udn>uuid:$(uuidgen)</udn>
    <home>$2</home>
    <webroot>$3/share/gerbera/web</webroot>
    <!--
        How frequently (in seconds) to send ssdp:alive advertisements.
        Minimum alive value accepted is: 62

        The advertisement will be sent every (A/2)-30 seconds,
        and will have a cache-control max-age of A where A is
        the value configured here. Ex: A value of 62 will result
        in an SSDP advertisement being sent every second.
    -->
    <alive>1800</alive>
    <storage>
      <sqlite3 enabled="yes">
        <database-file>gerbera.db</database-file>
      </sqlite3>
    </storage>
    <protocolInfo extend="yes"/>
    <custom-http-headers>
      <add header="transferMode.dlna.org: Streaming"/>
      <add header="contentFeatures.dlna.org: DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=017000 00000000000000000000000000"/>
    </custom-http-headers>
    <extended-runtime-options>
      <mark-played-items enabled="no" suppress-cds-updates="yes">
        <string mode="prepend">*</string>
        <mark>
          <content>video</content>
        </mark>
      </mark-played-items>
    </extended-runtime-options>
  </server>
  <import hidden-files="no">
    <scripting script-charset="UTF-8">
      <common-script>$3/share/gerbera/js/common.js</common-script>
      <playlist-script>$3/share/gerbera/js/playlists.js</playlist-script>
      <virtual-layout type="disabled">
        <import-script>$3/share/gerbera/js/import.js</import-script>
      </virtual-layout>
    </scripting>
    <mappings>
      <extension-mimetype ignore-unknown="no">
        <map from="mp3" to="audio/mpeg"/>
        <map from="ogx" to="application/ogg"/>
        <map from="ogv" to="video/ogg"/>
        <map from="oga" to="audio/ogg"/>
        <map from="ogg" to="audio/ogg"/>
        <map from="ogm" to="video/ogg"/>
        <map from="asf" to="video/x-ms-asf"/>
        <map from="asx" to="video/x-ms-asf"/>
        <map from="wma" to="audio/x-ms-wma"/>
        <map from="wax" to="audio/x-ms-wax"/>
        <map from="wmv" to="video/x-ms-wmv"/>
        <map from="wvx" to="video/x-ms-wvx"/>
        <map from="wm" to="video/x-ms-wm"/>
        <map from="wmx" to="video/x-ms-wmx"/>
        <map from="m3u" to="audio/x-mpegurl"/>
        <map from="pls" to="audio/x-scpls"/>
        <map from="flv" to="video/x-flv"/>
        <map from="mkv" to="video/x-matroska"/>
        <map from="mkv" to="video/mpeg"/>
        <map from="mka" to="audio/x-matroska"/>
        <map from="avi" to="video/avi"/>
        <map from="avi" to="video/divx"/>
        <map from="avi" to="video/mpeg"/>
      </extension-mimetype>
      <mimetype-upnpclass>
        <map from="audio/*" to="object.item.audioItem.musicTrack"/>
        <map from="video/*" to="object.item.videoItem"/>
        <map from="image/*" to="object.item.imageItem"/>
        <map from="application/ogg" to="object.item.audioItem.musicTrack"/>
      </mimetype-upnpclass>
      <mimetype-contenttype>
        <treat mimetype="audio/mpeg" as="mp3"/>
        <treat mimetype="application/ogg" as="ogg"/>
        <treat mimetype="audio/ogg" as="ogg"/>
        <treat mimetype="audio/x-flac" as="flac"/>
        <treat mimetype="audio/x-ms-wma" as="wma"/>
        <treat mimetype="audio/x-wavpack" as="wv"/>
        <treat mimetype="image/jpeg" as="jpg"/>
        <treat mimetype="audio/x-mpegurl" as="playlist"/>
        <treat mimetype="audio/x-scpls" as="playlist"/>
        <treat mimetype="audio/x-wav" as="pcm"/>
        <treat mimetype="audio/L16" as="pcm"/>
        <treat mimetype="video/x-msvideo" as="avi"/>
        <treat mimetype="video/mp4" as="mp4"/>
        <treat mimetype="audio/mp4" as="mp4"/>
        <treat mimetype="video/x-matroska" as="mkv"/>
        <treat mimetype="audio/x-matroska" as="mka"/>
      </mimetype-contenttype>
    </mappings>
    <online-content>
      <YouTube enabled="no" refresh="28800" update-at-start="no" purge-after="604800" racy-content="exclude" format="mp4" hd="no">
        <favorites user="gerbera"/>
        <standardfeed feed="most_viewed" time-range="today"/>
        <playlists user="gerbera"/>
        <uploads user="gerbera"/>
        <standardfeed feed="recently_featured" time-range="today"/>
      </YouTube>
    </online-content>
  </import>
  <transcoding enabled="no">
    <mimetype-profile-mappings>
      <transcode mimetype="video/x-flv" using="vlcmpeg"/>
      <transcode mimetype="application/ogg" using="vlcmpeg"/>
      <transcode mimetype="application/ogg" using="oggflac2raw"/>
      <transcode mimetype="audio/x-flac" using="oggflac2raw"/>
    </mimetype-profile-mappings>
    <profiles>
      <profile name="oggflac2raw" enabled="no" type="external">
        <mimetype>audio/L16</mimetype>
        <accept-url>no</accept-url>
        <first-resource>yes</first-resource>
        <accept-ogg-theora>no</accept-ogg-theora>
        <agent command="ogg123" arguments="-d raw -o byteorder:big -f %out %in"/>
        <buffer size="1048576" chunk-size="131072" fill-size="262144"/>
      </profile>
      <profile name="vlcmpeg" enabled="no" type="external">
        <mimetype>video/mpeg</mimetype>
        <accept-url>yes</accept-url>
        <first-resource>yes</first-resource>
        <accept-ogg-theora>yes</accept-ogg-theora>
        <agent command="vlc" arguments="-I dummy %in --sout #transcode{venc=ffmpeg,vcodec=mp2v,vb=4096,fps=25,aenc=ffmpeg,acodec=mpga,ab=192,samplerate=44100,channels=2}:standard{access=file,mux=ps,dst=%out} vlc:quit"/>
        <buffer size="14400000" chunk-size="512000" fill-size="120000"/>
      </profile>
    </profiles>
  </transcoding>
</config>
EOF
}

[ $(id -u) -eq 0 ] || error 1
egrep -sq $(printf "$syno_routers" | sed -e s/^/^/ -e "s/ /|^/g") /proc/sys/kernel/syno_hw_version || error 2
ping -c 1 www.google.com >/dev/null 2>&1 || error 3
printf "\e[2J\e[1;1H\ec\n\e[1mGerbera installer script for Synology routers v$vers by Kendek\n\n 1\e[0m - Install through the existing Entware environment\n \e[1m2\e[0m - Install through the existing Ubuntu chroot environment\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-2]: " o

  case $o in
    1)
      [ -f /opt/bin/opkg ] || error 4
      [ -f /opt/bin/gerbera ] && error 6
      [ -f /ubuntu/usr/bin/gerbera ] && error 7
      [ $(df /opt | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check
      [ -s /opt/etc/gerbera/config.xml ] && pset=1 || pset="" # Do not override previous settings when reinstall
      /opt/bin/opkg update
      /opt/bin/opkg upgrade
      /opt/bin/opkg install gerbera
      [ -f /opt/bin/gerbera ] || errd
      [ "$pset" ] || setting /opt/etc/gerbera/config.xml /opt/etc/gerbera /opt
      /opt/etc/init.d/S90gerbera start
      break
      ;;
    2)
      [ -f /ubuntu/usr/bin/apt ] || error 5
      [ -f /ubuntu/usr/bin/gerbera ] && error 6
      [ -f /opt/bin/gerbera ] && error 8
      [ $(df /ubuntu | awk "NR==2 {printf \$4}") -lt 262144 ] && error 9 # 256 MiB free space check
      [ -s /ubuntu/etc/gerbera/config.xml ] && pset=1 || pset="" # Do not override previous settings when reinstall
      chroot /ubuntu /usr/bin/apt update 2>/dev/null
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated full-upgrade -y
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated install gerbera --no-install-recommends -y
      chroot /ubuntu /usr/bin/apt clean
      [ -f /ubuntu/usr/bin/gerbera ] || errd
      [ "$pset" ] || setting /ubuntu/etc/gerbera/config.xml /var/lib/gerbera /usr

      cat << EOF >/ubuntu/autostart/gerbera.sh
#!/bin/sh

pidof gerbera || service gerbera start
EOF

      chmod +x /ubuntu/autostart/gerbera.sh
      chroot /ubuntu /autostart/gerbera.sh >/dev/null 2>&1
      break
      ;;
    ""|0)
      echo
      exit 0
  esac
done

sync
printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The Gerbera WebUI is available on 'http://$(ifconfig lbr0 | egrep -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -1):50500'.\e[0m\n\n"
