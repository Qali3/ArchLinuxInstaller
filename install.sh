#!/bin/sh

setfont ter-132b

SURE='0'

while [ !$SURE ]; do
	echo 'Please, enter your username: '
	read USERNAME
	clear
	echo "Is {$USERNAME} correct?"
	read SURE
	if 
done
echo 'Please, enter a name for your computer: '
read COMPUTERNAME

echo 'Please, enter Region/City: '
read TIME

PASSWORD='1'
PASSWORD2='0'

while [ $PASSWORD != $PASSWORD2 ]; do
	echo 'Please, enter your password: '
	read -sr PASSWORD

	echo 'Please, enter your password again: '
	read -sr PASSWORD2
	clear
done

DISK='/dev/nvme0n1'
PART1='/dev/nvme0n1p1'
PART2='/dev/nvme0n1p2'

parted --script $DISK \
	mklabel gpt \
	mkpart primary fat32 1MiB 257MiB \
	mkpart primary ext4 257MiB 100% \
	set 1 esp on

mkfs.vfat $PART1
mkfs.ext4 $PART2

mount $PART2 /mnt
mkdir /mnt/boot
mount $PART1 /mnt/boot

pacstrap -K /mnt linux-zen linux-firmware base efibootmgr reflector neovim base-devel git fish

genfstab -U /mnt > /mnt/etc/fstab

arch-chroot /mnt bash <<EOF
ln -sf /usr/share/zoneinfo/$TIME /etc/localtime
hwclock --systohc

echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo $COMPUTERNAME > /etc/hostname

echo '127.0.0.1 localhost' > /etc/hosts
echo '::1 localhost' >> /etc/hosts
echo "127.0.1.1 $COMPUTERNAME.localdomain $COMPUTERNAME" >> /etc/hosts

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

echo 'DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net' > /etc/systemd/resolved.conf
echo 'DNSOverTLS=yes' >> /etc/systemd/resolved.conf
echo 'Domains=~.' >> /etc/systemd/resolved.conf

echo '[Match]' > /etc/systemd/network/20-wired.network
echo 'Name=enp10s0' >> /etc/systemd/network/20-wired.network
echo '[Network]' >> /etc/systemd/network/20-wired.network
echo 'DHCP=yes' >> /etc/systemd/network/20-wired.network

systemctl enable systemd-networkd systemd-resolved

useradd -m -G wheel -s /bin/bash $USERNAME

echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers

efibootmgr --create --disk $DISK --part 1 --label "Arch Linux" --loader /vmlinuz-linux-zen --unicode "root=PARTUUID=$(blkid -s PARTUUID -o value $PART2) initrd=/initramfs-linux-zen.img"
EOF
