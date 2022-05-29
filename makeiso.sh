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

fi

rm -r ./archlive
mkdir ./archlive
cp -r /usr/share/archiso/configs/releng/* ./archlive/

set -e



until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/PreLoader.efi" "https://blog.hansenpartnership.com/wp-uploads/2013/PreLoader.efi";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/HashTool.efi" "https://blog.hansenpartnership.com/wp-uploads/2013/HashTool.efi";do date;echo RETRY;done

cat >/tmp/hash<<"EOF"
45639d23aa5f2a394b03a65fc732acf2  ./archlive/HashTool.efi
4f7a4f566781869d252a09dc84923a82  ./archlive/PreLoader.efi
EOF

md5sum -c /tmp/hash

cp /usr/bin/mkarchiso /usr/bin/mkarchiso_mod

sed -i "/efiboot_imgsize=\"\$(du/a \"./PreLoader.efi\" \\\\" /usr/bin/mkarchiso_mod
sed -i "/efiboot_imgsize=\"\$(du/a \"./HashTool.efi\" \\\\" /usr/bin/mkarchiso_mod
sed -i "s/::\/EFI\/BOOT\/BOOTx64.EFI/::\/EFI\/BOOT\/loader.efi/" /usr/bin/mkarchiso_mod
sed -i "/::\/EFI\/BOOT\/loader.efi/a mcopy -n -i \"\${work_dir}\/efiboot.img\" .\/PreLoader.efi ::\/EFI\/BOOT\/BOOTx64.efi" /usr/bin/mkarchiso_mod
sed -i "/::\/EFI\/BOOT\/loader.efi/a mcopy -n -i \"\${work_dir}\/efiboot.img\" .\/HashTool.efi ::\/EFI\/BOOT\/HashTool.efi" /usr/bin/mkarchiso_mod


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
fcitx-im
fcitx-configtool
fcitx-mozc
lxrandr
conky
nitrogen
i3lock
vi
qterminal
vivaldi
vivaldi-ffmpeg-codecs
netsurf
vinagre
virt-viewer
EOF

#gnome-packagekit
#xfce4-notifyd


cat >./archlive/airootfs/etc/mkinitcpio.d/linux-lts.preset<<"EOF"
PRESETS=('archiso')

ALL_kver='/boot/vmlinuz-linux-lts'
ALL_config='/etc/mkinitcpio.conf'

archiso_image="/boot/initramfs-linux-lts.img"
EOF
cat >./archlive/airootfs/etc/mkinitcpio.d/linux.preset<<"EOF"
EOF

sed -i "s/TIMEOUT 150/TIMEOUT 50/" ./archlive/syslinux/archiso_sys.cfg
sed -i "s/timeout 15/timeout 5/" ./archlive/efiboot/loader/loader.conf

sed -i s/vmlinuz-linux/vmlinuz-linux-lts/ ./archlive/syslinux/archiso_sys-linux.cfg
sed -i s/vmlinuz-linux/vmlinuz-linux-lts/ ./archlive/efiboot/loader/entries/01-archiso-x86_64-linux.conf
sed -i s/vmlinuz-linux/vmlinuz-linux-lts/ ./archlive/efiboot/loader/entries/02-archiso-x86_64-speech-linux.conf
sed -i s/vmlinuz-linux/vmlinuz-linux-lts/ ./archlive/efiboot/loader/entries/03-archiso-x86_64-ram-linux.conf

sed -i s/initramfs-linux/initramfs-linux-lts/ ./archlive/syslinux/archiso_sys-linux.cfg
sed -i s/initramfs-linux/initramfs-linux-lts/ ./archlive/efiboot/loader/entries/01-archiso-x86_64-linux.conf
sed -i s/initramfs-linux/initramfs-linux-lts/ ./archlive/efiboot/loader/entries/02-archiso-x86_64-speech-linux.conf
sed -i s/initramfs-linux/initramfs-linux-lts/ ./archlive/efiboot/loader/entries/03-archiso-x86_64-ram-linux.conf

sed -i s/"xz"/"zstd"/ ./archlive/airootfs/etc/mkinitcpio.conf
sed -i s/"#COMPRESSION_OPTIONS=()"/"COMPRESSION_OPTIONS=('-19')"/ ./archlive/airootfs/etc/mkinitcpio.conf

cat >>./archlive/airootfs/etc/locale.gen<<"EOF"
en_US.UTF-8 UTF-8
ja_JP.UTF-8 UTF-8
EOF

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


passwd root<<"PWD"
root
root
PWD

EOF

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
sed -i '/^)/i\ \ ["/etc/skel/alchg/exec.sh"]="0:0:755"' ./archlive/profiledef.sh
sed -i '/^)/i\ \ ["/etc/skel/alchg/menu.sh"]="0:0:755"' ./archlive/profiledef.sh
sed -i '/^)/i\ \ ["/etc/skel/alchg/pipe_menu.sh"]="0:0:755"' ./archlive/profiledef.sh

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
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
setxkbmap jp &
fcitx &
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


cat >./archlive/airootfs/etc/skel/alchg/pipe_menu.sh<<"EOF"
#! /bin/bash

echo "<openbox_pipe_menu>"
echo "<separator label='/usr/share/applications/'/>"

for FILE in $(ls /usr/share/applications/*.desktop );do
	NAME=`grep -m 1 Name= $FILE | awk -F "=" '{printf $2 "\n"}'`
	echo "<item label='$NAME'>"
	echo "<action name='Execute'>"
	echo "<execute>gtk-launch `echo $FILE | awk -F "/" 'END{print $NF}'`</execute>"
	echo "</action>"
	echo "</item>"
done

echo "</openbox_pipe_menu>"
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
                                                                                                                                                                         
if grep "own_window_transparent = true" $FILE2 ;then                                                                                                                     
        sed -i "s/own_window_transparent = true/own_window_transparent = false/" $FILE2                                                                                  
else                                                                                                                                                                     
        sed -i "s/own_window_transparent = false/own_window_transparent = true/" $FILE2                                                                                  
fi                                                                                                                                                                       

EOF

mkdir -p ./archlive/airootfs/usr/share/icons/hicolor/64x64/apps/
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/usr/share/icons/hicolor/64x64/apps/utilities-terminal.png" "https://icon-icons.com/downloadimage.php?id=34340&root=317/PNG/64/&file=terminal-icon_34340.png";do date;echo RETRY;done

mkdir ./archlive/airootfs/etc/skel/icon/
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/icon/menu.png" "http://flat-icon-design.com/f/f_event_52/s128_f_event_52_1nbg.png";do date;echo RETRY;done

mkdir ./archlive/airootfs/etc/skel/wallpaper/
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper01.jpg" "https://images.pexels.com/photos/689784/pexels-photo-689784.jpeg?cs=srgb&dl=pexels-dsd-689784.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper02.jpg" "https://images.pexels.com/photos/36717/amazing-animal-beautiful-beautifull.jpg?cs=srgb&dl=pexels-pixabay-36717.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper03.jpg" "https://images.pexels.com/photos/326055/pexels-photo-326055.jpeg?cs=srgb&dl=pexels-pixabay-326055.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper04.jpg" "https://images.pexels.com/photos/268533/pexels-photo-268533.jpeg?cs=srgb&dl=pexels-pixabay-268533.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper05.jpg" "https://images.pexels.com/photos/531321/pexels-photo-531321.jpeg?cs=srgb&dl=pexels-pixabay-531321.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper06.jpg" "https://images.pexels.com/photos/219998/pexels-photo-219998.jpeg?cs=srgb&dl=pexels-pixabay-219998.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper07.jpg" "https://images.pexels.com/photos/748626/pexels-photo-748626.jpeg?cs=srgb&dl=pexels-george-desipris-748626.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper08.jpg" "https://images.pexels.com/photos/1089438/pexels-photo-1089438.jpeg?cs=srgb&dl=pexels-markus-spiske-1089438.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper09.jpg" "https://images.pexels.com/photos/33688/delicate-arch-night-stars-landscape.jpg?cs=srgb&dl=pexels-pixabay-33688.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper10.jpg" "https://images.pexels.com/photos/316093/pexels-photo-316093.jpeg?cs=srgb&dl=pexels-pixabay-316093.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper11.jpg" "https://images.pexels.com/photos/220118/pexels-photo-220118.jpeg?cs=srgb&dl=pexels-pixabay-220118.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper12.jpg" "https://images.pexels.com/photos/7526797/pexels-photo-7526797.jpeg?cs=srgb&dl=pexels-satoshi-hirayama-7526797.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper13.jpg" "https://images.pexels.com/photos/355904/pexels-photo-355904.jpeg?cs=srgb&dl=pexels-pixabay-355904.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper14.jpg" "https://images.pexels.com/photos/91216/pexels-photo-91216.jpeg?cs=srgb&dl=pexels-stefan-stefancik-91216.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper15.jpg" "https://images.pexels.com/photos/1480690/pexels-photo-1480690.jpeg?cs=srgb&dl=pexels-sebastiaan-stam-1480690.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper16.jpg" "https://images.pexels.com/photos/1036841/pexels-photo-1036841.jpeg?cs=srgb&dl=pexels-dominika-roseclay-1036841.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper17.jpg" "https://images.pexels.com/photos/5011647/pexels-photo-5011647.jpeg?cs=srgb&dl=pexels-rostislav-uzunov-5011647.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper18.jpg" "https://images.pexels.com/photos/593158/pexels-photo-593158.jpeg?cs=srgb&dl=pexels-scott-webb-593158.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper19.jpg" "https://images.pexels.com/photos/3195642/pexels-photo-3195642.jpeg?cs=srgb&dl=pexels-vlad-che%C8%9Ban-3195642.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper20.jpg" "https://images.pexels.com/photos/1841841/pexels-photo-1841841.jpeg?cs=srgb&dl=pexels-sy-donny-1841841.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper21.jpg" "https://images.pexels.com/photos/5827789/pexels-photo-5827789.jpeg?cs=srgb&dl=pexels-polina-kovaleva-5827789.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper22.jpg" "https://images.pexels.com/photos/2922672/pexels-photo-2922672.jpeg?cs=srgb&dl=pexels-jeremy-bishop-2922672.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper23.jpg" "https://images.pexels.com/photos/7868374/pexels-photo-7868374.jpeg?cs=srgb&dl=pexels-sergiu-iacob-7868374.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper24.jpg" "https://images.pexels.com/photos/8621399/pexels-photo-8621399.jpeg?cs=srgb&dl=pexels-piya-nimityongskul-8621399.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper25.jpg" "https://images.pexels.com/photos/1612351/pexels-photo-1612351.jpeg?cs=srgb&dl=pexels-eberhard-grossgasteiger-1612351.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper26.jpg" "https://images.pexels.com/photos/1059161/pexels-photo-1059161.jpeg?cs=srgb&dl=pexels-willy-arisky-1059161.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper27.jpg" "https://images.pexels.com/photos/751374/pexels-photo-751374.jpeg?cs=srgb&dl=pexels-namakuki-751374.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper28.jpg" "https://images.pexels.com/photos/2363/france-landmark-lights-night.jpg?cs=srgb&dl=pexels-pixabay-2363.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper29.jpg" "https://images.pexels.com/photos/220769/pexels-photo-220769.jpeg?cs=srgb&dl=pexels-pixabay-220769.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper30.jpg" "https://images.pexels.com/photos/301469/pexels-photo-301469.jpeg?cs=srgb&dl=pexels-pixabay-301469.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper31.jpg" "https://images.pexels.com/photos/356831/pexels-photo-356831.jpeg?cs=srgb&dl=pexels-pixabay-356831.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper32.jpg" "https://images.pexels.com/photos/3408744/pexels-photo-3408744.jpeg?cs=srgb&dl=pexels-stein-egil-liland-3408744.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper33.jpg" "https://images.pexels.com/photos/15286/pexels-photo.jpg?cs=srgb&dl=pexels-luis-del-r%C3%ADo-15286.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper34.jpg" "https://images.pexels.com/photos/2156881/pexels-photo-2156881.jpeg?cs=srgb&dl=pexels-anni-roenkae-2156881.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper35.jpg" "https://images.pexels.com/photos/9291/nature-bird-flying-red.jpg?cs=srgb&dl=pexels-skitterphoto-9291.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper36.jpg" "https://images.pexels.com/photos/247399/pexels-photo-247399.jpeg?cs=srgb&dl=pexels-pixabay-247399.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper37.jpg" "https://images.pexels.com/photos/53581/bald-eagles-bald-eagle-bird-of-prey-adler-53581.jpeg?cs=srgb&dl=pexels-pixabay-53581.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper38.jpg" "https://images.pexels.com/photos/104827/cat-pet-animal-domestic-104827.jpeg?cs=srgb&dl=pexels-pixabay-104827.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper39.jpg" "https://images.pexels.com/photos/3880091/pexels-photo-3880091.jpeg?cs=srgb&dl=pexels-patrice-schoefolt-3880091.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper40.jpg" "https://images.pexels.com/photos/162256/wolf-predator-european-wolf-carnivores-162256.jpeg?cs=srgb&dl=pexels-pixabay-162256.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper41.jpg" "https://images.pexels.com/photos/4598072/pexels-photo-4598072.jpeg?cs=srgb&dl=pexels-skyler-ewing-4598072.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper42.jpg" "https://images.pexels.com/photos/4147992/pexels-photo-4147992.jpeg?cs=srgb&dl=pexels-vladimir-blyufer-4147992.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper43.jpg" "https://images.pexels.com/photos/5802998/pexels-photo-5802998.jpeg?cs=srgb&dl=pexels-eugenio-barboza-5802998.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper44.jpg" "https://images.pexels.com/photos/34231/antler-antler-carrier-fallow-deer-hirsch.jpg?cs=srgb&dl=pexels-pixabay-34231.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper45.jpg" "https://images.pexels.com/photos/2156311/pexels-photo-2156311.jpeg?cs=srgb&dl=pexels-lone-jensen-2156311.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper46.jpg" "https://images.pexels.com/photos/3536511/pexels-photo-3536511.jpeg?cs=srgb&dl=pexels-harrison-haines-3536511.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper47.jpg" "https://images.pexels.com/photos/213399/pexels-photo-213399.jpeg?cs=srgb&dl=pexels-fox-213399.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper48.jpg" "https://images.pexels.com/photos/1335971/pexels-photo-1335971.jpeg?cs=srgb&dl=pexels-chevanon-photography-1335971.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper49.jpg" "https://images.pexels.com/photos/2156316/pexels-photo-2156316.jpeg?cs=srgb&dl=pexels-lone-jensen-2156316.jpg&fm=jpg";do date;echo RETRY;done
until curl -L -Y 10240 -C - --limit-rate 10240K -k -o "./archlive/airootfs/etc/skel/wallpaper/wallpaper50.jpg" "https://images.pexels.com/photos/3699434/pexels-photo-3699434.jpeg?cs=srgb&dl=pexels-hung-tran-3699434.jpg&fm=jpg";do date;echo RETRY;done


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
fontFamily=Monospace
fontSize=12
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
(sleep 1s && conky) &
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
  <item label="Vivaldi">
    <action name="Execute">
     <command>vivaldi-stable</command>
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
  <menu id="desktop-entry-menu" label="全てのアプリケーション（デスクトップエントリ）" execute="/home/user/alchg/pipe_menu.sh"/>
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
     <command>lxrandr</command>
    </action>
  </item>
  <item label="日本語入力">
    <action name="Execute">
     <command>fcitx-configtool</command>
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
  <item label="Vivaldi">
    <action name="Execute">
     <command>vivaldi-stable</command>
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
  <item label="Vivaldi">
    <action name="Execute">
     <command>vivaldi-stable</command>
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
  <menu id="desktop-entry-menu" label="All applications (Desktop entries)" execute="/home/user/alchg/pipe_menu.sh"/>
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
     <command>lxrandr</command>
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
  <item label="Vivaldi">
    <action name="Execute">
     <command>vivaldi-stable</command>
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
systray_sort = left2right
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
launcher_item_app = /usr/share/applications/vivaldi-stable.desktop
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
systray_sort = left2right
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
launcher_item_app = /usr/share/applications/vivaldi-stable.desktop
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


mkdir -p ./archlive/airootfs/etc/skel/.config/vivaldi/Default
cat >>./archlive/airootfs/etc/skel/.config/vivaldi/Default/Preferences<<"EOF"
{"account_id_migration_state":2,"account_tracker_service_last_update":"13283808983322662","alternate_error_pages":{"backup":true},"announcement_notification_service_first_run_time":"13283808983032507","autocomplete":{"retention_policy_last_version":96},"autofill":{"orphan_rows_removed":true},"browser":{"has_seen_welcome_page":true,"window_placement":{"bottom":728,"left":10,"maximized":true,"right":1014,"top":10,"work_area_bottom":738,"work_area_left":0,"work_area_right":1024,"work_area_top":0},"window_placement_popup":{"bottom":738,"left":64,"maximized":false,"right":1024,"top":0,"work_area_bottom":738,"work_area_left":0,"work_area_right":1024,"work_area_top":0}},"countryid_at_install":19024,"data_reduction":{"daily_original_length":["0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","16651653"],"daily_received_length":["0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","16651653"],"last_update_date":"13283794800000000","this_week_number":2710,"this_week_services_downstream_foreground_kb":{"112189210":1,"117649486":441,"135466893":978,"1408190":792,"49601082":1,"54845618":6372,"72672995":0,"80134684":19,"82509217":7657,"98942797":1}},"default_apps_install_state":3,"domain_diversity":{"last_reporting_timestamp":"13283808983323012"},"download":{"directory_upgrade":true},"extensions":{"alerts":{"initialized":true},"chrome_url_overrides":{},"last_chrome_version":"96.0.4664.97","settings":{"ahfgeienlihckogmohjhadlkjgocpleb":{"active_permissions":{"api":["management","system.display","system.storage","webstorePrivate","system.cpu","system.memory","system.network"],"manifest_permissions":[]},"app_launcher_ordinal":"t","commands":{},"content_settings":[],"creation_flags":1,"events":[],"from_bookmark":false,"from_webstore":false,"incognito_content_settings":[],"incognito_preferences":{},"install_time":"13283808983165959","location":5,"manifest":{"app":{"launch":{"web_url":"https://chrome.google.com/webstore"},"urls":["https://chrome.google.com/webstore"]},"description":"Vivaldi のすばらしいアプリ、ゲーム、拡張機能、テーマをぜひご利用ください。","icons":{"128":"webstore_icon_128.png","16":"webstore_icon_16.png"},"key":"MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCtl3tO0osjuzRsf6xtD2SKxPlTfuoy7AWoObysitBPvH5fE1NaAA1/2JkPWkVDhdLBWLaIBPYeXbzlHp3y4Vv/4XG+aN5qFE3z+1RU/NqkzVYHtIpVScf3DjTYtKVL66mzVGijSoAIwbFCC3LpGdaoe6Q1rSRDp76wR6jjFzsYwQIDAQAB","name":"ウェブストア","permissions":["webstorePrivate","management","system.cpu","system.display","system.memory","system.network","system.storage"],"version":"0.2"},"needs_sync":true,"page_ordinal":"n","path":"/opt/vivaldi/resources/web_store","preferences":{},"regular_only_preferences":{},"state":1,"was_installed_by_default":false,"was_installed_by_oem":false},"jffbochibkahlbbmanpmndnhmeliecah":{"active_permissions":{"api":["pipPrivate"],"manifest_permissions":[],"scriptable_host":["file:///*","http://*/*","https://*/*"]},"commands":{},"content_settings":[],"creation_flags":1,"events":[],"from_bookmark":false,"from_webstore":false,"incognito_content_settings":[],"incognito_preferences":{},"install_time":"13283808983151022","location":5,"manifest":{"background":{"persistent":false,"scripts":["background.js"]},"content_scripts":[{"all_frames":true,"js":["picture-in-picture.js"],"matches":["http://*/*","https://*/*","file://*/*"],"run_at":"document_idle"}],"incognito":"split","key":"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAopqQwcxxNnqd3iNJ8np6Je7vuMqp/B1alJ+OfrzFgasMfv8v7GXmSjl/z+rFmAlHt5bmLfFrCAmginGwHPOm7R7nSIocseGU7TdWXt9QRF9blsrozSNTdUTGTgdw4z2g6ghvDBcJQIkcf8CdsEvLjJCvG7gQ3XXSuujJBzGm2jVHW+eXmAtMOoWlqTn293DJOHz2ZbpGXGKBYt6+qP7312XEKlXb152GG6oVX9qxkZA4Q364gfILJ3om4j3111WhJzCQ4MR6K3F/4Lx5ZhLSa48N1QYG/odh4XuqiEa0ZMQFCwnODhJW9thwcxLHjZMBRgr5nQScn/U+N3C/XeJW2QIDAQAB","manifest_version":2,"name":"Vivaldi Picture-In-Picture","permissions":["pipPrivate"],"version":"1.0","web_accessible_resources":["config.json","picture-in-picture.css"]},"path":"/opt/vivaldi/resources/vivaldi/components/picture-in-picture","preferences":{},"regular_only_preferences":{},"state":1,"was_installed_by_default":false,"was_installed_by_oem":false},"kmendfapggjehodndflmmgagdbamhnfd":{"active_permissions":{"api":["cryptotokenPrivate","externally_connectable.all_urls","tabs"],"explicit_host":["http://*/*","https://*/*"],"manifest_permissions":[]},"commands":{},"content_settings":[],"creation_flags":1,"events":["runtime.onConnectExternal"],"from_bookmark":false,"from_webstore":false,"incognito_content_settings":[],"incognito_preferences":{},"install_time":"13283808983176119","location":5,"manifest":{"background":{"persistent":false,"scripts":["util.js","b64.js","cbor.js","sha256.js","timer.js","countdown.js","countdowntimer.js","devicestatuscodes.js","approvedorigins.js","errorcodes.js","webrequest.js","messagetypes.js","factoryregistry.js","requesthelper.js","asn1.js","enroller.js","requestqueue.js","signer.js","origincheck.js","textfetcher.js","appid.js","watchdog.js","logging.js","webrequestsender.js","window-timer.js","cryptotokenorigincheck.js","cryptotokenapprovedorigins.js","inherits.js","individualattest.js","googlecorpindividualattest.js","cryptotokenbackground.js"]},"description":"CryptoToken Component Extension","externally_connectable":{"ids":["fjajfjhkeibgmiggdfehjplbhmfkialk"],"matches":["https://*/*"]},"incognito":"split","key":"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAq7zRobvA+AVlvNqkHSSVhh1sEWsHSqz4oR/XptkDe/Cz3+gW9ZGumZ20NCHjaac8j1iiesdigp8B1LJsd/2WWv2Dbnto4f8GrQ5MVphKyQ9WJHwejEHN2K4vzrTcwaXqv5BSTXwxlxS/mXCmXskTfryKTLuYrcHEWK8fCHb+0gvr8b/kvsi75A1aMmb6nUnFJvETmCkOCPNX5CHTdy634Ts/x0fLhRuPlahk63rdf7agxQv5viVjQFk+tbgv6aa9kdSd11Js/RZ9yZjrFgHOBWgP4jTBqud4+HUglrzu8qynFipyNRLCZsaxhm+NItTyNgesxLdxZcwOz56KD1Q4IQIDAQAB","manifest_version":2,"name":"CryptoTokenExtension","permissions":["cryptotokenPrivate","externally_connectable.all_urls","tabs","https://*/*","http://*/*"],"version":"0.9.74"},"path":"/opt/vivaldi/resources/cryptotoken","preferences":{},"regular_only_preferences":{},"state":1,"was_installed_by_default":false,"was_installed_by_oem":false},"lglfeioladcfajpjdnghbfgohdihdnfl":{"active_permissions":{"api":["themePrivate"],"manifest_permissions":[],"scriptable_host":["https://themes-staging.vivaldi.net/","https://themes.vivaldi.net/*","https://vivnet-st-themes.viv.dc01/*"]},"commands":{},"content_settings":[],"creation_flags":1,"events":[],"from_bookmark":false,"from_webstore":false,"incognito_content_settings":[],"incognito_preferences":{},"install_time":"13283808983151941","location":5,"manifest":{"content_scripts":[{"all_frames":true,"js":["theme-store.js"],"matches":["https://vivnet-st-themes.viv.dc01/*","https://themes-staging.vivaldi.net/","https://themes.vivaldi.net/*"],"run_at":"document_end"}],"incognito":"split","key":"AAAAB3NzaC1yc2EAAAADAQABAAABAQCTRcu4gLK34YltRyhW7wYAYga9005PNG6Gp86PtK/OHSgye3JreU5cBoTZCmf9+zwhxVhCOB7GyDcSjqvy7o438Qa3gCgWVieSSZHogGf+fHsNcmw0uP688+O8kDy7VtZsDdPatkpCLOzTTF2dHnrewJeEz295+IplqSIitIBRQLZkEJuib71BonUw9vwANdNHV0Ky3tlSng0muKwyT+jdj+h0ODQW0GJGsKj4GIzuEwwPGVrkWq6qKwc0FynS3B/xRrvXl7RMAZtNexzbGSSo7VUvV3+P/LfNJsu1HtwED6DByqnGgoQRTyW/bRqgTgPUIuWoRpTz04UZj6aHvCTP","manifest_version":2,"name":"Vivaldi Theme Store","permissions":["themePrivate"],"version":"1.0"},"path":"/opt/vivaldi/resources/vivaldi/components/theme-store","preferences":{},"regular_only_preferences":{},"state":1,"was_installed_by_default":false,"was_installed_by_oem":false},"mhjfbmdgcfjbbpaeojofohoefgiehjai":{"active_permissions":{"api":["contentSettings","fileSystem","fileSystem.write","metricsPrivate","tabs","resourcesPrivate"],"explicit_host":["chrome://resources/*"],"manifest_permissions":[]},"commands":{},"content_settings":[],"creation_flags":1,"events":[],"from_bookmark":false,"from_webstore":false,"incognito_content_settings":[],"incognito_preferences":{},"install_time":"13283808983174903","location":5,"manifest":{"content_security_policy":"script-src 'self' 'wasm-eval' blob: filesystem: chrome://resources; object-src * blob: externalfile: file: filesystem: data:","description":"","incognito":"split","key":"MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDN6hM0rsDYGbzQPQfOygqlRtQgKUXMfnSjhIBL7LnReAVBEd7ZmKtyN2qmSasMl4HZpMhVe2rPWVVwBDl6iyNE/Kok6E6v6V3vCLGsOpQAuuNVye/3QxzIldzG/jQAdWZiyXReRVapOhZtLjGfywCvlWq7Sl/e3sbc0vWybSDI2QIDAQAB","manifest_version":2,"mime_types":["application/pdf"],"mime_types_handler":"index.html","name":"Chromium PDF Viewer","offline_enabled":true,"permissions":["chrome://resources/","contentSettings","metricsPrivate","resourcesPrivate","tabs",{"fileSystem":["write"]}],"version":"1"},"path":"/opt/vivaldi/resources/pdf","preferences":{},"regular_only_preferences":{},"state":1,"was_installed_by_default":false,"was_installed_by_oem":false},"mpognobbkildjkofajifpdfhcoklimli":{"active_permissions":{"api":["accessibilityFeatures.modify","accessibilityFeatures.read","alarms","app.window.alwaysOnTop","audioCapture","bookmarks","bookmarkManagerPrivate","browsingData","clipboardRead","commandLinePrivate","contentSettings","contextMenus","cookies","declarativeWebRequest","downloads","downloadsInternal","downloads.open","downloads.shelf","fileSystem","fileSystem.directory","fileSystem.write","fontSettings","geolocation","history","identity","management","notifications","app.window.fullscreen.overrideEsc","privacy","sessions",{"socket":["tcp-connect:*:*"]},"storage","tabs","topSites","unlimitedStorage","videoCapture","webNavigation","webRequest","webview","languageSettingsPrivate","accessKeys","autoUpdate","bookmarkContextMenu","bookmarksPrivate","calendar","contacts","contentBlocking","contextMenu","devtoolsPrivate","extensionActionUtils","historyPrivate","importData","infobars","editcommand","mailPrivate","menuContent","menubar","menubarMenu","notes","pageActions","pipPrivate","prefs","runtimePrivate","savedpasswords","sessionsPrivate","settings","sync","tabsPrivate","themePrivate","translateHistory","thumbnails","utilities","vivaldiAccount","windowPrivate","zoom"],"explicit_host":["\u003Call_urls>","chrome://favicon/*","chrome://game/*","chrome://theme/*","chrome://thumb/*","chrome://vivaldi-data/*","chrome://vivaldi-webui/*"],"manifest_permissions":[]},"app_launcher_ordinal":"n","commands":{},"content_settings":[],"creation_flags":1,"events":["prefs.onChanged","storage.onChanged"],"filtered_events":{"windows.onCreated":[{}],"windows.onRemoved":[{}]},"from_bookmark":false,"from_webstore":false,"has_declarative_rules":{"declarativeContent":{"onPageChanged":false},"declarativeWebRequest":{"onRequest":false}},"incognito_content_settings":[],"incognito_preferences":{},"install_time":"13283808983150716","location":5,"manifest":{"app":{"background":{"scripts":["background-common-bundle.js","background-bundle.js"]}},"content_security_policy":{"extension_pages":"script-src 'self' http://localhost:35729/; object-src 'self'"},"default_locale":"en","display_in_launcher":true,"display_in_new_tab_page":true,"host_permissions":["\u003Call_urls>","chrome://favicon/","chrome://game/","chrome://theme/","chrome://vivaldi-data/","chrome://vivaldi-webui/"],"icons":{"128":"resources/icon_128.png","16":"resources/icon_16.png"},"key":"MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDZkVvA5GwPYgY0TLcWEuM3yp/SnK7aZul39rvMTTAXd8YUgd1CpoFSoparbHO9qcrp2o4dzKDuIlJchAZhd8Rc2BgC9YVceW8s0VkhbPxuECKPWjb+VzxV1u9f6OhD6oNtrkaKBEJRFQVHe29P+vaOwiFLuR9pkCo62vYnMK8fGwIDAQAB","manifest_version":3,"minimum_chrome_version":"32.0.1700.0","name":"Vivaldi","offline_enabled":true,"permissions":["accessibilityFeatures.read","accessibilityFeatures.modify","accessKeys","alarms","alwaysOnTopWindows","app.window.fullscreen.overrideEsc","audioCapture","autoUpdate","bookmarkContextMenu","bookmarkManagerPrivate","bookmarks","bookmarksPrivate","browsingData","calendar","contacts","contentBlocking","clipboardRead","commandLinePrivate","contentSettings","contextMenu","contextMenus","cookies","declarativeWebRequest","devtoolsPrivate","downloads","downloads.open","downloads.shelf","editcommand","extensionActionUtils","fileSystem","fontSettings","geolocation","history","historyPrivate","identity","importData","infobars","languageSettingsPrivate","management","mailPrivate","menuContent","menubar","menubarMenu","notes","notifications","pageActions","passwordsPrivate","pipPrivate","prefs","privacy","runtimePrivate","savedpasswords","scripting","sessions","sessionsPrivate","settings","storage","sync","tabs","tabsPrivate","themePrivate","thumbnails","translateHistory","topSites","unlimitedStorage","utilities","videoCapture","vivaldiAccount","webRequest","webview","webNavigation","windowPrivate","zoom",{"fileSystem":["write","directory"]},{"socket":["tcp-connect:*:*"]}],"version":"1.5","web_accessible_resources":[{"extension_ids":[],"matches":[],"resources":["rss/showfeed.html","rss/showopml.html","rss/hidepage.css"]}],"webview":{"partitions":[{"accessible_resources":["browser.html","saga/saga.html","components/thumbnail/capture.html","components/chat/chat.html","components/mail/mail.html","components/welcome/welcome.html","components/experiments/experiments.html","components/actionlog/actionlog.html","style/*","resources/*","defaultsPlatformSpecific.js","defaults.js","bundle.js","devtools.html"],"name":"storage"},{"accessible_resources":["components/notes/markdowneditor/markdowneditor.html","markdowneditor-bundle.js"],"name":"markdowneditor"},{"accessible_resources":["components/notes/richtexteditor/richtexteditor.html","richtexteditor-bundle.js","md.css"],"name":"richtexteditor"}]}},"page_ordinal":"n","path":"/opt/vivaldi/resources/vivaldi","preferences":{},"regular_only_preferences":{},"running":true,"state":1,"was_installed_by_default":false,"was_installed_by_oem":false},"nkeimhogjdpnpccoofpliimaahmaaome":{"active_permissions":{"api":["desktopCapture","processes","webrtcAudioPrivate","webrtcDesktopCapturePrivate","webrtcLoggingPrivate","system.cpu","enterprise.hardwarePlatform"],"manifest_permissions":[]},"commands":{},"content_settings":[],"creation_flags":1,"events":["runtime.onConnectExternal"],"from_bookmark":false,"from_webstore":false,"incognito_content_settings":[],"incognito_preferences":{},"install_time":"13283808983175542","location":5,"manifest":{"background":{"page":"background.html","persistent":false},"externally_connectable":{"matches":["https://*.google.com/*"]},"incognito":"split","key":"MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDAQt2ZDdPfoSe/JI6ID5bgLHRCnCu9T36aYczmhw/tnv6QZB2I6WnOCMZXJZlRdqWc7w9jo4BWhYS50Vb4weMfh/I0On7VcRwJUgfAxW2cHB+EkmtI1v4v/OU24OqIa1Nmv9uRVeX0GjhQukdLNhAE6ACWooaf5kqKlCeK+1GOkQIDAQAB","manifest_version":2,"name":"Google Hangouts","permissions":["desktopCapture","enterprise.hardwarePlatform","processes","system.cpu","webrtcAudioPrivate","webrtcDesktopCapturePrivate","webrtcLoggingPrivate"],"version":"1.3.16"},"path":"/opt/vivaldi/resources/hangout_services","preferences":{},"regular_only_preferences":{},"state":1,"was_installed_by_default":false,"was_installed_by_oem":false}}},"gcm":{"product_category_for_subtypes":"com.vivaldi.linux"},"google":{"services":{"signin_scoped_device_id":"6d9558fd-f6ce-4a96-9f7b-eb6d745ed59d"}},"http_original_content_length":"16651653","http_received_content_length":"16651653","intl":{"selected_languages":"ja,en-US,en"},"invalidation":{"per_sender_topics_to_handler":{"1013309121859":{},"8181035976":{}}},"media":{"device_id_salt":"678F3486A33E409F79B94585B06C19F4","engagement":{"schema_version":4}},"media_router":{"receiver_id_hash_token":"98DTxKgcfOq57cK1dw8JZkuKUVW0qGuNYidSbCLlWGxgqIbSVuxwWcwzzsl8X48E7HvclG3O8J8wWWZAfdifTw=="},"ntp":{"num_personal_suggestions":0},"optimization_guide":{"hintsfetcher":{"last_fetch_attempt":"13283809046979224"}},"pinned_tabs":[],"plugins":{"plugins_list":[]},"profile":{"avatar_bubble_tutorial_shown":2,"avatar_index":26,"content_settings":{"enable_quiet_permission_ui_enabling_method":{"notifications":1},"exceptions":{"accessibility_events":{},"app_banner":{},"ar":{},"auto_select_certificate":{},"automatic_downloads":{},"autoplay":{},"background_sync":{},"bluetooth_chooser_data":{},"bluetooth_guard":{},"bluetooth_scanning":{},"camera_pan_tilt_zoom":{},"client_hints":{},"clipboard":{},"cookies":{},"durable_storage":{},"file_handling":{},"file_system_access_chooser_data":{},"file_system_last_picked_directory":{},"file_system_read_guard":{},"file_system_write_guard":{},"font_access":{},"formfill_metadata":{},"geolocation":{},"hid_chooser_data":{},"hid_guard":{},"http_allowed":{},"idle_detection":{},"images":{},"important_site_info":{},"insecure_private_network":{},"installed_web_app_metadata":{},"intent_picker_auto_display":{},"javascript":{},"javascript_jit":{},"legacy_cookie_access":{},"media_engagement":{"https://vivaldi.com:443,*":{"expiration":"0","last_modified":"13283809318035089","model":0,"setting":{"hasHighScore":false,"lastMediaPlaybackTime":0.0,"mediaPlaybacks":0,"visits":1}}},"media_stream_camera":{},"media_stream_mic":{},"midi_sysex":{},"mixed_script":{},"nfc":{},"notifications":{},"password_protection":{},"payment_handler":{},"permission_autoblocking_data":{},"permission_autorevocation_data":{},"popups":{},"ppapi_broker":{},"protocol_handler":{},"safe_browsing_url_check_data":{},"sensors":{},"serial_chooser_data":{},"serial_guard":{},"site_engagement":{},"sound":{},"ssl_cert_decisions":{},"storage_access":{},"subresource_filter":{},"subresource_filter_data":{},"usb_chooser_data":{},"usb_guard":{},"vr":{},"webid_active_session":{},"webid_request":{},"webid_share":{},"window_placement":{}},"pref_version":1},"created_by_version":"96.0.4664.97","creation_time":"13283808982884726","exit_type":"Normal","last_time_obsolete_http_credentials_removed":1639335443.03007,"managed_user_id":"","name":"ユーザー 1","were_old_google_logins_removed":true},"protection":{"macs":{"browser":{"show_home_button":"904452986128BBEE5A7B1FFB8F342100C3150E3D9FD76C4105DF33EB021E22FD"},"default_search_provider_data":{"template_url_data":"575D258E47F940C6887685ABA99A5839CBFE4BA30863349DFE0D0C375AAB8816"},"extensions":{"settings":{"ahfgeienlihckogmohjhadlkjgocpleb":"B460C167B30DC5A2C928CC77EA675EBE00E1E36586BFAF425E826DE3765F97E0","jffbochibkahlbbmanpmndnhmeliecah":"8A5D4E5D6D0D69C0DF28AD6290E12C6EB412C447D7C822F873022B584601E4D8","kmendfapggjehodndflmmgagdbamhnfd":"24AA71E51125A9963306C5ADBFF5BCB010B4DF21D168EF234304AB900A58A70D","lglfeioladcfajpjdnghbfgohdihdnfl":"D34413715960348E1B9E1590D620F0A063EAC64EACD99E065A1F807047E0E4A7","mhjfbmdgcfjbbpaeojofohoefgiehjai":"6E73242B4D57BD912A5E9D5D6A866B124789C55D819FAE51ECE490CCFDDB9DD1","mpognobbkildjkofajifpdfhcoklimli":"1CCAF22C75227F3F3415CCD9702D138E8211FF87371591D1B7B95587C89420A3","nkeimhogjdpnpccoofpliimaahmaaome":"3A2BF3C56B2A6239653CD9CAA1DD17E3630B4E4CC4917154B9EF290D132285D9"}},"google":{"services":{"account_id":"E5B4CD7C5FA271A47D07D462465AFD63DBF6A8CDFAFEF4839D13F8F552131486","last_account_id":"6C67156FD15665D53CD24B5098D16B462BA8B8A0EFDD969A317C3235E973A4A3","last_username":"24FCEF9BF7DF12A2935BE143E58951E09DBAA1D3E0E24430C0FF93009F5D6AFD"}},"homepage":"B1E9FE8108A84F532486D13AAC43C0AFDA16D3DFC9EB2F743AEE11F89F2F163E","homepage_is_newtabpage":"3680F776D17E3C099431BAF5381FAB9BCC0C2C70FEA4C74D12324BC94A207119","media":{"storage_id_salt":"E1848263E6199A89D48A7FDF168364BF0F31246A18227F3D149D4088C7F4D667"},"pinned_tabs":"699F1AC92729A024B80605AFC3C63BFB2A35B70C4214581BBE108F851528E9E8","prefs":{"preference_reset_time":"95C909F3D0669D5931907B455F099C510E7770D9F0BA6FF13E4C76101B44F757"},"safebrowsing":{"incidents_sent":"569707D9A4676B72F48BE92B740BE3EF895419C8A646F1AE1BA70BD9C3B41845"},"search_provider_overrides":"1E1EBA3A4DC28A23BEFCF6ED5D71CE71E9814DD587A305F6B14F72E834AF75DD","session":{"restore_on_startup":"F9BD26F5D1AA6AB5258754888529CB2A82AE68D1703BCC2A97DEAEE5DDDA190E","startup_urls":"8BB8DBC1D7CA5C58F821C38254FB2B9C874F8EE9B9905B57DE48C731C6C91837"}}},"safebrowsing":{"event_timestamps":{},"metrics_last_log_time":"13283808983"},"sessions":{"event_log":[{"crashed":false,"time":"13283808983011357","type":0},{"did_schedule_command":true,"first_session_service":true,"tab_count":2,"time":"13283809318020949","type":2,"window_count":1}],"session_data_status":3},"signin":{"allowed":false},"spellcheck":{"dictionaries":["en-US"],"dictionary":""},"translate":{"enabled":true},"translate_site_blacklist":[],"translate_site_blacklist_with_time":{},"unified_consent":{"migration_state":10},"vivaldi":{"bookmarks":{"language":"ja-JP","panel":{"sorting":{"sortField":"manually","sortOrder":1}},"version":"20"},"chained_commands":{"command_list":[{"category":"CATEGORY_COMMAND_CHAIN","chain":[{"defaultValue":"https://vivaldi.com","key":"0b01337b-4c13-4197-90c8-179c5c91cfff","label":"COMMAND_OPEN_LINK_CURRENT","param":"https://vivaldi.com","uniqueId":"ckqje6egt000001ju8eebfjru"},{"defaultValue":"https://vivaldi.net","key":"f57b8092-9426-4bc8-8e39-fcf3e315b065","label":"COMMAND_OPEN_LINK_DEFAULT","param":"https://vivaldi.net","uniqueId":"ckqjh908u0001c542f1rdhmcx"},{"defaultValue":"https://help.vivaldi.com","key":"f57b8092-9426-4bc8-8e39-fcf3e315b065","label":"COMMAND_OPEN_LINK_DEFAULT","param":"https://help.vivaldi.com","uniqueId":"ckqjh8gcl0000c5426oly646p"},{"defaultValue":1000,"key":"2eb81004-6703-46db-9933-6afcfde924e4","param":150,"uniqueId":"ckqknstqv0001wv42wtrvwo75"},{"key":"e245bce5-20a7-481f-910e-23bf1de86748","uniqueId":"ckqjiearh0006c542041vvhpp"},{"key":"e245bce5-20a7-481f-910e-23bf1de86748","uniqueId":"ckqjieung0007c5425s4xu1w7"},{"defaultValue":1000,"key":"2eb81004-6703-46db-9933-6afcfde924e4","param":125,"uniqueId":"ckqkwoqnq0000bp42ec4vy8hs"},{"key":"cdd99010-5477-4508-aa28-d671de35dcb2","uniqueId":"ckqjik1520008c5428y7b22ux"},{"key":"854f8a44-50bd-41bc-8277-acd51e719d1b","uniqueId":"ckqjim3ag0009c542u55t3ze9"}],"key":"ckqjdk4o7000001l58zh17egm","label":"リンクを開いてタイリングする","name":"COMMAND_ckqjdk4o7000001l58zh17egm","shortcut":[]},{"category":"CATEGORY_COMMAND_CHAIN","chain":[{"defaultValue":"https://vivaldi.com","key":"f57b8092-9426-4bc8-8e39-fcf3e315b065","label":"COMMAND_OPEN_LINK_DEFAULT","name":"新しいタブでリンクを開く","param":"https://vivaldi.com","uniqueId":"ckqje6egt000001ju8eebfjru"},{"key":"275ca3f7-ecfb-4445-bf87-686cd473536e","uniqueId":"ckqji854k0005c5420safcet6"}],"key":"ckqjhvf430003c5429ni7i7bz","label":"その他を閉じてカスタムタブを開く","name":"COMMAND_ckqjhvf430003c5429ni7i7bz","shortcut":[]},{"category":"CATEGORY_COMMAND_CHAIN","chain":[{"key":"7420368f-565e-409f-8eec-5b5c578429af","uniqueId":"ckqkossz70004wv42t71b1lo0"},{"key":"8dd47fc9-4c1f-4487-a475-f55bfa61aaf2","uniqueId":"ckqkokeau0002wv42ugnmzjdv"}],"key":"ckqkoqycf0003wv4210uduu8n","label":"全画面モードとリーダーモードを起動する","name":"COMMAND_ckqkoqycf0003wv4210uduu8n","shortcut":[]}],"version":1},"panels":{"list":[{"available":false,"forMailOnly":false,"format":7,"id":"format","resizable":false,"width":-1},{"available":true,"forMailOnly":false,"id":"bookmarks","resizable":false,"width":-1},{"available":true,"forMailOnly":false,"id":"downloads","resizable":false,"width":-1},{"available":true,"forMailOnly":false,"id":"history","resizable":false,"width":-1},{"available":true,"forMailOnly":false,"id":"notes","resizable":false,"width":-1},{"available":true,"forMailOnly":false,"id":"tabs","resizable":false,"width":-1},{"available":true,"forMailOnly":true,"id":"mail","resizable":false,"width":-1},{"available":true,"forMailOnly":true,"id":"feeds","resizable":false,"width":-1},{"available":true,"forMailOnly":true,"id":"contacts","resizable":false,"width":-1},{"available":true,"forMailOnly":false,"id":"calendar","resizable":false,"width":-1},{"available":true,"forMailOnly":false,"id":"chat","resizable":false,"width":-1},{"available":true,"forMailOnly":false,"id":"translate","resizable":false,"width":-1}],"show_toggle":true,"version":"5.0.2497.28","web":{"items":[{"activeUrl":"","available":true,"faviconUrl":"data:image/png;base64,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","faviconUrlValid":true,"id":"ckmam0bsw00002y5xoafpww5i","mobileMode":true,"origin":"bundle","resizable":false,"title":"","url":"https://help.vivaldi.com/","width":-1},{"activeUrl":"","available":true,"faviconUrl":"data:image/png;base64,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","faviconUrlValid":true,"id":"ckn7fhhqx0000hc2roo8jshm4","mobileMode":true,"origin":"bundle","resizable":false,"title":"","url":"https://wikipedia.org","width":-1}],"removed_items":[],"version":"5.0.2497.28"}},"privacy":{"adverse_ad_block":{"last_update":"2021-12-12T18:56:27.185Z"}},"startup":{"has_seen_feature":1,"last_seen_version":"5.0.2497.28"},"status_bar":{"display":2,"minimized":1},"system":{"show_exit_confirmation_dialog":true},"tabs":{"cycle_by_recent_order":false,"stacking":{"open_accordions":[]}},"theme":{"schedule":{"o_s":{"dark":"Vivaldi2","light":"Vivaldi3x"}}},"themes":{"preview":[]},"translate":{"enabled":true},"welcome":{"seen_pages":["welcome_four","import_data","tracker_and_ad","personalize","tabs","touch"]}},"web_apps":{"did_migrate_default_chrome_apps":[],"last_preinstall_synchronize_version":"96","system_web_app_failure_count":0,"system_web_app_last_attempted_language":"ja","system_web_app_last_attempted_update":"96.0.4664.97","system_web_app_last_installed_language":"ja","system_web_app_last_update":"96.0.4664.97"}}
EOF



mkdir=./archlive/out
cd ./archlive
mkarchiso_mod -v ./


cd ./out
ORGNAME=`ls ./`
FILENAME=`echo ${ORGNAME#arch}`
mv "$ORGNAME" "alchg$FILENAME"
cd ../


mv /usr/bin/mkarchiso_mod ./
cd ../

find ./archlive/out/
sha256sum "./archlive/out/alchg$FILENAME"


