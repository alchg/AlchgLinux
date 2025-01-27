#! /bin/bash

if !(type "mkarchiso" > /dev/null 2>&1); then
echo "archiso not found."
echo "please install.ex: pacman -S archiso"
return 2>/dev/null
exit
fi


if [ $(whoami) != "root" ]; then
echo "require root"
return 2>/dev/null
exit

fi

rm -r ./archlive
mkdir ./archlive
cp -r /usr/share/archiso/configs/releng/* ./archlive/

set -e




sed -i "s/'xz' '-Xbcj' 'x86'/'zstd' '-Xcompression-level' '19'/" ./archlive/profiledef.sh
sed -i "s/'-Xdict-size' '1M'//" ./archlive/profiledef.sh


sed -i "s/^linux$//" ./archlive/packages.x86_64
cat >>./archlive/packages.x86_64<<"EOF"
linux-lts
otf-ipafont
xorg-server
xorg-xinit
openbox
tint2
network-manager-applet
xcompmgr
alsa-utils
volumeicon
pulseaudio
pulseaudio-jack
pulseaudio-bluetooth
bluez
bluez-utils
xdotool
zenity
fcitx5-im
fcitx5-mozc
lxrandr
conky
nitrogen
i3lock
vi
qterminal
firefox
netsurf
vinagre
virt-viewer
EOF

#gnome-packagekit
#xfce4-notifyd


cat >./archlive/airootfs/etc/mkinitcpio.d/linux-lts.preset<<"EOF"
PRESETS=('archiso')

ALL_kver='/boot/vmlinuz-linux-lts'
ALL_config='/etc/mkinitcpio.conf.d/archiso.conf'

archiso_image="/boot/initramfs-linux-lts.img"
EOF
cat >./archlive/airootfs/etc/mkinitcpio.d/linux.preset<<"EOF"
EOF

sed -i "s/TIMEOUT 150/TIMEOUT 50/" ./archlive/syslinux/archiso_sys.cfg
sed -i "s/timeout 15/timeout 5/" ./archlive/efiboot/loader/loader.conf
sed -i "s/beep on/beep off/" ./archlive/efiboot/loader/loader.conf
sed -i "s/timeout=15/timeout=5/" ./archlive/grub/grub.cfg

cat >./archlive/efiboot/loader/entries/04-archiso-x86_64-ram-linux.conf<<"EOF"
title    Arch Linux install medium (x86_64, UEFI, CopyToRAM)
sort-key 04
linux    /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux-lts
initrd   /%INSTALL_DIR%/boot/x86_64/initramfs-linux-lts.img
options  archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% copytoram=y
EOF

sed -i s/vmlinuz-linux/vmlinuz-linux-lts/ ./archlive/syslinux/archiso_sys-linux.cfg
sed -i s/vmlinuz-linux/vmlinuz-linux-lts/ ./archlive/efiboot/loader/entries/01-archiso-x86_64-linux.conf
sed -i s/vmlinuz-linux/vmlinuz-linux-lts/ ./archlive/efiboot/loader/entries/02-archiso-x86_64-speech-linux.conf
#sed -i s/vmlinuz-linux/vmlinuz-linux-lts/ ./archlive/efiboot/loader/entries/03-archiso-x86_64-ram-linux.conf

sed -i s/initramfs-linux/initramfs-linux-lts/ ./archlive/syslinux/archiso_sys-linux.cfg
sed -i s/initramfs-linux/initramfs-linux-lts/ ./archlive/efiboot/loader/entries/01-archiso-x86_64-linux.conf
sed -i s/initramfs-linux/initramfs-linux-lts/ ./archlive/efiboot/loader/entries/02-archiso-x86_64-speech-linux.conf
#sed -i s/initramfs-linux/initramfs-linux-lts/ ./archlive/efiboot/loader/entries/03-archiso-x86_64-ram-linux.conf


sed -i s/vmlinuz-linux/vmlinuz-linux-lts/ ./archlive/grub/grub.cfg
sed -i s/initramfs-linux/initramfs-linux-lts/ ./archlive/grub/grub.cfg

sed -i /APPEND/s/$/\ copytoram=n/ ./archlive/syslinux/archiso_sys-linux.cfg
sed -i /vmlinuz/s/$/\ copytoram=n/ ./archlive/grub/grub.cfg


cat >>./archlive/syslinux/archiso_sys-linux.cfg<<"EOF"

# Copy to RAM boot option
LABEL arch64ram
TEXT HELP
Boot the Arch Linux install medium on BIOS with Copy-to-RAM option
It allows you to install Arch Linux or perform system maintenance.
ENDTEXT
MENU LABEL Arch Linux install medium (x86_64, BIOS, Copy to RAM)
LINUX /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux-lts
INITRD /%INSTALL_DIR%/boot/x86_64/initramfs-linux-lts.img
APPEND archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% copytoram=y
EOF

sed -i "/# Menu entries/a}" ./archlive/grub/grub.cfg
sed -i "/# Menu entries/a\    initrd /%INSTALL_DIR%/boot/intel-ucode.img /%INSTALL_DIR%/boot/amd-ucode.img /%INSTALL_DIR%/boot/x86_64/initramfs-linux-lts.img" ./archlive/grub/grub.cfg
sed -i "/# Menu entries/a\    linux /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux-lts archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% copytoram" ./archlive/grub/grub.cfg
sed -i "/# Menu entries/a\    search --no-floppy --set=root --label %ARCHISO_LABEL%" ./archlive/grub/grub.cfg
sed -i "/# Menu entries/a\    set gfxpayload=keep" ./archlive/grub/grub.cfg
sed -i "/# Menu entries/amenuentry \"Arch Linux install medium (x86_64, UEFI, Copy to RAM)\" --class arch --class gnu-linux --class gnu --class os --id 'archlinux-copytoram' {" ./archlive/grub/grub.cfg

sed -i s/play\ 600\ 988\ 1\ 1319\ 4/play\ 1200\ 1319\ 1/ ./archlive/grub/grub.cfg

sed -i s/"xz"/"zstd"/ ./archlive/airootfs/etc/mkinitcpio.conf.d/archiso.conf
echo "COMPRESSION_OPTIONS=('-19')" >> ./archlive/airootfs/etc/mkinitcpio.conf.d/archiso.conf


cat >./archlive/airootfs/etc/systemd/system/alchg.service<<"EOF"
[Unit]
Description=alchg configuration

[Service]
Type=simple
ExecStart=/usr/local/sbin/alchg.sh

[Install]
WantedBy=multi-user.target
EOF

mkdir ./archlive/airootfs/usr/local/sbin/
cat >./archlive/airootfs/usr/local/sbin/alchg.sh<<"EOF"
#! /bin/bash

ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
timedatectl set-ntp yes

/usr/local/sbin/cowspace.sh

systemctl start NetworkManager.service
systemctl start bluetooth.service

cp /usr/share/X11/xorg.conf.d/40-libinput.conf /etc/X11/xorg.conf.d/30-touchpad.conf
sed -i '38i        Option "Tapping" "on"' /etc/X11/xorg.conf.d/30-touchpad.conf
sed -i '39i        Option "ClickMethod" "clickfinger"' /etc/X11/xorg.conf.d/30-touchpad.conf

sed -i s/"utilities-terminal"/"qterminal"/ /usr/share/applications/qterminal.desktop

passwd root<<"PWD"
root
root
PWD


EOF

#mkdir ./archlive/airootfs/etc/sysctl.d/
#cat >./archlive/airootfs/etc/sysctl.d/99-sysctl.conf<<"EOF"
#vm.overcommit_memory = 1
#EOF

cat >./archlive/airootfs/usr/local/sbin/cowspace.sh<<"EOF"
#! /bin/bash

MEM=`free --mebi|grep Mem|awk '{print $2}'`
SWP=`free --mebi|grep Swap|awk '{print $2}'`
REQ=1850
SYS=1600
SFS=0

if [ $MEM -ge $REQ ];then
        if [ -e /run/archiso/copytoram/airootfs.sfs ];then
                SFS=`du -m /run/archiso/copytoram/airootfs.sfs |awk '{print $1}'`
                REQ=`expr $REQ + $SFS`

                if [ $MEM -ge $REQ ];then
                        mount -o remount,size=`expr $MEM + $SWP - $SYS - $SFS`M /run/archiso/cowspace
                fi
        else
                mount -o remount,size=`expr $MEM + $SWP - $SYS`M /run/archiso/cowspace
        fi
fi

EOF


sed -i '/^)/i\ \ ["/usr/local/sbin/alchg.sh"]="0:0:700"' ./archlive/profiledef.sh
sed -i '/^)/i\ \ ["/usr/local/sbin/cowspace.sh"]="0:0:700"' ./archlive/profiledef.sh
sed -i '/^)/i\ \ ["/etc/skel/alchg/conky.sh"]="0:0:755"' ./archlive/profiledef.sh
sed -i '/^)/i\ \ ["/etc/skel/alchg/conky_transparent.sh"]="0:0:755"' ./archlive/profiledef.sh
sed -i '/^)/i\ \ ["/etc/skel/alchg/lxrandr.sh"]="0:0:755"' ./archlive/profiledef.sh
sed -i '/^)/i\ \ ["/etc/skel/alchg/exec.sh"]="0:0:755"' ./archlive/profiledef.sh
sed -i '/^)/i\ \ ["/etc/skel/alchg/menu.sh"]="0:0:755"' ./archlive/profiledef.sh

sed -i "s/ignore/suspend/" ./archlive/airootfs/etc/systemd/logind.conf.d/do-not-suspend.conf
echo "HandlePowerKey=suspend" >>./archlive/airootfs/etc/systemd/logind.conf.d/do-not-suspend.conf

sed -i s/root/user/  ./archlive/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf
cat >>./archlive/airootfs/etc/passwd<<"EOF"
user:x:1000:985::/home/user:/bin/bash
EOF
cat >>./archlive/airootfs/etc/shadow<<EOF
user:!:18680:0:99999::::
EOF

mkdir -p ./archlive/airootfs/etc/systemd/system/multi-user.target.wants
ln -s /usr/lib/systemd/system/alchg.service ./archlive/airootfs/etc/systemd/system/multi-user.target.wants/

# Deprecated
cat >./archlive/airootfs/root/customize_airootfs.sh<<"EOF"
#!/bin/bash

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
EOF





#########################################################
#Configuration files and others
#########################################################
mkdir ./archlive/airootfs/etc/skel


mkdir ./archlive/airootfs/etc/skel/alchg
cat >>./archlive/airootfs/etc/skel/.bash_profile<<"EOF"
#
# ~/.bash_profile
#
[[ -f ~/.bashrc ]] && . ~/.bashrc
until [ "$LMODE" = "1" ]  || [ "$LMODE" = "2" ]
do
        echo "SELECT LANGUAGE(1 or 2)"
        echo ""
        echo "1:JAPANESE(DEFAULT)"
        echo "2:ENGLISH"
        echo ""
        read -p \>  -t 5 LMODE
        if [ "$LMODE" = "" ]
        then
        LMODE=1
        fi
done
if [ "$LMODE" = "1" ]
then
cp .config/openbox/menu_jp.xml .config/openbox/menu.xml
cp .xinitrc_jp .xinitrc
sed -i 's/time2_format = %a\/%d\/%b/time2_format = %B%d日 %A/' .config/tint2/tint2rc
fi
if [ "$LMODE" = "2" ]
then
cp .config/openbox/menu_en.xml .config/openbox/menu.xml
cp .xinitrc_en .xinitrc
sed -i 's/time2_format = %B%d日 %A/time2_format = %a\/%d\/%b/' .config/tint2/tint2rc
fi


[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx
EOF
cp ./archlive/airootfs/etc/skel/.bash_profile ./archlive/airootfs/etc/skel/.zprofile 



cat >>./archlive/airootfs/etc/skel/.xinitrc_jp<<"EOF"
#!/bin/sh

userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

# merge in defaults and keymaps

if [ -f $sysresources ]; then







    xrdb -merge $sysresources

fi

if [ -f $sysmodmap ]; then
    xmodmap $sysmodmap
fi

if [ -f "$userresources" ]; then







    xrdb -merge "$userresources"

fi

if [ -f "$usermodmap" ]; then
    xmodmap "$usermodmap"
fi

# start some nice programs

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
 for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
  [ -x "$f" ] && . "$f"
 done
 unset f
fi


#twm &
#xclock -geometry 50x50-1+1 &
#xterm -geometry 80x50+494+51 &
#xterm -geometry 80x20+494-0 &
#exec xterm -geometry 80x66+0+0 -name login
export LANG=ja_JP.UTF-8
setxkbmap jp &
sleep 2 && fcitx5 &
#xrandr --output Virtual-1 --mode 1366x768 &
tint2 &
nitrogen --restore &
nm-applet &
xcompmgr &
exec openbox-session
EOF

cat >>./archlive/airootfs/etc/skel/.xinitrc_en<<"EOF"
#!/bin/sh

userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

# merge in defaults and keymaps

if [ -f $sysresources ]; then







    xrdb -merge $sysresources

fi

if [ -f $sysmodmap ]; then
    xmodmap $sysmodmap
fi

if [ -f "$userresources" ]; then







    xrdb -merge "$userresources"

fi

if [ -f "$usermodmap" ]; then
    xmodmap "$usermodmap"
fi

# start some nice programs

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
 for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
  [ -x "$f" ] && . "$f"
 done
 unset f
fi


#twm &
#xclock -geometry 50x50-1+1 &
#xterm -geometry 80x50+494+51 &
#xterm -geometry 80x20+494-0 &
#exec xterm -geometry 80x66+0+0 -name login
#xrandr --output Virtual-1 --mode 1366x768 &
tint2 &
nitrogen --restore &
nm-applet &
xcompmgr &
exec openbox-session
EOF



cat >./archlive/airootfs/etc/skel/alchg/exec.sh<<'EOFILE'
#! /bin/bash

set -e

TTL="Authentication"
MSG="Enter root password.(default:root)"
if [ "$LANG" = "ja_JP.UTF-8" ]
then
        TTL="認証"
        MSG="rootパスワードを入力して下さい。(既定値:root)"
fi

VALUE=$(zenity --entry --hide-text --title "$TTL" --text "$MSG")

su -c "$1"<<EOF
$VALUE
EOF
EOFILE



cat >./archlive/airootfs/etc/skel/alchg/menu.sh<<"EOF"
#! /bin/bash

xdotool key Super_L
EOF


mkdir ./archlive/airootfs/usr/share/
mkdir -p ./archlive/airootfs/usr/share/themes/Alchg/openbox-3/
cat >./archlive/airootfs/usr/share/themes/Alchg/openbox-3/themerc<<"EOF"
#openbox themerc edited with obtheme
border.color: #44454D
border.width: 2
menu.border.width: 0
menu.items.active.bg: Solid Flat
menu.items.active.bg.color: #44454D
menu.items.active.text.color: #f8f8f8
menu.items.bg: Solid Flat
menu.items.bg.color: #2E2F37
menu.items.disabled.text.color: #606060
menu.items.font: shadow=y:shadowtint=30:shadowoffset=1
menu.items.text.color: #b8b8b8
menu.overlap: 0
menu.separator.padding.height: 3
menu.title.bg: Solid Flat
menu.title.bg.color: #2E2F37
menu.title.text.color: #FFFFFF
menu.title.text.font: shadow=n
menu.title.text.justify: center
osd.bg: gradient vertical flat
osd.bg.color: #303030
osd.bg.colorTo: #080808
padding.width: 6
window.active.border.color: #2E2F37
window.active.button.disabled.bg: parentrelative
window.active.button.disabled.image.color: #707070
window.active.button.pressed.bg: parentrelative
window.active.button.toggled.hover.bg: parentrelative
window.active.button.toggled.hover.bg: flat splitvertical gradient border
window.active.button.toggled.hover.bg.color: #398dc6
window.active.button.toggled.hover.bg.colorTo: #236d83
window.active.button.toggled.hover.bg.border.color: #236d83
window.active.button.toggled.pressed.bg: parentrelative
window.active.button.toggled.pressed.bg: flat splitvertical gradient border
window.active.button.toggled.pressed.bg.color: #235679
window.active.button.toggled.pressed.bg.colorTo: #154350
window.active.button.toggled.pressed.bg.border.color: #154350
window.active.button.unpressed.bg: parentrelative
window.active.button.unpressed.image.color: #e0e0e0
window.active.client.color: #2E2F37
window.active.label.bg: parentrelative
window.active.label.text.color: #f8f8f8
window.active.title.bg: Solid Flat
window.active.title.bg.color: #2E2F37
window.client.padding.width: 1
window.handle.width: 0
window.inactive.border.color: #404040
window.inactive.button.disabled.bg: parentrelative
window.inactive.button.disabled.image.color: #c0c0c0
window.inactive.button.pressed.bg: parentrelative
window.inactive.button.toggled.hover.bg: parentrelative
window.inactive.button.toggled.hover.bg: parentrelative
window.inactive.button.toggled.image.color: #747474
window.inactive.button.toggled.pressed.bg: parentrelative
window.inactive.button.toggled.pressed.bg: flat splitvertical gradient border
window.inactive.button.toggled.pressed.bg.color: #4ab5ff
window.inactive.button.toggled.pressed.bg.colorTo: #38b3d6
window.inactive.button.toggled.pressed.bg.border.color: #38b3d6
window.inactive.button.unpressed.bg: parentrelative
window.inactive.button.unpressed.image.color: #747474
window.inactive.client.color: #CACAB6
window.inactive.label.bg: parentrelative
window.inactive.label.text.color: #747474
window.inactive.title.bg: Solid Flat
window.inactive.title.bg.color: #44454D
window.inactive.title.separator.color: #eeeee6
window.label.text.justify: center
EOF

mkdir -p ./archlive/airootfs/etc/skel/.local/share/applications
cat >./archlive/airootfs/etc/skel/.local/share/applications/open-openbox-menu.desktop<<"EOF"
[Desktop Entry]
Type=Application
Encoding=UTF-8
Name=OpenBoxMenu
Comment=AndroidStudio
Exec=/home/user/alchg/menu.sh
Icon=/home/user/icon/menu.png

Terminal=false
EOF


cat >./archlive/airootfs/etc/environment<<"EOF"
#
# This file is parsed by pam_env module
#
# Syntax: simple "KEY=VAL" pairs on separate lines
#
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF


cat >./archlive/airootfs/etc/skel/alchg/conky.sh<<"EOF"
#! /bin/bash

cat >/home/user/.config/conky/conky.conf.skel.details<<"EOFCONKY"
--[[
Conky, a system monitor, based on torsmo

Any original torsmo code is licensed under the BSD license

All code written since the fork of torsmo is licensed under the GPL

Please see COPYING for details

Copyright (c) 2004, Hannu Saransaari and Lauri Hakkarainen
Copyright (c) 2005-2019 Brenden Matthews, Philip Kovacs, et. al. (see AUTHORS)
All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

conky.config = {
    alignment = 'top_right',
    background = false,
    border_width = 1,
    cpu_avg_samples = 2,
    default_color = 'white',
    default_outline_color = 'white',
    default_shade_color = 'white',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = false,
    draw_outline = false,
    draw_shades = false,
    extra_newline = false,
    font = 'DejaVu Sans Mono:size=12',
    gap_x = 25,
    gap_y = -20,
    minimum_height = 5,
    minimum_width = 220,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_ncurses = false,
    out_to_stderr = false,
    out_to_x = true,
    own_window = true,
    own_window_class = 'Conky',
    own_window_type = 'window',
    own_window_transparent = true,
    own_window_argb_visual = true, 
    own_window_argb_value = 150,
    show_graph_range = false,
    show_graph_scale = false,
    stippled_borders = 0,
    update_interval = 1.0,
    uppercase = false,
    use_spacer = 'none',
    use_xft = true,
}

conky.text = [[
${color grey}SysInfo $hr
${color grey}Host     :$color $nodename
${color grey}Machine  :$color $machine
${color grey}System   :$color $sysname
${color grey}Kernel   :$color $kernel
${color grey}UpTime   :$color $uptime

${color grey}Cpu $hr
${color grey}Frequency:$color $freq Mhz
${color grey}Usage    :$color ${cpu cpu0}%
${color grey}Running  :$color $running_processes

${color grey}Mem $hr
${color grey}Capacity :$color $memmax
${color grey}Used     :$color $mem
${color grey}Free     :$color $memfree
${color grey}Cached   :$color $cached
${color grey}Buffers  :$color $buffers
${color grey}Swap     :$color $swap

${color grey}FileSys(/) $hr
${color grey}Capacity :$color ${fs_size /}
${color grey}Used     :$color ${fs_used /}
${color grey}Free     :$color ${fs_free /}

]]
EOFCONKY

nmcli dev|awk '$2 ~ /^ethernet$/{print $1}'|xargs -I {} bash -c "FILE=/home/user/.config/conky/conky.conf.skel.details && sed -i '93i\$alignc' \$FILE && sed -i '93i\${color grey}Down     : \$color\${downspeed {}}' \$FILE && sed -i '93i\${color grey}Up       : \$color\${upspeed {}}' \$FILE && sed -i '93i\${color grey}IP       :\$color \${addr {}}' \$FILE && sed -i '93i\${color grey}Ethernet({}) \$hr' \$FILE"


nmcli dev|awk '$2 ~ /^wifi$/{print $1}'|xargs -I {} bash -c "FILE=/home/user/.config/conky/conky.conf.skel.details && sed -i '93i\$alignc' \$FILE && sed -i '93i\${color grey}Down     : \$color\${downspeed {}}' \$FILE && sed -i '93i\${color grey}Up       : \$color\${upspeed {}}' \$FILE && sed -i '93i\${color grey}IP       :\$color \${addr {}}' \$FILE && sed -i '93i\${color grey}Wifi({}) \$hr' \$FILE"

sed -i "s/own_window_transparent = false/own_window_transparent = true/" /home/user/.config/conky/conky.conf

EOF

cat >./archlive/airootfs/etc/skel/alchg/conky_transparent.sh<<"EOF"
#! /bin/bash

set -e

FILE1=/home/user/.config/conky/conky.conf.skel.details
FILE2=/home/user/.config/conky/conky.conf

if grep "own_window_transparent = true" $FILE1 ;then
        sed -i "s/own_window_transparent = true/own_window_transparent = false/" $FILE1
else
        sed -i "s/own_window_transparent = false/own_window_transparent = true/" $FILE1
fi

sleep 1s

if grep "own_window_transparent = true" $FILE2 ;then
        sed -i "s/own_window_transparent = true/own_window_transparent = false/" $FILE2
else
        sed -i "s/own_window_transparent = false/own_window_transparent = true/" $FILE2
fi

EOF

cat >./archlive/airootfs/etc/skel/alchg/lxrandr.sh<<"EOF"
#! /bin/bash

lxrandr
echo "" >>/home/user/.config/conky/conky.conf
nitrogen --restore
EOF


mkdir -p ./archlive/airootfs/usr/share/icons/hicolor/64x64/apps/
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/usr/share/icons/hicolor/64x64/apps/utilities-terminal.png" "https://icon-icons.com/downloadimage.php?id=34340&root=317/PNG/64/&file=terminal-icon_34340.png";do date;echo RETRY;done

mkdir ./archlive/airootfs/etc/skel/icon/
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/icon/menu.png" "http://flat-icon-design.com/f/f_event_52/s128_f_event_52_1nbg.png";do date;echo RETRY;done

mkdir ./archlive/airootfs/etc/skel/wallpaper/
for i in  {0..50}
do
	IDX=0$i
	NUM=${IDX: -2:2}
	until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper$NUM.jpg" "https://raw.githubusercontent.com/alchg/AlchgLinux/main/images/wallpaper/wallpaper$NUM.jpg";do date;echo RETRY;done
done


mkdir ./archlive/airootfs/etc/skel/.config/


mkdir ./archlive/airootfs/etc/skel/.config/qterminal.org/
cat >./archlive/airootfs/etc/skel/.config/qterminal.org/qterminal.ini<<"EOF"
[General]
AskOnExit=false
BookmarksFile=/home/user/.config/qterminal.org/qterminal_bookmarks.xml
BookmarksVisible=true
Borderless=false
ChangeWindowIcon=true
ChangeWindowTitle=true
ConfirmMultilinePaste=false
FixedTabWidth=false
FixedTabWidthValue=500
HideTabBarWithOneTab=false
HistoryLimited=true
HistoryLimitedTo=1000
KeyboardCursorShape=0
LastWindowMaximized=false
MenuVisible=true
MotionAfterPaste=0
SavePosOnExit=true
SaveSizeOnExit=true
ScrollbarPosition=2
ShowCloseTabButton=true
TabBarless=false
TabsPosition=0
Term=xterm-256color
TerminalBackgroundImage=
TerminalMargin=0
TerminalTransparency=25
TerminalsPreset=0
TrimPastedTrailingNewlines=false
UseBookmarks=false
UseCWD=false
colorScheme=Linux
emulation=default
enabledBidiSupport=true
fontFamily=Source Code Pro
fontSize=10
guiStyle=
highlightCurrentTerminal=false
showTerminalSizeHint=true
version=0.14.1

[DropMode]
Height=45
KeepOpen=false
ShortCut=F12
ShowOnStart=true
Width=70

[MainWindow]
ApplicationTransparency=0
isMaximized=false
pos=@Point(120 43)
size=@Size(640 480)
state=@ByteArray(\0\0\0\xff\0\0\0\0\xfd\0\0\0\x1\0\0\0\0\0\0\0\0\0\0\0\0\xfc\x2\0\0\0\x1\xfb\0\0\0&\0\x42\0o\0o\0k\0m\0\x61\0r\0k\0s\0\x44\0o\0\x63\0k\0W\0i\0\x64\0g\0\x65\0t\0\0\0\0\0\xff\xff\xff\xff\0\0\0r\0\xff\xff\xff\0\0\x2\x80\0\0\x1\xce\0\0\0\x4\0\0\0\x4\0\0\0\b\0\0\0\b\xfc\0\0\0\0)

[Sessions]
size=0

[Shortcuts]
Add%20Tab=Ctrl+T
Bottom%20Subterminal=Alt+Down
Clear%20Active%20Terminal=Ctrl+Shift+X
Close%20Tab=Ctrl+W
Collapse%20Subterminal=
Copy%20Selection=Ctrl+Shift+C
Find=Ctrl+Shift+F
Fullscreen=F11
Hide%20Window%20Borders=
Left%20Subterminal=Alt+Left
Move%20Tab%20Left=Alt+Shift+Left|Ctrl+Shift+PgUp
Move%20Tab%20Right=Alt+Shift+Right|Ctrl+Shift+PgDown
New%20Window=Ctrl+Shift+N
Next%20Tab=Ctrl+Tab
Next%20Tab%20in%20History=Ctrl+PgDown
Paste%20Clipboard=Ctrl+Shift+V
Preferences...=
Previous%20Tab=Ctrl+Shift+Tab
Previous%20Tab%20in%20History=Ctrl+PgUp
Quit=
Rename%20Session=Alt+Shift+S
Right%20Subterminal=Alt+Right
Show%20Tab%20Bar=
Split%20Terminal%20Horizontally=
Split%20Terminal%20Vertically=
Toggle%20Bookmarks=Ctrl+Shift+B
Toggle%20Menu=Ctrl+Shift+M
Top%20Subterminal=Alt+Up
Zoom%20in=Ctrl++
Zoom%20out=Ctrl+-
Zoom%20reset=Ctrl+0

EOF

mkdir ./archlive/airootfs/etc/skel/.config/volumeicon/
cat >./archlive/airootfs/etc/skel/.config/volumeicon/volumeicon<<"EOF"
[Alsa]
card=default

[Notification]
show_notification=true
notification_type=0

[StatusIcon]
stepsize=5
onclick=xterm -e 'alsamixer'
theme=Default
use_panel_specific_icons=false
lmb_slider=true
mmb_mute=false
use_horizontal_slider=false
show_sound_level=false
use_transparent_background=false

[Hotkeys]
up_enabled=false
down_enabled=false
mute_enabled=false
up=XF86AudioRaiseVolume
down=XF86AudioLowerVolume
mute=XF86AudioMute
EOF

mkdir ./archlive/airootfs/etc/skel/.config/nitrogen/
cat >./archlive/airootfs/etc/skel/.config/nitrogen/bg-saved.cfg<<"EOF"
[xin_-1]
file=/home/user/wallpaper/wallpaper21.jpg
mode=0
bgcolor=#000000
EOF

cat >./archlive/airootfs/etc/skel/.config/nitrogen/nitrogen.cfg<<"EOF"
[geometry]
posx=0
posy=0
sizex=514
sizey=500

[nitrogen]
view=icon
recurse=true
sort=alpha
icon_caps=false
dirs=
EOF


mkdir ./archlive/airootfs/etc/skel/.config/openbox
cat >./archlive/airootfs/etc/skel/.config/openbox/autostart<<"EOF"
(sleep 1s && volumeicon) &
(sleep 1s && /home/user/alchg/conky.sh) &
(sleep 3s && conky) &
EOF

cat >./archlive/airootfs/etc/skel/.config/openbox/menu_jp.xml<<"EOF"
<?xml version="1.0" encoding="UTF-8"?>

<openbox_menu xmlns="http://openbox.org/3.4/menu">

<menu id="apps-term-menu" label="端末">
  <item label="Qterminal">
    <action name="Execute">
      <command>qterminal</command>
    </action>
  </item>
  <item label="Qterminal（管理者）">
    <action name="Execute">
      <command>/home/user/alchg/exec.sh qterminal</command>
    </action>
  </item>
</menu>

<menu id="apps-web-browser-menu" label="ウェブブラウザ">
  <item label="Firefox">
    <action name="Execute">
     <command>firefox</command>
    </action>
  </item>
  <item label="NetSurf">
    <action name="Execute">
     <command>netsurf</command>
    </action>
  </item>
</menu>

<menu id="apps-remote-menu" label="リモート">
  <item label="Vinagre">
    <action name="Execute">
     <command>vinagre</command>
    </action>
  </item>
  <item label="Virt Viewer">
    <action name="Execute">
     <command>remote-viewer</command>
    </action>
  </item>
</menu>

<menu id="alchg-menu" label="Alchg">
  <item label="ラムディスク最適化">
    <action name="Execute">
      <command>/home/user/alchg/exec.sh /usr/local/sbin/cowspace.sh</command>
    </action>
  </item>
  <item label="システムモニタ背景透過切替">
    <action name="Execute">
      <command>/home/user/alchg/conky_transparent.sh</command>
    </action>
  </item>
</menu>

<menu id="system-menu" label="設定">
  <item label="システムモニタ">
    <action name="Execute">
      <command>conky -c /home/user/.config/conky/conky.conf.skel.details</command>
    </action>
  </item>
  <item label="壁紙">
    <action name="Execute">
     <command>nitrogen /home/user/wallpaper/</command>
    </action>
  </item>
  <item label="画面">
    <action name="Execute">
     <command>/home/user/alchg/lxrandr.sh</command>
    </action>
  </item>
  <item label="日本語入力">
    <action name="Execute">
     <command>fcitx5-configtool</command>
    </action>
  </item>
  <item label="タスクバー">
    <action name="Execute">
     <command>tint2conf</command>
    </action>
  </item>
  <menu id="alchg-menu"/>
</menu>

<menu id="exit-menu" label="終了">
  <item label="電源オフ">
    <action name="Execute">
       <command>systemctl poweroff</command>
    </action>
  </item>
  <item label="再起動">
    <action name="Execute">
      <command>systemctl reboot</command>
    </action>
  </item>
  <item label="省電力待機">
    <action name="Execute">
      <command>systemctl suspend</command>
    </action>
  </item>
  <item label="画面ロック">
    <action name="Execute">
      <command>/home/user/alchg/exec.sh "i3lock -c 222222"</command>
    </action>
  </item>
  <item label="ログアウト">
    <action name="Execute">
      <command>openbox --exit</command>
    </action>
  </item>
</menu>

<menu id="root-menu" label="Openbox 3">
  <separator label="アプリケーション" />
  <item label="Firefox">
    <action name="Execute">
     <command>firefox</command>
    </action>
  </item>
  <menu id="apps-web-browser-menu"/>
  <menu id="apps-remote-menu"/>
  <menu id="apps-term-menu"/>
  <separator label="システム" />
  <menu id="system-menu"/>
  <menu id="exit-menu"/>
</menu>

</openbox_menu>
EOF

cat >./archlive/airootfs/etc/skel/.config/openbox/menu_en.xml<<"EOF"
<?xml version="1.0" encoding="UTF-8"?>

<openbox_menu xmlns="http://openbox.org/3.4/menu">

<menu id="apps-term-menu" label="Term">
  <item label="Qterminal">
    <action name="Execute">
      <command>qterminal</command>
    </action>
  </item>
  <item label="Qterminal(root)">
    <action name="Execute">
      <command>/home/user/alchg/exec.sh qterminal</command>
    </action>
  </item>
</menu>

<menu id="apps-web-browser-menu" label="Web Browser">
  <item label="Firefox">
    <action name="Execute">
     <command>firefox</command>
    </action>
  </item>
  <item label="NetSurf">
    <action name="Execute">
     <command>netsurf</command>
    </action>
  </item>
</menu>

<menu id="apps-remote-menu" label="Remote">
  <item label="Vinagre">
    <action name="Execute">
     <command>vinagre</command>
    </action>
  </item>
  <item label="Virt Viewer">
    <action name="Execute">
     <command>remote-viewer</command>
    </action>
  </item>
</menu>

<menu id="alchg-menu" label="Alchg">
  <item label="Ramdisk Update">
    <action name="Execute">
      <command>/home/user/alchg/exec.sh /usr/local/sbin/cowspace.sh</command>
    </action>
  </item>
  <item label="SystemMonitor Transparent Toggle">
    <action name="Execute">
      <command>/home/user/alchg/conky_transparent.sh</command>
    </action>
  </item>
</menu>

<menu id="system-menu" label="Config">
  <item label="SystemMonitor">
    <action name="Execute">
      <command>conky -c /home/user/.config/conky/conky.conf.skel.details</command>
    </action>
  </item>
  <item label="Wallpaper">
    <action name="Execute">
     <command>nitrogen /home/user/wallpaper/</command>
    </action>
  </item>
  <item label="Screen">
    <action name="Execute">
     <command>/home/user/alchg/lxrandr.sh</command>
    </action>
  </item>
  <item label="TaskBar">
    <action name="Execute">
     <command>tint2conf</command>
    </action>
  </item>
  <menu id="alchg-menu"/>
</menu>

<menu id="exit-menu" label="Exit">
  <item label="shutdown">
    <action name="Execute">
       <command>systemctl poweroff</command>
    </action>
  </item>
  <item label="reboot">
    <action name="Execute">
      <command>systemctl reboot</command>
    </action>
  </item>
  <item label="suspend">
    <action name="Execute">
      <command>systemctl suspend</command>
    </action>
  </item>
  <item label="lock screen">
    <action name="Execute">
      <command>/home/user/alchg/exec.sh "i3lock -c 222222"</command>
    </action>
  </item>
  <item label="logout">
    <action name="Execute">
      <command>openbox --exit</command>
    </action>
  </item>
</menu>

<menu id="root-menu" label="Openbox 3">
  <separator label="Application" />
  <item label="Firefox">
    <action name="Execute">
     <command>firefox</command>
    </action>
  </item>
  <menu id="apps-web-browser-menu"/>
  <menu id="apps-remote-menu"/>
  <menu id="apps-term-menu"/>
  <separator label="System" />
  <menu id="system-menu"/>
  <menu id="exit-menu"/>
</menu>

</openbox_menu>
EOF


cat >./archlive/airootfs/etc/skel/.config/openbox/rc.xml<<"EOF"
<?xml version="1.0" encoding="UTF-8"?>

<!-- Do not edit this file, it will be overwritten on install.
        Copy the file to $HOME/.config/openbox/ instead. -->

<openbox_config xmlns="http://openbox.org/3.4/rc"
		xmlns:xi="http://www.w3.org/2001/XInclude">

<resistance>
  <strength>10</strength>
  <screen_edge_strength>20</screen_edge_strength>
</resistance>

<focus>
  <focusNew>yes</focusNew>
  <!-- always try to focus new windows when they appear. other rules do
       apply -->
  <followMouse>no</followMouse>
  <!-- move focus to a window when you move the mouse into it -->
  <focusLast>yes</focusLast>
  <!-- focus the last used window when changing desktops, instead of the one
       under the mouse pointer. when followMouse is enabled -->
  <underMouse>no</underMouse>
  <!-- move focus under the mouse, even when the mouse is not moving -->
  <focusDelay>200</focusDelay>
  <!-- when followMouse is enabled, the mouse must be inside the window for
       this many milliseconds (1000 = 1 sec) before moving focus to it -->
  <raiseOnFocus>no</raiseOnFocus>
  <!-- when followMouse is enabled, and a window is given focus by moving the
       mouse into it, also raise the window -->
</focus>

<placement>
  <policy>Smart</policy>
  <!-- 'Smart' or 'UnderMouse' -->
  <center>yes</center>
  <!-- whether to place windows in the center of the free area found or
       the top left corner -->
  <monitor>Primary</monitor>
  <!-- with Smart placement on a multi-monitor system, try to place new windows
       on: 'Any' - any monitor, 'Mouse' - where the mouse is, 'Active' - where
       the active window is, 'Primary' - only on the primary monitor -->
  <primaryMonitor>1</primaryMonitor>
  <!-- The monitor where Openbox should place popup dialogs such as the
       focus cycling popup, or the desktop switch popup.  It can be an index
       from 1, specifying a particular monitor.  Or it can be one of the
       following: 'Mouse' - where the mouse is, or
                  'Active' - where the active window is -->
</placement>

<theme>
  <name>Alchg</name>
  <titleLayout>NLIMC</titleLayout>
  <!--
      available characters are NDSLIMC, each can occur at most once.
      N: window icon
      L: window label (AKA title).
      I: iconify
      M: maximize
      C: close
      S: shade (roll up/down)
      D: omnipresent (on all desktops).
  -->
  <keepBorder>yes</keepBorder>
  <animateIconify>yes</animateIconify>
  <font place="ActiveWindow">
    <name>sans</name>
    <size>8</size>
    <!-- font size in points -->
    <weight>bold</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
  <font place="InactiveWindow">
    <name>sans</name>
    <size>8</size>
    <!-- font size in points -->
    <weight>bold</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
  <font place="MenuHeader">
    <name>sans</name>
    <size>9</size>
    <!-- font size in points -->
    <weight>normal</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
  <font place="MenuItem">
    <name>sans</name>
    <size>9</size>
    <!-- font size in points -->
    <weight>normal</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
  <font place="ActiveOnScreenDisplay">
    <name>sans</name>
    <size>9</size>
    <!-- font size in points -->
    <weight>bold</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
  <font place="InactiveOnScreenDisplay">
    <name>sans</name>
    <size>9</size>
    <!-- font size in points -->
    <weight>bold</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
</theme>

<desktops>
  <!-- this stuff is only used at startup, pagers allow you to change them
       during a session

       these are default values to use when other ones are not already set
       by other applications, or saved in your session

       use obconf if you want to change these without having to log out
       and back in -->
  <number>4</number>
  <firstdesk>1</firstdesk>
  <names>
    <name>１</name>
    <name>２</name>
    <name>３</name>
    <name>４</name>
    <name>５</name>
    <name>６</name>
    <name>７</name>
    <name>８</name>
    <name>９</name>
    <!-- set names up here if you want to, like this:
    <name>desktop 1</name>
    <name>desktop 2</name>
    -->
  </names>
  <popupTime>875</popupTime>
  <!-- The number of milliseconds to show the popup for when switching
       desktops.  Set this to 0 to disable the popup. -->
</desktops>

<resize>
  <drawContents>yes</drawContents>
  <popupShow>Nonpixel</popupShow>
  <!-- 'Always', 'Never', or 'Nonpixel' (xterms and such) -->
  <popupPosition>Center</popupPosition>
  <!-- 'Center', 'Top', or 'Fixed' -->
  <popupFixedPosition>
    <!-- these are used if popupPosition is set to 'Fixed' -->

    <x>10</x>
    <!-- positive number for distance from left edge, negative number for
         distance from right edge, or 'Center' -->
    <y>10</y>
    <!-- positive number for distance from top edge, negative number for
         distance from bottom edge, or 'Center' -->
  </popupFixedPosition>
</resize>

<!-- You can reserve a portion of your screen where windows will not cover when
     they are maximized, or when they are initially placed.
     Many programs reserve space automatically, but you can use this in other
     cases. -->
<margins>
  <top>0</top>
  <bottom>0</bottom>
  <left>0</left>
  <right>0</right>
</margins>

<dock>
  <position>TopLeft</position>
  <!-- (Top|Bottom)(Left|Right|)|Top|Bottom|Left|Right|Floating -->
  <floatingX>0</floatingX>
  <floatingY>0</floatingY>
  <noStrut>no</noStrut>
  <stacking>Above</stacking>
  <!-- 'Above', 'Normal', or 'Below' -->
  <direction>Vertical</direction>
  <!-- 'Vertical' or 'Horizontal' -->
  <autoHide>no</autoHide>
  <hideDelay>300</hideDelay>
  <!-- in milliseconds (1000 = 1 second) -->
  <showDelay>300</showDelay>
  <!-- in milliseconds (1000 = 1 second) -->
  <moveButton>Middle</moveButton>
  <!-- 'Left', 'Middle', 'Right' -->
</dock>

<keyboard>
  <chainQuitKey>C-g</chainQuitKey>

  <!-- Keybindings for desktop switching -->
  <keybind key="C-A-Left">
    <action name="GoToDesktop"><to>left</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="C-A-Right">
    <action name="GoToDesktop"><to>right</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="C-A-Up">
    <action name="GoToDesktop"><to>up</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="C-A-Down">
    <action name="GoToDesktop"><to>down</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="S-A-Left">
    <action name="SendToDesktop"><to>left</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="S-A-Right">
    <action name="SendToDesktop"><to>right</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="S-A-Up">
    <action name="SendToDesktop"><to>up</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="S-A-Down">
    <action name="SendToDesktop"><to>down</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="W-F1">
    <action name="GoToDesktop"><to>1</to></action>
  </keybind>
  <keybind key="W-F2">
    <action name="GoToDesktop"><to>2</to></action>
  </keybind>
  <keybind key="W-F3">
    <action name="GoToDesktop"><to>3</to></action>
  </keybind>
  <keybind key="W-F4">
    <action name="GoToDesktop"><to>4</to></action>
  </keybind>
  <keybind key="W-d">
    <action name="ToggleShowDesktop"/>
  </keybind>

  <keybind key="Super_L">
    <action name="ShowMenu"><menu>root-menu</menu></action>
  </keybind>

  <!-- Keybindings for windows -->
  <keybind key="A-F4">
    <action name="Close"/>
  </keybind>
  <keybind key="A-Escape">
    <action name="Lower"/>
    <action name="FocusToBottom"/>
    <action name="Unfocus"/>
  </keybind>
  <keybind key="A-space">
    <action name="ShowMenu"><menu>client-menu</menu></action>
  </keybind>

  <!-- Keybindings for window switching -->
  <keybind key="A-Tab">
    <action name="NextWindow">
      <finalactions>
        <action name="Focus"/>
        <action name="Raise"/>
        <action name="Unshade"/>
      </finalactions>
    </action>
  </keybind>
  <keybind key="A-S-Tab">
    <action name="PreviousWindow">
      <finalactions>
        <action name="Focus"/>
        <action name="Raise"/>
        <action name="Unshade"/>
      </finalactions>
    </action>
  </keybind>
  <keybind key="C-A-Tab">
    <action name="NextWindow">
      <panels>yes</panels><desktop>yes</desktop>
      <finalactions>
        <action name="Focus"/>
        <action name="Raise"/>
        <action name="Unshade"/>
      </finalactions>
    </action>
  </keybind>

  <!-- Keybindings for window switching with the arrow keys -->
  <keybind key="W-S-Right">
    <action name="DirectionalCycleWindows">
      <direction>right</direction>
    </action>
  </keybind>
  <keybind key="W-S-Left">
    <action name="DirectionalCycleWindows">
      <direction>left</direction>
    </action>
  </keybind>
  <keybind key="W-S-Up">
    <action name="DirectionalCycleWindows">
      <direction>up</direction>
    </action>
  </keybind>
  <keybind key="W-S-Down">
    <action name="DirectionalCycleWindows">
      <direction>down</direction>
    </action>
  </keybind>

  <!-- Keybindings for running applications -->
  <keybind key="W-e">
    <action name="Execute">
      <startupnotify>
        <enabled>true</enabled>
        <name>Konqueror</name>
      </startupnotify>
      <command>kfmclient openProfile filemanagement</command>
    </action>
  </keybind>
</keyboard>

<mouse>
  <dragThreshold>1</dragThreshold>
  <!-- number of pixels the mouse must move before a drag begins -->
  <doubleClickTime>500</doubleClickTime>
  <!-- in milliseconds (1000 = 1 second) -->
  <screenEdgeWarpTime>400</screenEdgeWarpTime>
  <!-- Time before changing desktops when the pointer touches the edge of the
       screen while moving a window, in milliseconds (1000 = 1 second).
       Set this to 0 to disable warping -->
  <screenEdgeWarpMouse>false</screenEdgeWarpMouse>
  <!-- Set this to TRUE to move the mouse pointer across the desktop when
       switching due to hitting the edge of the screen -->

  <context name="Frame">
    <mousebind button="A-Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="A-Left" action="Click">
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="A-Left" action="Drag">
      <action name="Move"/>
    </mousebind>

    <mousebind button="A-Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="A-Right" action="Drag">
      <action name="Resize"/>
    </mousebind> 

    <mousebind button="A-Middle" action="Press">
      <action name="Lower"/>
      <action name="FocusToBottom"/>
      <action name="Unfocus"/>
    </mousebind>

    <mousebind button="A-Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="A-Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>
    <mousebind button="C-A-Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="C-A-Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>
    <mousebind button="A-S-Up" action="Click">
      <action name="SendToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="A-S-Down" action="Click">
      <action name="SendToDesktop"><to>next</to></action>
    </mousebind>
  </context>

  <context name="Titlebar">
    <mousebind button="Left" action="Drag">
      <action name="Move"/>
    </mousebind>
    <mousebind button="Left" action="DoubleClick">
      <action name="ToggleMaximize"/>
    </mousebind>

    <mousebind button="Up" action="Click">
      <action name="if">
        <shaded>no</shaded>
        <then>
          <action name="Shade"/>
          <action name="FocusToBottom"/>
          <action name="Unfocus"/>
          <action name="Lower"/>
        </then>
      </action>
    </mousebind>
    <mousebind button="Down" action="Click">
      <action name="if">
        <shaded>yes</shaded>
        <then>
          <action name="Unshade"/>
          <action name="Raise"/>
        </then>
      </action>
    </mousebind>
  </context>

  <context name="Titlebar Top Right Bottom Left TLCorner TRCorner BRCorner BLCorner">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>

    <mousebind button="Middle" action="Press">
      <action name="Lower"/>
      <action name="FocusToBottom"/>
      <action name="Unfocus"/>
    </mousebind>

    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="ShowMenu"><menu>client-menu</menu></action>
    </mousebind>
  </context>

  <context name="Top">
    <mousebind button="Left" action="Drag">
      <action name="Resize"><edge>top</edge></action>
    </mousebind>
  </context>

  <context name="Left">
    <mousebind button="Left" action="Drag">
      <action name="Resize"><edge>left</edge></action>
    </mousebind>
  </context>

  <context name="Right">
    <mousebind button="Left" action="Drag">
      <action name="Resize"><edge>right</edge></action>
    </mousebind>
  </context>

  <context name="Bottom">
    <mousebind button="Left" action="Drag">
      <action name="Resize"><edge>bottom</edge></action>
    </mousebind>

    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="ShowMenu"><menu>client-menu</menu></action>
    </mousebind>
  </context>

  <context name="TRCorner BRCorner TLCorner BLCorner">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Left" action="Drag">
      <action name="Resize"/>
    </mousebind>
  </context>

  <context name="Client">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="Middle" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
  </context>

  <context name="Icon">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
      <action name="ShowMenu"><menu>client-menu</menu></action>
    </mousebind>
    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="ShowMenu"><menu>client-menu</menu></action>
    </mousebind>
  </context>

  <context name="AllDesktops">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Left" action="Click">
      <action name="ToggleOmnipresent"/>
    </mousebind>
  </context>

  <context name="Shade">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="Left" action="Click">
      <action name="ToggleShade"/>
    </mousebind>
  </context>

  <context name="Iconify">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="Left" action="Click">
      <action name="Iconify"/>
    </mousebind>
  </context>

  <context name="Maximize">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Middle" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Left" action="Click">
      <action name="ToggleMaximize"/>
    </mousebind>
    <mousebind button="Middle" action="Click">
      <action name="ToggleMaximize"><direction>vertical</direction></action>
    </mousebind>
    <mousebind button="Right" action="Click">
      <action name="ToggleMaximize"><direction>horizontal</direction></action>
    </mousebind>
  </context>

  <context name="Close">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Left" action="Click">
      <action name="Close"/>
    </mousebind>
  </context>

  <context name="Desktop">
    <mousebind button="Up" action="Click">
      <action name="GoToDesktop"><to>previous</to><wrap>no</wrap></action>
    </mousebind>
    <mousebind button="Down" action="Click">
      <action name="GoToDesktop"><to>next</to><wrap>no</wrap></action>
    </mousebind>

    <mousebind button="A-Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="A-Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>
    <mousebind button="C-A-Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="C-A-Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>

    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
  </context>

  <context name="Root">
    <!-- Menus -->
    <mousebind button="Middle" action="Press">
      <action name="ShowMenu"><menu>client-list-combined-menu</menu></action>
    </mousebind> 
    <mousebind button="Right" action="Press">
      <action name="ShowMenu"><menu>root-menu</menu></action>
    </mousebind>
  </context>

  <context name="MoveResize">
    <mousebind button="Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>
    <mousebind button="A-Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="A-Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>
  </context>
</mouse>

<menu>
  <!-- You can specify more than one menu file in here and they are all loaded,
       just don't make menu ids clash or, well, it'll be kind of pointless -->

  <!-- default menu file (or custom one in $HOME/.config/openbox/) -->
  <file>menu.xml</file>
  <hideDelay>200</hideDelay>
  <!-- if a press-release lasts longer than this setting (in milliseconds), the
       menu is hidden again -->
  <middle>no</middle>
  <!-- center submenus vertically about the parent entry -->
  <submenuShowDelay>100</submenuShowDelay>
  <!-- time to delay before showing a submenu after hovering over the parent
       entry.
       if this is a negative value, then the delay is infinite and the
       submenu will not be shown until it is clicked on -->
  <submenuHideDelay>400</submenuHideDelay>
  <!-- time to delay before hiding a submenu when selecting another
       entry in parent menu
       if this is a negative value, then the delay is infinite and the
       submenu will not be hidden until a different submenu is opened -->
  <showIcons>yes</showIcons>
  <!-- controls if icons appear in the client-list-(combined-)menu -->
  <manageDesktops>yes</manageDesktops>
  <!-- show the manage desktops section in the client-list-(combined-)menu -->
</menu>

<applications>
<!--
  # this is an example with comments through out. use these to make your
  # own rules, but without the comments of course.
  # you may use one or more of the name/class/role/title/type rules to specify
  # windows to match

  <application name="the window's _OB_APP_NAME property (see obxprop)"
              class="the window's _OB_APP_CLASS property (see obxprop)"
          groupname="the window's _OB_APP_GROUP_NAME property (see obxprop)"
         groupclass="the window's _OB_APP_GROUP_CLASS property (see obxprop)"
               role="the window's _OB_APP_ROLE property (see obxprop)"
              title="the window's _OB_APP_TITLE property (see obxprop)"
               type="the window's _OB_APP_TYPE property (see obxprob)..
                      (if unspecified, then it is 'dialog' for child windows)">
  # you may set only one of name/class/role/title/type, or you may use more
  # than one together to restrict your matches.

  # the name, class, role, and title use simple wildcard matching such as those
  # used by a shell. you can use * to match any characters and ? to match
  # any single character.

  # the type is one of: normal, dialog, splash, utility, menu, toolbar, dock,
  #    or desktop

  # when multiple rules match a window, they will all be applied, in the
  # order that they appear in this list


    # each rule element can be left out or set to 'default' to specify to not 
    # change that attribute of the window

    <decor>yes</decor>
    # enable or disable window decorations

    <shade>no</shade>
    # make the window shaded when it appears, or not

    <position force="no">
      # the position is only used if both an x and y coordinate are provided
      # (and not set to 'default')
      # when force is "yes", then the window will be placed here even if it
      # says you want it placed elsewhere.  this is to override buggy
      # applications who refuse to behave
      <x>center</x>
      # a number like 50, or 'center' to center on screen. use a negative number
      # to start from the right (or bottom for <y>), ie -50 is 50 pixels from
      # the right edge (or bottom). use 'default' to specify using value
      # provided by the application, or chosen by openbox, instead.
      <y>200</y>
      <monitor>1</monitor>
      # specifies the monitor in a xinerama setup.
      # 1 is the first head, or 'mouse' for wherever the mouse is
    </position>

    <size>
      # the size to make the window.
      <width>20</width>
      # a number like 20, or 'default' to use the size given by the application.
      # you can use fractions such as 1/2 or percentages such as 75% in which
      # case the value is relative to the size of the monitor that the window
      # appears on.
      <height>30%</height>
    </size>

    <focus>yes</focus>
    # if the window should try be given focus when it appears. if this is set
    # to yes it doesn't guarantee the window will be given focus. some
    # restrictions may apply, but Openbox will try to

    <desktop>1</desktop>
    # 1 is the first desktop, 'all' for all desktops

    <layer>normal</layer>
    # 'above', 'normal', or 'below'

    <iconic>no</iconic>
    # make the window iconified when it appears, or not

    <skip_pager>no</skip_pager>
    # asks to not be shown in pagers

    <skip_taskbar>no</skip_taskbar>
    # asks to not be shown in taskbars. window cycling actions will also
    # skip past such windows

    <fullscreen>yes</fullscreen>
    # make the window in fullscreen mode when it appears

    <maximized>true</maximized>
    # 'Horizontal', 'Vertical' or boolean (yes/no)
  </application>

  # end of the example
-->
</applications>

</openbox_config>
EOF

mkdir ./archlive/airootfs/etc/skel/.config/tint2

cat >>./archlive/airootfs/etc/skel/.config/tint2/tint2rc<<"EOF"
#---- Generated by tint2conf a2ab ----
# See https://gitlab.com/o9000/tint2/wikis/Configure for 
# full documentation of the configuration options.
#-------------------------------------
# Gradients
#-------------------------------------
# Backgrounds
# Background 1: Default task, Iconified task, Inactive desktop name
rounded = 0
border_width = 1
border_sides = B
border_content_tint_weight = 0
background_content_tint_weight = 0
background_color = #2e2f37 70
border_color = #2e2f37 70
background_color_hover = #2e2f37 70
border_color_hover = #ffffff 100
background_color_pressed = #555555 4
border_color_pressed = #eaeaea 44

# Background 2: Active taskbar, Battery, Clock, Inactive taskbar, Launcher, Launcher icon, Systray, Tooltip
rounded = 0
border_width = 0
border_sides = 
border_content_tint_weight = 0
background_content_tint_weight = 0
background_color = #2e2f37 70
border_color = #2e2f37 70
background_color_hover = #2e2f37 70
border_color_hover = #ffffff 100
background_color_pressed = #2e2f37 70
border_color_pressed = #ffffff 100

# Background 3: Panel
rounded = 0
border_width = 0
border_sides = 
border_content_tint_weight = 0
background_content_tint_weight = 0
background_color = #2e2f37 70
border_color = #2e2f37 70
background_color_hover = #2e2f37 70
border_color_hover = #ffffff 100
background_color_pressed = #2e2f37 70
border_color_pressed = #ffffff 100

# Background 4: Active task
rounded = 0
border_width = 2
border_sides = B
border_content_tint_weight = 0
background_content_tint_weight = 0
background_color = #44454d 70
border_color = #ffffff 100
background_color_hover = #44454d 75
border_color_hover = #ffffff 100
background_color_pressed = #2e2f37 75
border_color_pressed = #ffffff 100

# Background 5: Active desktop name
rounded = 0
border_width = 0
border_sides = 
border_content_tint_weight = 0
background_content_tint_weight = 0
background_color = #44454d 70
border_color = #ffffff 100
background_color_hover = #44454d 75
border_color_hover = #ffffff 100
background_color_pressed = #2e2f37 75
border_color_pressed = #ffffff 100

#-------------------------------------
# Panel
panel_items = LTSCB
panel_size = 100% 4%
panel_margin = 0 0
panel_padding = 0 0 0
panel_background_id = 3
wm_menu = 1
panel_dock = 0
panel_pivot_struts = 0
panel_position = bottom center horizontal
panel_layer = top
panel_monitor = all
panel_shrink = 0
autohide = 0
autohide_show_timeout = 0
autohide_hide_timeout = 0.5
autohide_height = 2
strut_policy = follow_size
panel_window_name = tint2
disable_transparency = 1
mouse_effects = 1
font_shadow = 0
mouse_hover_icon_asb = 100 0 20
mouse_pressed_icon_asb = 100 0 0
scale_relative_to_dpi = 0
scale_relative_to_screen_height = 0

#-------------------------------------
# Taskbar
taskbar_mode = single_desktop
taskbar_hide_if_empty = 0
taskbar_padding = 0 0 0
taskbar_background_id = 2
taskbar_active_background_id = 2
taskbar_name = 1
taskbar_hide_inactive_tasks = 0
taskbar_hide_different_monitor = 0
taskbar_hide_different_desktop = 1
taskbar_always_show_all_desktop_tasks = 0
taskbar_name_padding = 5 0
taskbar_name_background_id = 1
taskbar_name_active_background_id = 5
taskbar_name_font_color = #44454d 100
taskbar_name_active_font_color = #ffffff 100
taskbar_distribute_size = 1
taskbar_sort_order = none
task_align = left

#-------------------------------------
# Task
task_text = 1
task_icon = 1
task_centered = 0
urgent_nb_of_blink = 100000
task_maximum_size = 150 35
task_padding = 2 2 2
task_tooltip = 1
task_thumbnail = 0
task_thumbnail_size = 350
task_font_color = #ffffff 100
task_background_id = 1
task_active_background_id = 4
task_urgent_background_id = 0
task_iconified_background_id = 1
mouse_left = toggle_iconify
mouse_middle = close
mouse_right = maximize_restore
mouse_scroll_up = prev_task
mouse_scroll_down = next_task

#-------------------------------------
# System tray (notification area)
systray_padding = 0 0 2
systray_background_id = 2
systray_sort = right2left
systray_icon_size = 24
systray_icon_asb = 100 0 0
systray_monitor = 1
systray_name_filter = 

#-------------------------------------
# Launcher
launcher_padding = 0 0 2
launcher_background_id = 2
launcher_icon_background_id = 2
launcher_icon_size = 24
launcher_icon_asb = 100 0 0
launcher_icon_theme_override = 0
startup_notifications = 1
launcher_tooltip = 1
launcher_item_app = ~/.local/share/applications/open-openbox-menu.desktop
launcher_item_app = /usr/share/applications/firefox.desktop
launcher_item_app = /usr/share/applications/qterminal.desktop

#-------------------------------------
# Clock
time1_format = %H:%M
time2_format = %B%d日 %A
time1_timezone = 
time2_timezone = 
clock_font_color = #ffffff 100
clock_padding = 0 0
clock_background_id = 2
clock_tooltip = 
clock_tooltip_timezone = 
clock_lclick_command = 
clock_rclick_command = orage
clock_mclick_command = 
clock_uwheel_command = 
clock_dwheel_command = 

#-------------------------------------
# Battery
battery_tooltip = 1
battery_low_status = 10
battery_low_cmd = xmessage 'tint2: Battery low!'
battery_full_cmd = 
battery_font_color = #ffffff 100
bat1_format = 
bat2_format = 
battery_padding = 0 0
battery_background_id = 2
battery_hide = 100
battery_lclick_command = 
battery_rclick_command = 
battery_mclick_command = 
battery_uwheel_command = 
battery_dwheel_command = 
ac_connected_cmd = 
ac_disconnected_cmd = 

#-------------------------------------
# Tooltip
tooltip_show_timeout = 0.5
tooltip_hide_timeout = 0.1
tooltip_padding = 2 2
tooltip_background_id = 2
tooltip_font_color = #dddddd 100

EOF


cat >>./archlive/airootfs/etc/skel/.config/tint2/alchg.tint2rc<<"EOF"
#---- Generated by tint2conf a2ab ----
# See https://gitlab.com/o9000/tint2/wikis/Configure for 
# full documentation of the configuration options.
#-------------------------------------
# Gradients
#-------------------------------------
# Backgrounds
# Background 1: Default task, Iconified task, Inactive desktop name
rounded = 0
border_width = 1
border_sides = B
border_content_tint_weight = 0
background_content_tint_weight = 0
background_color = #2e2f37 70
border_color = #2e2f37 70
background_color_hover = #2e2f37 70
border_color_hover = #ffffff 100
background_color_pressed = #555555 4
border_color_pressed = #eaeaea 44

# Background 2: Active taskbar, Battery, Clock, Inactive taskbar, Launcher, Launcher icon, Systray, Tooltip
rounded = 0
border_width = 0
border_sides = 
border_content_tint_weight = 0
background_content_tint_weight = 0
background_color = #2e2f37 70
border_color = #2e2f37 70
background_color_hover = #2e2f37 70
border_color_hover = #ffffff 100
background_color_pressed = #2e2f37 70
border_color_pressed = #ffffff 100

# Background 3: Panel
rounded = 0
border_width = 0
border_sides = 
border_content_tint_weight = 0
background_content_tint_weight = 0
background_color = #2e2f37 70
border_color = #2e2f37 70
background_color_hover = #2e2f37 70
border_color_hover = #ffffff 100
background_color_pressed = #2e2f37 70
border_color_pressed = #ffffff 100

# Background 4: Active task
rounded = 0
border_width = 2
border_sides = B
border_content_tint_weight = 0
background_content_tint_weight = 0
background_color = #44454d 70
border_color = #ffffff 100
background_color_hover = #44454d 75
border_color_hover = #ffffff 100
background_color_pressed = #2e2f37 75
border_color_pressed = #ffffff 100

# Background 5: Active desktop name
rounded = 0
border_width = 0
border_sides = 
border_content_tint_weight = 0
background_content_tint_weight = 0
background_color = #44454d 70
border_color = #ffffff 100
background_color_hover = #44454d 75
border_color_hover = #ffffff 100
background_color_pressed = #2e2f37 75
border_color_pressed = #ffffff 100

#-------------------------------------
# Panel
panel_items = LTSCB
panel_size = 100% 4%
panel_margin = 0 0
panel_padding = 0 0 0
panel_background_id = 3
wm_menu = 1
panel_dock = 0
panel_pivot_struts = 0
panel_position = bottom center horizontal
panel_layer = top
panel_monitor = all
panel_shrink = 0
autohide = 0
autohide_show_timeout = 0
autohide_hide_timeout = 0.5
autohide_height = 2
strut_policy = follow_size
panel_window_name = tint2
disable_transparency = 1
mouse_effects = 1
font_shadow = 0
mouse_hover_icon_asb = 100 0 20
mouse_pressed_icon_asb = 100 0 0
scale_relative_to_dpi = 0
scale_relative_to_screen_height = 0

#-------------------------------------
# Taskbar
taskbar_mode = single_desktop
taskbar_hide_if_empty = 0
taskbar_padding = 0 0 0
taskbar_background_id = 2
taskbar_active_background_id = 2
taskbar_name = 1
taskbar_hide_inactive_tasks = 0
taskbar_hide_different_monitor = 0
taskbar_hide_different_desktop = 1
taskbar_always_show_all_desktop_tasks = 0
taskbar_name_padding = 5 0
taskbar_name_background_id = 1
taskbar_name_active_background_id = 5
taskbar_name_font_color = #44454d 100
taskbar_name_active_font_color = #ffffff 100
taskbar_distribute_size = 1
taskbar_sort_order = none
task_align = left

#-------------------------------------
# Task
task_text = 1
task_icon = 1
task_centered = 0
urgent_nb_of_blink = 100000
task_maximum_size = 150 35
task_padding = 2 2 2
task_tooltip = 1
task_thumbnail = 0
task_thumbnail_size = 350
task_font_color = #ffffff 100
task_background_id = 1
task_active_background_id = 4
task_urgent_background_id = 0
task_iconified_background_id = 1
mouse_left = toggle_iconify
mouse_middle = close
mouse_right = maximize_restore
mouse_scroll_up = prev_task
mouse_scroll_down = next_task

#-------------------------------------
# System tray (notification area)
systray_padding = 0 0 2
systray_background_id = 2
systray_sort = right2left
systray_icon_size = 24
systray_icon_asb = 100 0 0
systray_monitor = 1
systray_name_filter = 

#-------------------------------------
# Launcher
launcher_padding = 0 0 2
launcher_background_id = 2
launcher_icon_background_id = 2
launcher_icon_size = 24
launcher_icon_asb = 100 0 0
launcher_icon_theme_override = 0
startup_notifications = 1
launcher_tooltip = 1
launcher_item_app = ~/.local/share/applications/open-openbox-menu.desktop
launcher_item_app = /usr/share/applications/firefox.desktop
launcher_item_app = /usr/share/applications/qterminal.desktop

#-------------------------------------
# Clock
time1_format = %H:%M
time2_format = %B%d日 %A
time1_timezone = 
time2_timezone = 
clock_font_color = #ffffff 100
clock_padding = 0 0
clock_background_id = 2
clock_tooltip = 
clock_tooltip_timezone = 
clock_lclick_command = 
clock_rclick_command = orage
clock_mclick_command = 
clock_uwheel_command = 
clock_dwheel_command = 

#-------------------------------------
# Battery
battery_tooltip = 1
battery_low_status = 10
battery_low_cmd = xmessage 'tint2: Battery low!'
battery_full_cmd = 
battery_font_color = #ffffff 100
bat1_format = 
bat2_format = 
battery_padding = 0 0
battery_background_id = 2
battery_hide = 100
battery_lclick_command = 
battery_rclick_command = 
battery_mclick_command = 
battery_uwheel_command = 
battery_dwheel_command = 
ac_connected_cmd = 
ac_disconnected_cmd = 

#-------------------------------------
# Tooltip
tooltip_show_timeout = 0.5
tooltip_hide_timeout = 0.1
tooltip_padding = 2 2
tooltip_background_id = 2
tooltip_font_color = #dddddd 100

EOF




mkdir ./archlive/airootfs/etc/skel/.config/conky
cat >>./archlive/airootfs/etc/skel/.config/conky/conky.conf<<"EOF"

--[[
Conky, a system monitor, based on torsmo

Any original torsmo code is licensed under the BSD license

All code written since the fork of torsmo is licensed under the GPL

Please see COPYING for details

Copyright (c) 2004, Hannu Saransaari and Lauri Hakkarainen
Copyright (c) 2005-2019 Brenden Matthews, Philip Kovacs, et. al. (see AUTHORS)
All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

conky.config = {
    alignment = 'bottom_right',
    background = false,
    border_width = 1,
    cpu_avg_samples = 2,
    default_color = 'white',
    default_outline_color = 'white',
    default_shade_color = 'white',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,
    extra_newline = false,
    font = 'DejaVu Sans Mono:size=12',
    gap_x = 25,
    gap_y = 40,
    minimum_height = 5,
    minimum_width = 220,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_ncurses = false,
    out_to_stderr = false,
    out_to_x = true,
    own_window = true,
    own_window_class = 'Conky',
    own_window_type = 'desktop',
    own_window_transparent = true,
    own_window_argb_visual = true, 
    own_window_argb_value = 150,
    show_graph_range = false,
    show_graph_scale = false,
    stippled_borders = 0,
    update_interval = 1.0,
    uppercase = false,
    use_spacer = 'none',
    use_xft = true,
}

conky.text = [[
${color grey}CPU:$color${cpubar 4}
${if_match ${memperc}==100}${color red}RAM:${membar 4}${else}${if_match ${memperc}<70}${color grey}RAM:${color white}${membar 4}${else}${color #FF7000}RAM:${membar 4}${endif}${endif}
${if_match ${fs_used_perc}==100}${color red}FS :${fs_bar 4}${else}${if_match ${fs_used_perc}<90}${color grey}FS :${color white}${fs_bar 4}${else}${color #FF7000}FS :${fs_bar 4}${endif}${endif}
]]

EOF





mkdir=./archlive/out
cd ./archlive
mkarchiso -v ./


cd ./out
ORGNAME=`ls ./`
FILENAME=`echo ${ORGNAME#arch}`
mv "$ORGNAME" "alchg$FILENAME"
sha256sum "alchg$FILENAME" >sha256sum.txt
cd ../


cd ../

find ./archlive/out/

