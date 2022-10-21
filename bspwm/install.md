## Objective: setup Void FDE with detached luks header and encrypted boot on a usb

**This is work in progress do not attempt to use it in production**
### Must have:

- usb device with void:
``` 
  cp void-linux-x86_64.iso /dev/sdb && sync
```
- usb device for boot: 
```
    cfdisk /dev/sda  ( USE GPT!! )
	=> /dev/sda1 EFI with FAT32 256M
	=> /dev/sda2 EXT4	256M
```

## Steps:

1. Make sure your /dev/sda ( will contain encrypted boot )  looks like described 
2. Setup encrypted container on /dev/sda2 LUKS1 ( GRUB compat )
```
	cryptsetup --type luks1 --cipher aes-xts-plain64 --key-size 512 --use-random -i 5566 luksFormat /dev/sda2

```
3. Open cryptroot container 
```
	cryptsetup open /dev/sda2 cryptboot
```

4. Format it as ext4
```
	mkfs.ext4 /dev/mapper/cryptboot
```

5. Mount it:
```
	mount /dev/mapper/cryptboot /mnt
```
6. Create cryptroot with detached luks header
```
	cryptsetup luksFormat /dev/nvme0n1 --align-payload 4096 -i 60000 --header /mnt/cryptroot.img
```

7. Open it

```
	cryptsetup open /dev/nvme0n1 --header=/mnt/cryptroot.img cryptroot
```

8. Make volumes:
```
	pvcreate /dev/mapper/cryptroot
	vgcreate System /dev/mapper/cryptroot
        lvcreate --name root -L 50G System
        lvcreate --name swap -L 16G System
	lvcreate --name home -l 100%Free System
	mkfs.xfs -L root /dev/System/root
        mkfs.xfs -L home /dev/System/home
	mkswap /dev/System/swap
```

9. Make key for boot partition to unlock from initramfs

```	
	dd if=/dev/urandom of=/mnt/volume.key bs=1 count=1024
	cryptsetup luksAddKey /dev/sda2 /mnt/volume.key
```

10. Prepare the chroot:

```
	umount /mnt
	mount /dev/System/root /mnt
	mkdir -p /mnt/home
	mount /dev/System/home /mnt/home
	mkdir -p /mnt/boot
	mount /dev/mapper/cryptboot /mnt/boot
	mkdir -p /mnt/boot/efi
	mount /dev/sda1 /mnt/boot/efi
	for dir in dev proc sys run; do mkdir -p /mnt/$dir ; mount --rbind /$dir /mnt/$dir ; mount --make-rslave /mnt/$dir ; done
	mkdir -p /mnt/var/db/xbps/keys
	cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/
	xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt base-system cryptsetup grub-x86_64-efi lvm2 vim
	chroot /mnt
	chown root:root /
	chmod 755 /
	passwd root
	echo voidvm > /etc/hostname
	echo "LANG=en_US.UTF-8" > /etc/locale.conf
	echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
	xbps-reconfigure -f glibc-locales
```

11. Configure fstab:


	Best if you use blkid and put instead of device name *UUID=id-of-blk* without anything else.
```
	tmpfs             /tmp  tmpfs   defaults,nosuid,nodev 0       0
	/dev/System/root  /     xfs     defaults              0       0
	/dev/System/home  /home xfs     defaults              0       0
	/dev/System/swap  swap  swap    defaults              0       0
	/dev/mapper/cryptboot	/boot	ext4	defaults	0	0
	/dev/sda1	/boot/efi	vfat	defaults	0	0
```

12. Configure custom dracut module to unlock crypted devices:

    ```
        The module is in the repo
    ```

	/usr/lib/dracut/modules.d

13. Configure initramfs

```
	echo 'install_items+=" /boot/cryptroot.img /boot/volume.key "' > /etc/dracut.conf.d/10-crypt.conf
	echo 'host_only="yes" > /etc/dracut.conf.d/20-host-only.conf
	echo 'omit_dracutmodules+=" btrfs "' > /etc/dracut.conf.d/30-omit-modules.conf
```

14. Configure grub


	edit **/etc/default/grub**

```
	GRUB_ENABLE_CRYPTODISK=y
	Append to CMDLINE_LINUX_DEFAULT += "rd.auto=1 init_on_alloc=1 init_on_free=1 ipv6.disable=1"
```

15. Set boot perms:

```
# chmod 000 /boot/volume.key
# chmod -R g-rwx,o-rwx /boot
```
	
16.	Generate grub and initramfs

```
	grub-install /dev/sda --removable
	xbps-reconfigure -fa
```




Post install


enable dhcp service 

ln -s /etc/sv/dhchpd /var/service/

export EDITOR=vim
visudo

sudo xbps-install -S git xorg sxhkd rofi dbus feh betterlockscreen bspwm picom linux-firmware rxvt-unicode nerd-fonts base-devel alacritty polybar vpm vsv

enable dbus service	

ln -s /etc/sv/dbus /var/service/

cp /etc/X11/xinit/xinitrc .xinitrc
vim xinitrc 
add exec bspwm
