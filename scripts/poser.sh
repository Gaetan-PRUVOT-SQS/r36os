#!/bin/sh
# Ancien chemin carte. Le systeme s'ecrit par l'OTG, sauf --carte.
set -eu

if [ "${1:-}" != "--carte" ]; then
  echo "Le systeme s'ecrit par l'OTG, pas sur la carte." >&2
  echo "sudo scripts/ecrire-puce.sh --ecrire" >&2
  exit 1
fi

racine=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
out=$racine/out
src=$racine/debian-root
dev=/dev/mmcblk0

for f in boot.ini uInitrd Image rk3326-r36max-type1-linux.dtb \
  rk3326-r36max-type1-linux.dtb.sans-emmc; do
  if [ ! -f "$out/$f" ]; then
    echo "Manque $out/$f. Lance make d'abord." >&2
    exit 1
  fi
done

if [ ! -x "$src/usr/bin/startlxqt" ] || [ ! -x "$src/usr/bin/startx" ]; then
  echo "Bureau absent dans $src." >&2
  exit 1
fi

if [ ! -f "$racine/rootfs/sbin/init" ]; then
  echo "Manque l'init du bureau." >&2
  exit 1
fi

if [ ! -b "$dev" ]; then
  echo "Carte absente." >&2
  exit 1
fi

nom=$(lsblk -ndo NAME "$dev")
bus=$(lsblk -ndo TRAN "$dev")
octets=$(lsblk -ndbo SIZE "$dev")
p2octets=$(lsblk -ndbo SIZE "${dev}p2")
if [ "$nom" != "mmcblk0" ] || [ "$bus" != "mmc" ]; then
  echo "Refus: $nom n'est pas la carte." >&2
  exit 1
fi
if [ "$octets" -gt 75161927680 ]; then
  echo "Refus: disque trop grand." >&2
  exit 1
fi
if [ "$p2octets" -gt 12884901888 ]; then
  echo "Refus: la partition racine est trop grande." >&2
  exit 1
fi

export DISPLAY="${DISPLAY:-:0}"
export SUDO_ASKPASS="$racine/scripts/askpass.sh"
cat > "$SUDO_ASKPASS" << 'EOF'
#!/bin/sh
export DISPLAY="${DISPLAY:-:0}"
zenity --password --title="Installer le bureau r36os"
EOF
chmod 700 "$SUDO_ASKPASS"

travail=$(mktemp)
cat > "$travail" << EOF
set -eu
dev=$dev
out=$out
src=$src
racine=$racine
sync
i=0
while [ "\$i" -lt 5 ]; do
  umount \${dev}p1 2>/dev/null || true
  umount \${dev}p2 2>/dev/null || true
  umount \${dev}p3 2>/dev/null || true
  if ! findmnt \${dev}p1 >/dev/null && ! findmnt \${dev}p2 >/dev/null && ! findmnt \${dev}p3 >/dev/null; then
    break
  fi
  i=\$((i + 1))
  sleep 1
done
if findmnt \${dev}p1 >/dev/null || findmnt \${dev}p2 >/dev/null || findmnt \${dev}p3 >/dev/null; then
  echo "Une partition de la carte est encore montée." >&2
  findmnt \${dev}p1 \${dev}p2 \${dev}p3 >&2 || true
  exit 1
fi
mkfs.ext4 -F -L r36os \${dev}p2
mkdir -p /mnt/r36os-root /mnt/r36os-boot
mount \${dev}p2 /mnt/r36os-root
rsync -a --delete \\
  --exclude=/proc --exclude=/sys --exclude=/dev \\
  --exclude=/run --exclude=/tmp --exclude=/mnt \\
  --exclude=/usr/bin/qemu-aarch64-static \\
  "\$src/" /mnt/r36os-root/
sh "\$racine/scripts/habiller.sh" "\$racine" /mnt/r36os-root
umount /mnt/r36os-root
mount \${dev}p1 /mnt/r36os-boot
b=/mnt/r36os-boot
cp -f "\$out/boot.ini" "\$b/boot.ini"
cp -f "\$out/uInitrd" "\$b/uInitrd"
cp -f "\$out/Image" "\$b/Image"
cp -f "\$out/rk3326-r36max-type1-linux.dtb" "\$b/rk3326-r36max-type1-linux.dtb"
cp -f "\$out/rk3326-r36max-type1-linux.dtb.sans-emmc" \
  "\$b/rk3326-r36max-type1-linux.dtb.sans-emmc"
sync
umount /mnt/r36os-boot
EOF
sh -n "$travail"
trap 'rm -f "$travail" "$SUDO_ASKPASS"' EXIT
sudo -A sh "$travail"

echo "r36os est sur la carte."
