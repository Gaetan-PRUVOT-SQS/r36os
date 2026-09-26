#!/bin/sh
# Construit l'image ext4 de la racine. À lancer sous fakeroot.
set -eu

racine=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
stage=$racine/out/root-stage
image=$racine/out/r36os-root.ext4
busybox=$racine/vendor/busybox

rm -rf "$stage"
mkdir -p "$stage/bin" "$stage/sbin" "$stage/etc" "$stage/root" \
  "$stage/proc" "$stage/sys" "$stage/dev" "$stage/tmp" "$stage/mnt"

cp "$busybox" "$stage/bin/busybox"
chmod 755 "$stage/bin/busybox"

for cmd in sh mount echo cat ls uname dmesg sleep hostname \
  poweroff reboot mkdir switch_root; do
  ln -s busybox "$stage/bin/$cmd"
done
ln -s ../bin/sh "$stage/sbin/sh"

cp "$racine/rootfs/sbin/init" "$stage/sbin/init"
chmod 755 "$stage/sbin/init"
cp "$racine/rootfs/etc/os-release" "$stage/etc/os-release"
cp "$racine/rootfs/etc/issue" "$stage/etc/issue"
cp "$racine/rootfs/etc/passwd" "$stage/etc/passwd"
cp "$racine/rootfs/etc/group" "$stage/etc/group"
cp "$racine/rootfs/etc/fstab" "$stage/etc/fstab"
chmod 644 "$stage/etc/"*

chown -R 0:0 "$stage"
chmod 755 "$stage" "$stage/bin" "$stage/sbin" "$stage/etc" "$stage/root" \
  "$stage/proc" "$stage/sys" "$stage/dev" "$stage/tmp" "$stage/mnt"
chmod 1777 "$stage/tmp"

rm -f "$image"
mkfs.ext4 -F -L r36os -b 4096 -d "$stage" "$image" 16M
