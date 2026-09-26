#!/bin/sh
# Construit la racine arm64 avec LXQt. Demande root pour debootstrap et chroot.
set -eu

racine=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cible=$racine/debian-root
miroir=http://deb.debian.org/debian
export DEBIAN_FRONTEND=noninteractive

if [ "$(id -u)" -ne 0 ]; then
  echo "Lance ce script en root." >&2
  exit 1
fi

if [ ! -x /usr/bin/qemu-aarch64-static ]; then
  ln -sf qemu-aarch64 /usr/bin/qemu-aarch64-static
fi

if [ ! -d "$cible/etc" ]; then
  debootstrap --arch=arm64 --variant=minbase bookworm "$cible" "$miroir"
fi

printf 'deb %s bookworm main\n' "$miroir" > "$cible/etc/apt/sources.list"

chroot "$cible" apt-get update
chroot "$cible" apt-get install -y --no-install-recommends \
  lxqt-core openbox pcmanfm-qt qterminal \
  xserver-xorg-core xserver-xorg-video-fbdev \
  xserver-xorg-input-evdev xserver-xorg-input-joystick \
  xinit x11-xserver-utils dbus \
  fonts-dejavu-core locales

sed -i 's/^# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' "$cible/etc/locale.gen"
chroot "$cible" locale-gen fr_FR.UTF-8
printf 'LANG=fr_FR.UTF-8\n' > "$cible/etc/default/locale"

install -d "$cible/etc/X11/xorg.conf.d" "$cible/root"
install -m 644 "$racine/rootfs/xorg/xorg.conf" "$cible/etc/X11/xorg.conf"
install -m 644 "$racine/rootfs/xorg/Xwrapper.config" "$cible/etc/X11/Xwrapper.config"
install -m 755 "$racine/rootfs/root/.xinitrc" "$cible/root/.xinitrc"
install -m 755 "$racine/rootfs/sbin/init" "$cible/sbin/init"
install -m 644 "$racine/rootfs/etc/os-release" "$cible/etc/os-release"
install -m 644 "$racine/rootfs/etc/issue" "$cible/etc/issue"

chroot "$cible" apt-get clean
echo "Bureau construit dans $cible"
