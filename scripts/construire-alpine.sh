#!/bin/sh
# Construit la racine Alpine arm64 avec X fbdev et Openbox.
# Voir docs/justifications/alpine.md
set -eu

racine=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cible=$racine/alpine-root
branche=${ALPINE_BRANCHE:-v3.22}
depot=https://dl-cdn.alpinelinux.org/alpine/$branche
releases=$depot/releases/aarch64

if [ "$(id -u)" -ne 0 ]; then
  echo "Lance ce script avec sudo." >&2
  exit 1
fi
if [ ! -x /usr/bin/qemu-aarch64-static ]; then
  echo "qemu-aarch64-static manque (paquet qemu-user-static)." >&2
  exit 1
fi

if [ ! -d "$cible/etc" ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "$releases/latest-releases.yaml" -o "$tmp/latest.yaml"
  # Le yaml donne le nom exact du minirootfs et son sha256.
  fichier=$(awk '/file: alpine-minirootfs-.*-aarch64.tar.gz/ {print $2}' \
    "$tmp/latest.yaml" | head -n 1)
  somme=$(awk -v f="$fichier" '
    $0 ~ "file: " f {vu = 1}
    vu && /sha256:/ {print $2; exit}
  ' "$tmp/latest.yaml")
  if [ -z "$fichier" ] || [ -z "$somme" ]; then
    echo "Minirootfs introuvable dans latest-releases.yaml." >&2
    exit 1
  fi
  curl -fL --retry 3 "$releases/$fichier" -o "$tmp/$fichier"
  echo "$somme  $tmp/$fichier" | sha256sum -c -
  mkdir -p "$cible"
  tar -xzf "$tmp/$fichier" -C "$cible"
fi

cp /usr/bin/qemu-aarch64-static "$cible/usr/bin/qemu-aarch64-static"
cp /etc/resolv.conf "$cible/etc/resolv.conf"
printf '%s/main\n%s/community\n' "$depot" "$depot" > "$cible/etc/apk/repositories"

chroot "$cible" /sbin/apk update
chroot "$cible" /sbin/apk add --no-cache \
  alpine-base eudev udev-init-scripts udev-init-scripts-openrc \
  e2fsprogs e2fsprogs-extra blkid findmnt tzdata \
  xorg-server xf86-video-fbdev xf86-input-evdev xinit xset \
  openbox tint2 xterm pcmanfm font-dejavu \
  python3 alsa-lib libx11 libxtst \
  wpa_supplicant ntfs-3g

# Services OpenRC, comme setup-alpine sur une machine sans reseau fixe.
for s in devfs dmesg udev udev-trigger; do
  chroot "$cible" /sbin/rc-update add "$s" sysinit
done
for s in hwclock modules sysctl hostname bootmisc localmount seedrng; do
  chroot "$cible" /sbin/rc-update add "$s" boot
done
chroot "$cible" /sbin/rc-update add local default
for s in killprocs mount-ro savecache; do
  chroot "$cible" /sbin/rc-update add "$s" shutdown
done

rm -f "$cible/usr/bin/qemu-aarch64-static"
echo "Alpine construit dans $cible"
