#!/bin/sh
# Lance r36os dans une fenêtre. N'écrit que dans out/sandbox.
set -eu

racine=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
bac=$racine/out/sandbox
img=$bac/disque.img
noyau=$bac/vmlinuz
initrd=$bac/initrd.img
vars=$bac/vars.fd
src=$racine/debian-root
modsrc=$bac/noyau/lib/modules/6.1.0-50-cloud-arm64
deb_url=https://deb.debian.org/debian/pool/main/l/linux-signed-arm64/linux-image-6.1.0-50-cloud-arm64_6.1.176-1_arm64.deb
deb_sha=9d41a53f5d687ae1a33cf546d0ed8be955f72e5f9e97b2b4e45e41dff3353b97
efi=/usr/share/AAVMF/AAVMF_CODE.fd

mkdir -p "$bac"

if [ ! -x /usr/bin/qemu-system-aarch64 ]; then
  echo "QEMU manque. Installe le paquet qemu-system-arm." >&2
  exit 1
fi
if [ ! -f "$efi" ]; then
  echo "Firmware AAVMF absent." >&2
  exit 1
fi
if [ ! -d "$src/etc" ]; then
  echo "Racine Debian absente. Lance construire-bureau.sh." >&2
  exit 1
fi

if [ ! -f "$noyau" ]; then
  tmp=$(mktemp)
  curl -fL --retry 3 -o "$tmp" "$deb_url"
  echo "$deb_sha  $tmp" | sha256sum -c -
  rm -rf "$bac/noyau"
  dpkg-deb -x "$tmp" "$bac/noyau"
  cp "$bac/noyau/boot/vmlinuz-6.1.0-50-cloud-arm64" "$noyau"
  rm -f "$tmp"
fi

stage=$(mktemp -d)
mkdir -p "$stage/bin" "$stage/modules" "$stage/proc" "$stage/sys" "$stage/dev" "$stage/newroot"
cp "$racine/vendor/busybox" "$stage/bin/busybox"
for app in sh mount insmod echo sleep mkdir switch_root; do
  ln -s busybox "$stage/bin/$app"
done
cp "$racine/rootfs/sandbox/init" "$stage/init"
chmod 755 "$stage/init"
cp "$modsrc/kernel/drivers/virtio/virtio.ko" "$stage/modules/virtio.ko"
cp "$modsrc/kernel/drivers/virtio/virtio_ring.ko" "$stage/modules/virtio_ring.ko"
cp "$modsrc/kernel/drivers/virtio/virtio_mmio.ko" "$stage/modules/virtio_mmio.ko"
cp "$modsrc/kernel/drivers/block/virtio_blk.ko" "$stage/modules/virtio_blk.ko"
cp "$modsrc/kernel/drivers/virtio/virtio_input.ko" "$stage/modules/virtio_input.ko"
( cd "$stage" && find . | cpio -o -H newc | gzip -9 ) > "$initrd"
rm -rf "$stage"

if [ ! -f "$vars" ]; then
  cp /usr/share/AAVMF/AAVMF_VARS.fd "$vars"
fi

reconstruire=0
if [ "${1:-}" = "--rebuild" ] || [ ! -f "$img" ]; then
  reconstruire=1
fi

if [ "$reconstruire" -eq 1 ]; then
  export DISPLAY="${DISPLAY:-:0}"
  export SUDO_ASKPASS="$racine/scripts/askpass.sh"
  cat > "$SUDO_ASKPASS" << 'EOF'
#!/bin/sh
export DISPLAY="${DISPLAY:-:0}"
zenity --password --title="Construire le disque sandbox r36os"
EOF
  chmod 700 "$SUDO_ASKPASS"
  sudo -A sh << EOF
set -eu
truncate -s 4G "$img"
mkfs.ext4 -F -L r36os -b 4096 "$img"
mkdir -p /mnt/r36os-sandbox
mount -o loop "$img" /mnt/r36os-sandbox
rsync -a --delete \
  --exclude=/proc --exclude=/sys --exclude=/dev \
  --exclude=/run --exclude=/tmp --exclude=/mnt \
  --exclude=/usr/bin/qemu-aarch64-static \
  "$src/" /mnt/r36os-sandbox/
rm -f /mnt/r36os-sandbox/sbin/init \
  /mnt/r36os-sandbox/sbin/shutdown \
  /mnt/r36os-sandbox/sbin/poweroff \
  /mnt/r36os-sandbox/sbin/reboot \
  /mnt/r36os-sandbox/sbin/halt
install -m 755 "$racine/rootfs/sbin/init" /mnt/r36os-sandbox/sbin/init
install -m 755 "$racine/rootfs/sbin/shutdown" /mnt/r36os-sandbox/sbin/shutdown
install -m 755 "$racine/rootfs/sbin/poweroff" /mnt/r36os-sandbox/sbin/poweroff
install -m 755 "$racine/rootfs/sbin/reboot" /mnt/r36os-sandbox/sbin/reboot
ln -sf poweroff /mnt/r36os-sandbox/sbin/halt
install -m 644 "$racine/rootfs/etc/os-release" /mnt/r36os-sandbox/etc/os-release
install -m 644 "$racine/rootfs/etc/issue" /mnt/r36os-sandbox/etc/issue
install -m 644 "$racine/rootfs/etc/hosts" /mnt/r36os-sandbox/etc/hosts
install -d /mnt/r36os-sandbox/usr/share/lxqt /mnt/r36os-sandbox/etc/X11
install -m 644 "$racine/rootfs/lxqt/power.conf" /mnt/r36os-sandbox/usr/share/lxqt/power.conf
install -m 644 "$racine/rootfs/xorg/xorg.sandbox.conf" /mnt/r36os-sandbox/etc/X11/xorg.conf
printf 'sandbox\n' > /mnt/r36os-sandbox/etc/r36os-sandbox
mkdir -p /mnt/r36os-sandbox/proc /mnt/r36os-sandbox/sys \
  /mnt/r36os-sandbox/dev /mnt/r36os-sandbox/run \
  /mnt/r36os-sandbox/tmp /mnt/r36os-sandbox/mnt
chmod 1777 /mnt/r36os-sandbox/tmp
umount /mnt/r36os-sandbox
chown "$(id -u):$(id -g)" "$img"
EOF
  rm -f "$SUDO_ASKPASS"
fi

export DISPLAY="${DISPLAY:-:0}"
rm -f "$bac/monitor.sock"
exec qemu-system-aarch64 \
  -name r36os-sandbox \
  -machine virt \
  -cpu cortex-a35 -smp 4 -m 1024 \
  -drive if=pflash,format=raw,readonly=on,file="$efi" \
  -drive if=pflash,format=raw,file="$vars" \
  -kernel "$noyau" \
  -initrd "$initrd" \
  -append "console=ttyAMA0 console=tty0" \
  -device ramfb \
  -device virtio-blk-device,drive=disque \
  -drive id=disque,file="$img",if=none,format=raw \
  -device virtio-keyboard-device \
  -device virtio-tablet-device \
  -display gtk \
  -serial file:"$bac/serie.log" \
  -monitor unix:"$bac/monitor.sock",server,nowait
