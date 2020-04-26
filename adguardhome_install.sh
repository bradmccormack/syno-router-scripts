#!/bin/sh
#
# AdGuard Home server installer script for Synology routers
# Compatible with Entware (soft-float) and Ubuntu chroot (hard-float)
# Tested only on RT2600ac in Wireless Router mode
#
# 2020, Krisztián Kende <krisztiankende@gmail.com>
#
# This script can be used freely at your own risk.
# I will not take any responsibility!
#

vers=1.4 # 2020.04.26
adguardhome_vers=0.101.0 # For download
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
      printf "The AdGuard Home is already installed on Ubuntu!\n Secondary installation is not a good idea."
      ;;
    7)
      printf "The AdGuard Home is already installed on Entware!\n Secondary installation is not a good idea."
      ;;
    8)
      printf "Sorry, but not enough free space to install the AdGuard Home!"
      ;;
    9)
      printf "Sorry, but failed to download the AdGuard Home version $adguardhome_vers!\n Please update the installer."
  esac

  printf "\n\n The script is ended without any effect!\e[0m\n\n"
  exit $1
} >&2

setting()
{
  cat << EOF >etc/adguardhome/adguardhome.conf
bind_host: $bh
bind_port: 3000
users:
- name: synology
  password: \$2a\$10\$JVrDPjdmaQkCvdjobQXxM.mQnhTefyfKMXJJdAV/RstG101m95Ch6
language: ""
rlimit_nofile: 0
web_session_ttl: 720
dns:
  bind_host: $bh
  port: 3053
  statistics_interval: 1
  querylog_enabled: true
  querylog_interval: 30
  querylog_memsize: 0
  protection_enabled: true
  blocking_mode: default
  blocking_ipv4: ""
  blocking_ipv6: ""
  blocked_response_ttl: 10
  ratelimit: 20
  ratelimit_whitelist: []
  refuse_any: true
  bootstrap_dns:
  - 1.1.1.1
  - 1.0.0.1
  - 2606:4700:4700::1111
  - 2606:4700:4700::1001
  all_servers: false
  edns_client_subnet: false
  aaaa_disabled: false
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts: []
  parental_block_host: family-block.dns.adguard.com
  safebrowsing_block_host: standard-block.dns.adguard.com
  cache_size: 1048576
  upstream_dns:
  - https://security.cloudflare-dns.com/dns-query
  filtering_enabled: true
  filters_update_interval: 12
  parental_enabled: false
  safesearch_enabled: false
  safebrowsing_enabled: false
  safebrowsing_cache_size: 262144
  safesearch_cache_size: 262144
  parental_cache_size: 262144
  cache_time: 30
  rewrites: []
  blocked_services: []
tls:
  enabled: false
  server_name: ""
  force_https: false
  port_https: 443
  port_dns_over_tls: 853
  allow_unencrypted_doh: false
  strict_sni_check: false
  certificate_chain: ""
  private_key: ""
  certificate_path: ""
  private_key_path: ""
filters:
- enabled: true
  url: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
  name: AdGuard Simplified Domain Names filter
  id: 1
- enabled: false
  url: https://adaway.org/hosts.txt
  name: AdAway
  id: 2
- enabled: false
  url: https://www.malwaredomainlist.com/hostslist/hosts.txt
  name: MalwareDomainList.com Hosts List
  id: 3
- enabled: false
  url: https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
  name: StevenBlack's Unified Hosts List
  id: 4
- enabled: false
  url: https://mirror1.malwaredomains.com/files/justdomains
  name: MalwareDomains
  id: 5
- enabled: false
  url: http://sysctl.org/cameleon/hosts
  name: Cameleon
  id: 6
- enabled: false
  url: https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
  name: Disconnect.me Tracking
  id: 7
- enabled: false
  url: https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
  name: Disconnect.me Ads
  id: 8
whitelist_filters: []
user_rules: []
dhcp:
  enabled: false
  interface_name: ""
  gateway_ip: ""
  subnet_mask: ""
  range_start: ""
  range_end: ""
  lease_duration: 86400
  icmp_timeout_msec: 1000
clients: []
log_file: ""
verbose: false
schema_version: 6
EOF
}

setup()
{
  cd $1
  [ $(df . | awk "NR==2 {printf \$4}") -lt 262144 ] && error 8 # 256 MiB free space check
  wget -O adguardhome.tgz https://github.com/AdguardTeam/AdGuardHome/releases/download/v$adguardhome_vers/AdGuardHome_linux_arm.tar.gz || error 9
  tar -xf adguardhome.tgz AdGuardHome/AdGuardHome --strip-components 1
  rm adguardhome.tgz
  mv AdGuardHome bin/adguardhome
  chown 0:0 bin/adguardhome
  bh=$(ifconfig lbr0 | egrep -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -1)

  [ -d etc/adguardhome ] && {
      pidof adguardhome >/dev/null && {
          killall adguardhome
          cnt=20

          while pidof adguardhome && [ $((cnt--)) -ne 0 ]
          do usleep 500000
          done

          pidof adguardhome >/dev/null && killall -9 adguardhome
        }

      [ -s etc/adguardhome/adguardhome.conf ] || setting
    } || {
      mkdir etc/adguardhome
      setting
    }
}

[ $(id -u) -eq 0 ] || error 1
rname="$(head -c 8 /proc/sys/kernel/syno_hw_version 2>/dev/null)"
printf "$rname" | egrep -q $(printf "$syno_routers" | sed "s/ /|/g") || error 2
ping -c 1 www.google.com >/dev/null 2>&1 || error 3
printf "\e[2J\e[1;1H\ec\n\e[1mAdGuard Home server installer script for Synology routers v$vers by Kendek\n\n 1\e[0m - Install into the existing Entware environment\n \e[1m2\e[0m - Install into the existing Ubuntu chroot environment\n \e[1m0\e[0m - Quit (default)\n\n"

while :
do
  read -p "Select an option [0-2]: " o

  case $o in
    1)
      [ -f /opt/bin/opkg ] || error 4
      [ -s /ubuntu/usr/local/bin/adguardhome ] && error 6
      setup /opt

      cat << EOF >etc/init.d/S99adguardhome
#!/bin/sh

ENABLED=yes
PROCS=adguardhome
ARGS="-c /opt/etc/adguardhome/adguardhome.conf -w /opt/etc/adguardhome"
PREARGS=""
DESC=\$PROCS
PATH=/opt/sbin:/opt/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/syno/sbin:/usr/syno/bin:/usr/local/sbin:/usr/local/bin
IPTABLES=/sbin/iptables
IPTRULE="PREROUTING -t nat -i lbr0 -p udp --dport 53 -j REDIRECT --to-port 3053"

. /opt/etc/init.d/rc.func
rv=\$?

case \$1 in
  start|restart)
    [ \$rv -eq 0 ] || exit \$rv
    \$IPTABLES -C \$IPTRULE 2>/dev/null || \$IPTABLES -A \$IPTRULE
    ;;
  stop)
    \$IPTABLES -D \$IPTRULE
esac
EOF

      chmod +x etc/init.d/S99adguardhome
      setsid etc/init.d/S99adguardhome start
      break
      ;;
    2)
      [ -f /ubuntu/usr/bin/apt ] || error 5
      [ -s /opt/bin/adguardhome ] && error 7
      setup /ubuntu/usr/local

      cat << EOF >/ubuntu/autostart/adguardhome.sh
#!/bin/sh

pidof adguardhome || {
    adguardhome -c /usr/local/etc/adguardhome/adguardhome.conf -w /usr/local/etc/adguardhome &
    chroot /mnt/Synology iptables -t nat -A PREROUTING -i lbr0 -p udp --dport 53 -j REDIRECT --to-port 3053
  }
EOF

      chmod +x /ubuntu/autostart/adguardhome.sh
      chroot /ubuntu /usr/bin/apt update 2>/dev/null
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated full-upgrade -y
      chroot /ubuntu /usr/bin/apt --allow-unauthenticated install ca-certificates --no-install-recommends -y
      chroot /ubuntu /usr/bin/apt clean
      setsid chroot /ubuntu /autostart/adguardhome.sh >/dev/null 2>&1
      break
      ;;
    ""|0)
      echo
      exit 0
  esac
done

sync
printf "\e[2J\e[1;1H\ec\n \e[1mOkay, all done!\n\n The AdGuard Home WebUI is available on '$bh:3000'.\e[0m\n\n"
