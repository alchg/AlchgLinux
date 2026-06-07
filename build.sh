#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -e

log_info() {
  echo "[INFO] $1"
}

log_error() {
  local message="$1"
  echo "[ERROR] $message" >&2
  exit 1
}


log_info "Starting initialization..."


if ! command -v xorriso; then
  log_error "xorriso command not found. Requires libisoburn."
fi

if ! command -v mmd; then
  log_error "mmd command not found. Requires mtools."
fi

if ! command -v mkfs.fat; then
  log_error "mkfs.fat command not found. Requires dosfstools."
fi

if ! command -v mksquashfs; then
  log_error "mksquashfs command not found. Requires squashfs-tools."
fi

if ! command -v pacstrap; then
  log_error "pacstrap command not found. Requires arch-install-scripts."
fi

if ! command -v grub-mkstandalone; then
  log_error "grub-mkstandalone command not found. Requires grub."
fi

if [[ "$EUID" -ne 0 ]]; then
  log_error "This script must be run as root."
fi

archlive="archlive"
if [[ -d "$archlive" ]]; then
  rm -rf "$archlive"
fi
mkdir "$archlive"
cd "$archlive"


log_info "Done."


log_info "Starting pacstrap..."


pkg_list=(
base
linux
linux-firmware
intel-ucode
amd-ucode
mkinitcpio
mkinitcpio-archiso
pv
memtest86+
memtest86+-efi
edk2-shell
otf-ipafont
otf-font-awesome
fcitx5-im
fcitx5-mozc
pipewire
pipewire-pulse
pamixer
networkmanager
network-manager-applet
sway
swaybg
waybar
wofi
wdisplays
foot
gvim
vi
virt-viewer
firefox
)

rootfs=rootfs
install -d -m 0755 -o 0 -g 0 -- "${rootfs}"

install -d -m 0755 -o 0 -g 0 -- "${rootfs}/etc/mkinitcpio.conf.d/"
cat >"${rootfs}/etc/mkinitcpio.conf.d/archiso.conf"<<'EOF'
HOOKS=(base udev modconf archiso block filesystems)
COMPRESSION="zstd"
COMPRESSION_OPTIONS=(-19)
EOF

install -d -m 0755 -o 0 -g 0 -- "${rootfs}/etc/mkinitcpio.d/"
cat >"${rootfs}/etc/mkinitcpio.d/linux.preset"<<'EOF'
# mkinitcpio preset file for the 'linux' package on archiso

PRESETS=('archiso')

ALL_kver='/boot/vmlinuz-linux'
archiso_config='/etc/mkinitcpio.conf.d/archiso.conf'

archiso_image="/boot/initramfs-linux.img"
EOF

env -u TMPDIR pacstrap -c -G -M -- "${rootfs}" "${pkg_list[@]}"


log_info "Done."


log_info "Customize the system."


cat >"${rootfs}/etc/hostname"<<'EOF'
archiso
EOF

install -d -m 0755 -o 0 -g 0 -- "${rootfs}/etc/systemd/system/getty@tty1.service.d/"
cat >"${rootfs}/etc/systemd/system/getty@tty1.service.d/autologin.conf"<<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin user - $TERM
EOF

cat >"${rootfs}/etc/passwd"<<'EOF'
root:x:0:0:root:/root:/usr/bin/bash
user:x:1000:1000::/home/user:/usr/bin/bash
EOF

cat >"${rootfs}/etc/shadow"<<'EOF'
root:$6$3g2Z7dB8Jw22J8su$l6tBV5cX.JCyA7u3t8oU1YcdaCVTob4JrCQUJ9sUYjGe9YTEEaEZGBGlZh.bLhYu9WhH9Hcybr5wsYxcQlJ1w0:14871::::::
user::14871::::::
EOF

install -d -m 0755 -o 0 -g 0 -- "${rootfs}/home/user/"
cp -r ../skel/. "${rootfs}/home/user/"
find "${rootfs}/home/user/" |xargs -I {} chown user {}

cat >"${rootfs}/etc/locale.conf"<<'EOF'
LANG=C.UTF-8
EOF

cat >"${rootfs}/etc/localtime"<<'EOF'
/usr/share/zoneinfo/UTC
EOF

cat >${rootfs}/etc/systemd/system/startup.service<<"EOF"
[Unit]
Description=startup configuration

[Service]
Type=simple
ExecStart=/usr/local/sbin/startup.sh

[Install]
WantedBy=multi-user.target
EOF

mkdir -p ${rootfs}/usr/local/sbin/
cat >${rootfs}/usr/local/sbin/startup.sh<<'EOF'
#!/bin/bash

localectl set-locale LANG=ja_JP.UTF-8
timedatectl set-timezone Asia/Tokyo
timedatectl set-ntp yes
systemctl start NetworkManager.service
sed -i s/^#Server/Server/g /etc/pacman.d/mirrorlist
pacman-key --init
pacman-key --populate archlinux
/usr/local/sbin/cowspace.sh

EOF
chmod +x ${rootfs}/usr/local/sbin/startup.sh

cat >${rootfs}/usr/local/sbin/cowspace.sh<<"EOF"
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
chmod +x ${rootfs}/usr/local/sbin/cowspace.sh

mkdir -p ${rootfs}/etc/systemd/system/multi-user.target.wants
ln -s /etc/systemd/system/startup.service ${rootfs}/etc/systemd/system/multi-user.target.wants/startup.service

#sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' ${rootfs}/etc/locale.gen
sed -i 's/#ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' ${rootfs}/etc/locale.gen
eval -- env -u TMPDIR arch-chroot "${rootfs}" "locale-gen"

log_info "Done."


log_info "Preparing kernel and initramfs."


isofs=isofs
base=arch
arch=x86_64

install -d -m 0755 -- "${isofs}/${base}/boot/${arch}"
install -m 0644 -- "${rootfs}/boot/initramfs-"*".img" "${isofs}/${base}/boot/${arch}/"
install -m 0644 -- "${rootfs}/boot/vmlinuz-"* "${isofs}/${base}/boot/${arch}/"


log_info "Done."


log_info "Setting EFI boot."


install -d -m 0755 -- "${isofs}/boot"

printf -v SOURCE_DATE_EPOCH '%(%s)T' -1
export SOURCE_DATE_EPOCH

TZ=UTC printf -v uuid '%(%F-%H-%M-%S-00)T' "$SOURCE_DATE_EPOCH"

install -d -- "grub"

cat >"grub/grub.cfg"<<EOF
# Load partition table and file system modules
insmod part_gpt
insmod part_msdos
insmod fat
insmod iso9660
insmod ntfs
insmod ntfscomp
insmod exfat
insmod udf

# Use graphics-mode output
if loadfont "\${prefix}/fonts/unicode.pf2" ; then
    insmod all_video
    set gfxmode="auto"
    terminal_input console
    terminal_output console
fi

# Enable serial console
insmod serial
insmod usbserial_common
insmod usbserial_ftdi
insmod usbserial_pl2303
insmod usbserial_usbdebug
if serial --unit=0 --speed=115200; then
    terminal_input --append serial
    terminal_output --append serial
fi

# Get a human readable platform identifier
if [ "\${grub_platform}" == 'efi' ]; then
    archiso_platform='UEFI'
    if [ "\${grub_cpu}" == 'x86_64' ]; then
        archiso_platform="x64 \${archiso_platform}"
    elif [ "\${grub_cpu}" == 'i386' ]; then
        archiso_platform="IA32 \${archiso_platform}"
    else
        archiso_platform="\${grub_cpu} \${archiso_platform}"
    fi
elif [ "\${grub_platform}" == 'pc' ]; then
    archiso_platform='BIOS'
else
    archiso_platform="\${grub_cpu} \${grub_platform}"
fi

# Set default menu entry
default=archlinux
timeout=5
timeout_style=menu


# Menu entries

menuentry "Arch Linux (${arch}, \${archiso_platform})" --class arch --class gnu-linux --class gnu --class os --id 'archlinux' {
    set gfxpayload=keep
    linux /${base}/boot/${arch}/vmlinuz-linux archisobasedir=${base} archisosearchuuid=${uuid}
    initrd /${base}/boot/${arch}/initramfs-linux.img
}

if [ "\${grub_platform}" == 'efi' -a "\${grub_cpu}" == 'x86_64' -a -f '/boot/memtest86+/memtest.efi' ]; then
    menuentry 'Run Memtest86+ (RAM test)' --class memtest86 --class gnu --class tool {
        set gfxpayload=800x600,1024x768
        linux /boot/memtest86+/memtest.efi
    }
fi
if [ "\${grub_platform}" == 'pc' -a -f '/boot/memtest86+/memtest' ]; then
    menuentry 'Run Memtest86+ (RAM test)' --class memtest86 --class gnu --class tool {
        set gfxpayload=800x600,1024x768
        linux /boot/memtest86+/memtest
    }
fi
if [ "\${grub_platform}" == 'efi' ]; then
    if [ "\${grub_cpu}" == 'x86_64' -a -f '/shellx64.efi' ]; then
        menuentry 'UEFI Shell' {
            chainloader /shellx64.efi
        }
    fi

    menuentry 'UEFI Firmware Settings' --id 'uefi-firmware' {
        fwsetup
    }
fi

menuentry 'System shutdown' --class shutdown --class poweroff {
    echo 'System shutting down...'
    halt
}

menuentry 'System restart' --class reboot --class restart {
    echo 'System rebooting...'
    reboot
}

EOF

cat >"grub/loopback.cfg"<<EOF
# https://www.supergrubdisk.org/wiki/Loopback.cfg

# Search for the ISO volume
search --no-floppy --set=archiso_img_dev --file "\${iso_path}"
probe --set archiso_img_dev_uuid --fs-uuid "\${archiso_img_dev}"

# Get a human readable platform identifier
if [ "\${grub_platform}" == 'efi' ]; then
    archiso_platform='UEFI'
    if [ "\${grub_cpu}" == 'x86_64' ]; then
        archiso_platform="x64 \${archiso_platform}"
    elif [ "\${grub_cpu}" == 'i386' ]; then
        archiso_platform="IA32 \${archiso_platform}"
    else
        archiso_platform="\${grub_cpu} \${archiso_platform}"
    fi
elif [ "\${grub_platform}" == 'pc' ]; then
    archiso_platform='BIOS'
else
    archiso_platform="\${grub_cpu} \${grub_platform}"
fi

# Set default menu entry
default=archlinux
timeout=5
timeout_style=menu


# Menu entries

menuentry "Arch Linux (${arch}, \${archiso_platform})" --class arch --class gnu-linux --class gnu --class os --id 'archlinux' {
    set gfxpayload=keep
    linux /${base}/boot/${arch}/vmlinuz-linux archisobasedir=${base} img_dev=UUID=\${archiso_img_dev_uuid} img_loop="\${iso_path}"
    initrd /${base}/boot/${arch}/initramfs-linux.img
}

if [ "\${grub_platform}" == 'efi' -a "\${grub_cpu}" == 'x86_64' -a -f '/boot/memtest86+/memtest.efi' ]; then
    menuentry 'Run Memtest86+ (RAM test)' --class memtest86 --class gnu --class tool {
        set gfxpayload=800x600,1024x768
        linux /boot/memtest86+/memtest.efi
    }
fi
if [ "\${grub_platform}" == 'pc' -a -f '/boot/memtest86+/memtest' ]; then
    menuentry 'Run Memtest86+ (RAM test)' --class memtest86 --class gnu --class tool {
        set gfxpayload=800x600,1024x768
        linux /boot/memtest86+/memtest
    }
fi
if [ "\${grub_platform}" == 'efi' ]; then
    if [ "\${grub_cpu}" == 'x86_64' -a -f '/shellx64.efi' ]; then
        menuentry 'UEFI Shell' {
            chainloader /shellx64.efi
        }
    fi

    menuentry 'UEFI Firmware Settings' --id 'uefi-firmware' {
        fwsetup
    }
fi

menuentry 'System shutdown' --class shutdown --class poweroff {
    echo 'System shutting down...'
    halt
}

menuentry 'System restart' --class reboot --class restart {
    echo 'System rebooting...'
    reboot
}

EOF

IFS='' read -r -d '' grubembedcfg <<'EOF' || true
if ! [ -d "$cmdpath" ]; then
    # On some firmware, GRUB has a wrong cmdpath when booted from an optical disc. During El Torito boot, GRUB is
    # launched from a case-insensitive FAT-formatted EFI system partition, but it seemingly cannot access that partition
    # and sets cmdpath to the whole cd# device which has case-sensitive ISO 9660 + Rock Ridge + Joliet file systems.
    # See https://gitlab.archlinux.org/archlinux/archiso/-/issues/183 and https://savannah.gnu.org/bugs/?62886
    if regexp --set=1:archiso_bootdevice '^\(([^)]+)\)\/?[Ee][Ff][Ii]\/[Bb][Oo][Oo][Tt]\/?$' "${cmdpath}"; then
        set cmdpath="(${archiso_bootdevice})/EFI/BOOT"
        set ARCHISO_HINT="${archiso_bootdevice}"
    fi
fi

# Prepare a hint for the search command using the device in cmdpath
if [ -z "${ARCHISO_HINT}" ]; then
    regexp --set=1:ARCHISO_HINT '^\(([^)]+)\)' "${cmdpath}"
fi

# Search for the ISO volume
if search --no-floppy --set=archiso_device --file '%ARCHISO_SEARCH_FILENAME%' --hint "${ARCHISO_HINT}"; then
    set ARCHISO_HINT="${archiso_device}"
    if probe --set ARCHISO_UUID --fs-uuid "${ARCHISO_HINT}"; then
        export ARCHISO_UUID
    fi
else
    echo "Could not find a volume with a '%ARCHISO_SEARCH_FILENAME%' file on it!"
fi

# Load grub.cfg
if [ "${ARCHISO_HINT}" == 'memdisk' -o -z "${ARCHISO_HINT}" ]; then
    echo 'Could not find the ISO volume!'
elif [ -e "(${ARCHISO_HINT})/boot/grub/grub.cfg" ]; then
    export ARCHISO_HINT
    set root="${ARCHISO_HINT}"
    configfile "(${ARCHISO_HINT})/boot/grub/grub.cfg"
else
    echo "File '(${ARCHISO_HINT})/boot/grub/grub.cfg' not found!"
fi
EOF
iso_name="archlinux-baseline"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
iso_label="ARCH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
search_filename="/boot/${uuid}.uuid"
: >${isofs}${search_filename}
grubembedcfg="${grubembedcfg//'%ARCHISO_SEARCH_FILENAME%'/"${search_filename}"}"
printf '%s\n' "$grubembedcfg" >"grub-embed.cfg"
printf '%.1024s' \
    "$(printf '# GRUB Environment Block\nNAME=%s\nVERSION=%s\nARCHISO_LABEL=%s\nINSTALL_DIR=%s\nARCH=%s\nARCHISO_SEARCH_FILENAME=%s\n%s' \
        "${iso_name}" \
        "${iso_version}" \
        "${iso_label}" \
        "${base}" \
        "${arch}" \
        "${search_filename}" \
        "$(printf '%0.1s' "#"{1..1024})")" \
    >"grub/grubenv"

install -d -m 0755 -- "${isofs}/boot/grub"

cp -r --remove-destination -- grub/* "${isofs}/boot/grub/"


log_info "Done."


log_info "Create a FAT image for the EFI."


efibootimg="efiboot.img"


# Create EFI binary
# Module list from https://bugs.archlinux.org/task/71382#comment202911
grubmodules=(all_video at_keyboard boot btrfs cat chain configfile echo efifwsetup efinet exfat ext2 f2fs fat font \
    gfxmenu gfxterm gzio halt hfsplus iso9660 jpeg keylayouts linux loadenv loopback lsefi lsefimmap \
    minicmd normal ntfs ntfscomp part_apple part_gpt part_msdos png read reboot regexp search \
    search_fs_file search_fs_uuid search_label serial sleep tpm udf usb usbserial_common usbserial_ftdi \
    usbserial_pl2303 usbserial_usbdebug video xfs zstd)

grub-mkstandalone -O i386-efi \
    --modules="${grubmodules[*]}" \
    --locales="en@quot" \
    --themes="" \
    --sbat=/usr/share/grub/sbat.csv \
    --disable-shim-lock \
    -o "BOOTIA32.EFI" "boot/grub/grub.cfg=grub-embed.cfg"

efiboot_files+=(
"BOOTIA32.EFI"
)

grub-mkstandalone -O x86_64-efi \
    --modules="${grubmodules[*]}" \
    --locales="en@quot" \
    --themes="" \
    --sbat=/usr/share/grub/sbat.csv \
    --disable-shim-lock \
    -o "BOOTx64.EFI" "boot/grub/grub.cfg=grub-embed.cfg"

efiboot_files+=(
"BOOTx64.EFI"
"${rootfs}/usr/share/edk2-shell/x64/Shell_Full.efi"
)

efiboot_imgsize="$(du -bcs -- "${efiboot_files[@]}" 2>/dev/null | awk 'END { print $1 }')"

efiboot_imgsize_kib="$(
    awk 'function ceil(x){return int(x)+(x>int(x))}
        function byte_to_kib(x){return x/1024}
        function mib_to_kib(x){return x*1024}
        END {print mib_to_kib(ceil((byte_to_kib($1)+8192)/1024))}' <<<"${efiboot_imgsize}"
)"

#mkfs.fat -C -n ARCHISO_EFI -F 32 "${efibootimg}" "${efiboot_imgsize_kib}"
mkfs.fat -C -n ARCHISO_EFI "${efibootimg}" "${efiboot_imgsize_kib}"

mmd -i "${efibootimg}" ::/EFI ::/EFI/BOOT


log_info "Done."


log_info "Setting for UEFI."


mcopy -i "${efibootimg}" "BOOTIA32.EFI" ::/EFI/BOOT/BOOTIA32.EFI

mcopy -i "${efibootimg}" "BOOTx64.EFI" ::/EFI/BOOT/BOOTx64.EFI

mcopy -i "${efibootimg}" "${rootfs}/usr/share/edk2-shell/x64/Shell_Full.efi" ::/shellx64.efi

install -d -m 0755 -- "${isofs}/boot/memtest86+/"

install -m 0644 -- "${rootfs}/boot/memtest86+/memtest.efi" "${isofs}/boot/memtest86+/memtest.efi"

install -m 0644 -- "${rootfs}/usr/share/licenses/spdx/GPL-2.0-only.txt" "${isofs}/boot/memtest86+/LICENSE"


log_info "Done."


log_info "Setting for El Torito."


install -d -m 0755 -- "${isofs}/EFI/BOOT"

install -m 0644 -- "BOOTIA32.EFI" "${isofs}/EFI/BOOT/BOOTIA32.EFI"

install -m 0644 -- "BOOTx64.EFI" "${isofs}/EFI/BOOT/BOOTx64.EFI"

install -m 0644 -- "${rootfs}/usr/share/edk2-shell/x64/Shell_Full.efi" "${isofs}/shellx64.efi"


log_info "Done."


log_info "Setting BIOS boot from MBR."


mkdir -p "${isofs}/boot/grub/i386-pc"

grubmodules=(all_video at_keyboard biosdisk boot btrfs cat chain configfile echo exfat ext2 f2fs fat font \
    gfxmenu gfxterm gzio halt hfsplus iso9660 jpeg keylayouts linux loadenv loopback \
    minicmd normal ntfs ntfscomp part_apple part_gpt part_msdos png read reboot regexp search \
    search_fs_file search_fs_uuid search_label serial sleep test udf usb usbserial_common usbserial_ftdi \
    usbserial_pl2303 usbserial_usbdebug video xfs zstd)

grub-mkimage -O i386-pc \
    -o core.img \
    -p /boot/grub \
    "${grubmodules[@]}"

cat /usr/lib/grub/i386-pc/cdboot.img core.img > ${isofs}/boot/grub/i386-pc/eltorito.img

mkdir "${isofs}/boot/grub/fonts"
cp /usr/share/grub/unicode.pf2 ${isofs}/boot/grub/fonts/

install -m 0644 -- "${rootfs}/boot/memtest86+/memtest.bin" "${isofs}/boot/memtest86+/memtest"

log_info "Done."


log_info "Cleanup rootfs."


[[ -d "${rootfs}/boot" ]] && find "${rootfs}/boot" -mindepth 1 -delete
[[ -d "${rootfs}/var/lib/pacman" ]] && find "${rootfs}/var/lib/pacman" -maxdepth 1 -type f -delete
[[ -d "${rootfs}/var/lib/pacman/sync" ]] && find "${rootfs}/var/lib/pacman/sync" -delete
[[ -d "${rootfs}/var/cache/pacman/pkg" ]] && find "${rootfs}/var/cache/pacman/pkg" -type f -delete
[[ -d "${rootfs}/var/log" ]] && find "${rootfs}/var/log" -type f -delete
[[ -d "${rootfs}/var/tmp" ]] && find "${rootfs}/var/tmp" -mindepth 1 -delete
find "./" \( -name '*.pacnew' -o -name '*.pacsave' -o -name '*.pacorig' \) -delete
rm -f -- "${rootfs}/etc/machine-id"
printf 'uninitialized\n' >"${rootfs}/etc/machine-id"


log_info "Done."


log_info "Create a squashfs."


install -d -m 0755 -- "${isofs}/${base}/${arch}"
squashfsimg="${isofs}/${base}/${arch}/airootfs.sfs"

mksquashfs "${rootfs}" "${squashfsimg}" -noappend -comp zstd -Xcompression-level 19 -b 1M
sha512sum ${squashfsimg} >"${isofs}/${base}/${arch}/airootfs.sha512"


log_info "Done."


log_info "Build ISO."

mkdir out
isofile="out/alchglinux-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)-${arch}.iso"

xorriso \
-no_rc \
-as mkisofs \
-iso-level 3 \
-full-iso9660-filenames \
-joliet \
-joliet-long \
-rational-rock \
-volid "ARCH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)" \
-appid "Arch Linux Live DVD" \
-publisher "None" \
-preparer "prepared by ${0##*/}" \
--grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
--mbr-force-bootable \
-partition_offset 16 \
-eltorito-boot boot/grub/i386-pc/eltorito.img \
-eltorito-catalog boot/grub/boot.cat \
--grub2-boot-info \
-no-emul-boot -boot-load-size 4 -boot-info-table \
-append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B "${efibootimg}" \
-eltorito-alt-boot \
-e --interval:appended_partition_2:all:: \
-no-emul-boot \
-isohybrid-gpt-basdat \
-no-pad \
-output "${isofile}" \
"${isofs}/"

sha256sum "${isofile}" >out/sha256sum.txt
du -hs "${isofile}"


log_info "Done."
