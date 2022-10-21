CRYPTO_DISK="/dev/nvme0n1"
BOOT_DISK="/dev/sda2"

if [ -e "$BOOT_DISK" ]; then
    if [ -e "/dev/mapper/cryptroot" ]; then
        exit 0;
    fi

    echo "Unlocking encrypted FS";
    cryptsetup luksOpen "$BOOT_DISK" cryptboot --key-file /boot/volume.key || emergency_shell;
    cryptsetup luksOpen --header /boot/cryptroot.img "$CRYPTO_DISK" cryptroot || emergency_shell;
    echo "Activating LVM"
    lvm vgchange -ay || emergency_shell;
else
    echo "Boot disk not found"
    sleep 0.5
    exit 1;
fi

exit 0;

