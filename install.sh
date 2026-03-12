#!/bin/bash

setfont ter-132b

setvar() {
        local answer

        while true; do
                read -p "Please, enter $1: " $2
                read -p 'Continue? [Y/n]' answer
                answer=${answer:-Y}
                case $answer in
                        [Yy]*) break;;
                        [Nn]*) continue;;
                        *) echo 'Please, enter y or n.';;
                esac
        done
}

setvar 'your username' username
setvar 'your hostname' hostname
setvar 'your Region' region
setvar 'your City' city

while true; do
        checkPassword=0

        read -rsp 'Please, enter your password: ' password
        echo
        read -rsp 'Please, reenter your password: ' checkPassword
        echo

        if [[ $password == $checkPassword ]]; then
                break
        fi

        echo 'Passwords do not match.'
done

lsblk

setvar 'a path to your disk (all of your data on that disk will be erased)' disk
diskPart1="${disk}p1"
diskPart2="${disk}p2"

parted --script $disk mklabel gpt mkpart primary fat32 1MiB 257MiB mkpart primary ext4 257MiB 100% set 1 esp on

mkfs.vfat $diskPart1
mkfs.ext4 $diskPart2

mount $diskPart2 /mnt
mkdir /mnt/boot
mount $diskPart1 /mnt/boot

pacstrap -K /mnt linux-zen linux-firmware base efibootmgr neovim base-devel git fish

genfstab -U /mnt > /mnt/etc/fstab

arch-chroot /mnt bash <<EOF
ln -sf /usr/share/zoneinfo/$region/$city /etc/localtime
hwclock --systohc

echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo $hostname > /etc/hostname

cat <<EOT > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $hostname.localdomain $hostname
EOT

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

cat <<EOT > /etc/systemd/resolved.conf
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net
DNSOverTLS=yes
Domains=~.
EOT

cat <<EOT > /etc/systemd/network/20-wired.network
[Match]
Name=enp10s0
[Network]
DHCP=yes
EOT

systemctl enable systemd-networkd systemd-resolved

useradd -m -G wheel -s /bin/bash $username

echo "$username:$password" | chpasswd
echo "root:$password" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers

efibootmgr --create --disk $disk --part 1 --label "Arch Linux" --loader /vmlinuz-linux-zen --unicode "root=PARTUUID=$(blkid -s PARTUUID -o value $diskPart2) initrd=/initramfs-linux-zen.img"

pacman -Rns efibootmgr
EOF
