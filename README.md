# Scripts collection for Synology routers

**Be careful, these install, setup and control scripts are only compatible with each other!  
All scripts were tested only in Wireless Router mode!**

Currently supported models:
- MR2200ac
- RT2600ac
- RT1900ac

## Table of contents

- [syno-router-scripts.sh](#syno-router-scriptssh)
- [entware_install.sh](#entware_installsh)
- [ubuntu_install.sh](#ubuntu_installsh)
- [transmission_install.sh](#transmission_installsh)
- [openvpn_install.sh](#openvpn_installsh)
- [minidlna_install.sh](#minidlna_installsh)
- [gerbera_install.sh](#gerbera_installsh)
- [plex_install.sh](#plex_installsh)
- [nfs_setup.sh](#nfs_setupsh)
- [services_control.sh](#services_controlsh)

## syno-router-scripts.sh

This all-in-one script is help to execute the others.  
Additional commands are not necessary.

Requirements:
- SSH connection with 'root' user (admin password)

Usage:
```sh
sh -c "$(wget -O- goo.gl/Pkyohd)"
```

![](https://logout.hu/dl/upc/2018-01/180556_executor.png)

## entware_install.sh

This installer script is help to fully initialize an Entware environment, including a SWAP file.  
It may need to run the option 2 after the major SRM updates.

Requirements:
- SSH connection with 'root' user (admin password)
- USB attached external storage device (like HDD, SSD or pendrive) or memory card (SD) in the card reader slot
- One ext4-formatted partition with minimum 1.5 GiB free space

Usage:
```sh
sh -c "$(wget -O- goo.gl/bQMA17)"

opkg install <package>
opkg update # Update the package list
opkg upgrade # Upgrade the packages
```

![](https://logout.hu/dl/upc/2018-05/180556_entware.png)

## ubuntu_install.sh

This installer script is help to fully initialize a Ubuntu chroot environment, including a SWAP file.  
The average performance is greater than with Entware.  
It may need to run the option 2 after the major SRM updates.

Requirements:
- SSH connection with 'root' user (admin password)
- USB attached external storage device (like HDD, SSD or pendrive) or memory card (SD) in the card reader slot
- One ext4-formatted partition with minimum 1.5 GiB free space

Usage:
```sh
sh -c "$(wget -O- goo.gl/aBC8BP)"

apt install <package>
apt-upgrade # Upgrade the packages
uroot # Chroot into the Ubuntu installation
```

![](https://logout.hu/dl/upc/2018-05/180556_ubuntu.png)

## transmission_install.sh

This installer script is help to install a Transmission torrent client through Entware or Ubuntu.  
The download directory is created on the same partition.

Requirements:
- SSH connection with 'root' user (admin password)
- Entware or Ubuntu chroot environment, installed with above scripts
- A web browser for the WebUI

Necessary firewall rules:

 Protocol | Source IP | Source port | Destination IP | Destination port | Action
:--------:|:---------:|:-----------:|:--------------:|:----------------:|:------:
 TCP/UDP  | All       | All         | SRM            | 51413            | Allow

Usage:
```sh
sh -c "$(wget -O- goo.gl/Hs8yNU)"
```

![](https://logout.hu/dl/upc/2018-01/180556_transmission_2.png)

## openvpn_install.sh

This installer script is help to install a secure OpenVPN (v2.4) server through Entware or Ubuntu.  
An allowed user's credentials are needed for the connection, beyond the strong certificates and keys.

Requirements:
- SSH connection with 'root' user (admin password)
- Entware or Ubuntu chroot environment, installed with above scripts
- Own and globally-unique public IPv4 address, without carrier-grade NAT
- Optionally, a compatible (v2.4) OpenVPN client

Necessary firewall rules for connection:

 Protocol | Source IP              | Source port | Destination IP            | Destination port | Action
:--------:|:----------------------:|:-----------:|:-------------------------:|:----------------:|:------:
 UDP      | All                    | All         | SRM                       | 1194             | Allow

Necessary firewall rules for access to local network:

 Protocol | Source IP              | Source port | Destination IP            | Destination port | Action
:--------:|:----------------------:|:-----------:|:-------------------------:|:----------------:|:------:
 TCP/UDP  | 10.8.0.0/255.255.255.0 | All         | All                       | All              | Allow

Usage:
```sh
sh -c "$(wget -O- goo.gl/nxXR9Q)"
```

![](https://logout.hu/dl/upc/2018-01/180556_openvpn_4.png)

## minidlna_install.sh

This installer script is help to install a MiniDLNA (ReadyMedia) media server through Entware or Ubuntu.  
The partition content will be indexed and watched. The *minidlnad* process may causes high CPU usage when the Transmission torrent client is active. In this case need to change the *media_dir* value in the *etc/minidlna.conf* file.

Requirements:
- SSH connection with 'root' user (admin password)
- Entware or Ubuntu chroot environment, installed with above scripts
- Optionally, a UPnP-compatible client (like a smart TV)

Usage:
```sh
sh -c "$(wget -O- goo.gl/y7HbAJ)"
```

![](https://logout.hu/dl/upc/2018-01/180556_minidlna_2.png)

## gerbera_install.sh

This installer script is help to install a Gerbera media server through Entware or Ubuntu.  
The media database can be edited through WebUI.

Requirements:
- SSH connection with 'root' user (admin password)
- Entware or Ubuntu chroot environment, installed with above scripts
- A web browser for the WebUI
- Optionally, a UPnP-compatible client (like a smart TV)

Usage:
```sh
sh -c "$(wget -O- goo.gl/wYzAU1)"
```

![](https://logout.hu/dl/upc/2018-01/180556_gerbera.png)

## plex_install.sh

This installer script is help to install a Plex Media Server into Entware or Ubuntu.  
Some features does not work because of hardware limitations.

Requirements:
- SSH connection with 'root' user (admin password)
- Entware or Ubuntu chroot environment, installed with above scripts
- At least 512 MiB SWAP
- A web browser for the WebUI

Necessary firewall rules for remote access:

 Protocol | Source IP | Source port | Destination IP | Destination port | Action
:--------:|:---------:|:-----------:|:--------------:|:----------------:|:------:
 TCP      | All       | All         | SRM            | 32400            | Allow

Usage:
```sh
sh -c "$(wget -O- goo.gl/WDG9ih)"
```

![](https://logout.hu/dl/upc/2018-01/180556_plex_2.png)

## nfs_setup.sh

This setup script is help to configure and activate an NFSv4.1 server, taking into account the currently mounted external storage devices.  
It may need to rerun when the mount points are changed, or after the major SRM updates.

Requirements:
- SSH connection with 'root' user (admin password)
- Optionally, a compatible client (like Kodi)

Usage:
```sh
sh -c "$(wget -O- goo.gl/kHHpwN)"
```

![](https://logout.hu/dl/upc/2018-05/180556_nfs.png)

## services_control.sh

This control script is help to disable, enable and uninstall the Transmission, OpenVPN, MiniDLNA, Gerbera and Plex Media Server services.

Requirements:
- SSH connection with 'root' user (admin password)

Usage:
```sh
sh -c "$(wget -O- goo.gl/ynPr4p)"
```

![](https://logout.hu/dl/upc/2018-10/180556_services.png)
