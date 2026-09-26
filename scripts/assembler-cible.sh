#!/bin/sh
# Construit boot.img et racine.img pour la puce. N'écrit pas la console.
set -eu

racine=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
out=$racine/out
dossier=$out/cible
src=$racine/debian-root
stage=$dossier/stage
boot=$dossier/boot.img
image=$dossier/racine.img

python3 "$racine/scripts/cible.py" preparer

if [ ! -x "$src/usr/bin/startlxqt" ] || [ ! -x "$src/usr/bin/startx" ]; then
  echo "Bureau absent dans $src." >&2
  exit 1
fi

export DISPLAY="${DISPLAY:-:0}"
export SUDO_ASKPASS="$racine/scripts/askpass-assembler.sh"
cat > "$SUDO_ASKPASS" << 'EOF'
#!/bin/sh
export DISPLAY="${DISPLAY:-:0}"
zenity --password --title="Preparer r36os pour la puce"
EOF
chmod 700 "$SUDO_ASKPASS"

travail=$(mktemp)
cat > "$travail" << EOF
set -eu
export LANG=C
racine=$racine
src=$src
dossier=$dossier
stage=$stage
boot=$boot
image=$image
mntb=/mnt/r36os-cible-boot
mntr=/mnt/r36os-cible-root
ok=0
nettoyer() {
  umount "\$mntb" 2>/dev/null || true
  umount "\$mntr" 2>/dev/null || true
  rm -rf "\$stage"
  if [ "\$ok" != 1 ]; then
    rm -f "\$boot" "\$image"
  fi
}
trap nettoyer EXIT
rm -rf "\$stage"
mkdir -p "\$stage" "\$mntb" "\$mntr"
rm -f "\$boot" "\$image"
truncate -s 128M "\$boot"
mkfs.vfat -F 32 -s 4 -n BOOT "\$boot"
mount -o loop "\$boot" "\$mntb"
cp -f "\$dossier/boot/boot.ini" "\$mntb/boot.ini"
cp -f "\$dossier/boot/Image" "\$mntb/Image"
cp -f "\$dossier/boot/uInitrd" "\$mntb/uInitrd"
cp -f "\$dossier/boot/rk3326-r36max-type1-linux.dtb" \\
  "\$mntb/rk3326-r36max-type1-linux.dtb"
if ! grep -q 'load mmc 0:' "\$mntb/boot.ini"; then
  echo "boot.ini interne incorrect." >&2
  exit 1
fi
sync
umount "\$mntb"
rsync -a \\
  --exclude=/proc --exclude=/sys --exclude=/dev \\
  --exclude=/run --exclude=/tmp --exclude=/mnt \\
  --exclude=/usr/bin/qemu-aarch64-static \\
  "\$src/" "\$stage/"
sh "\$racine/scripts/habiller.sh" "\$racine" "\$stage"
octets=\$(du -sb "\$stage" | awk '{print \$1}')
marge=\$((512 * 1024 * 1024))
bloc=\$((512 * 1024))
taille=\$(( (octets + marge + bloc - 1) / bloc * bloc ))
max=\$((14989312 * 512))
if [ "\$taille" -gt "\$max" ]; then
  echo "Racine trop grosse pour la puce." >&2
  exit 1
fi
truncate -s "\$taille" "\$image"
mkfs.ext4 -F -b 4096 -E stride=128,stripe_width=128 -L r36os -d "\$stage" "\$image"
etiq=\$(tune2fs -l "\$image" | awk -F: '/volume name/{gsub(/ /,"",\$2); print \$2}')
if [ "\$etiq" != "r36os" ]; then
  echo "Etiquette \$etiq." >&2
  exit 1
fi
mount -o loop "\$image" "\$mntr"
test -x "\$mntr/usr/bin/startlxqt"
test -x "\$mntr/sbin/init"
test -f "\$mntr/usr/lib/r36os/cible.py"
test -x "\$mntr/sbin/resize2fs"
grep -q resize2fs "\$mntr/sbin/init"
if grep -n 'now)' "\$mntr/sbin/shutdown" >/dev/null; then
  echo "shutdown traite encore now." >&2
  exit 1
fi
sync
umount "\$mntr"
echo "images \$taille"
ok=1
EOF
sh -n "$travail"
trap 'rm -f "$travail" "$SUDO_ASKPASS"' EXIT
sudo -A sh "$travail"
python3 "$racine/scripts/cible.py" controler mbr "$dossier/mbr.bin" 0
python3 "$racine/scripts/cible.py" controler boot "$boot" 16384
python3 "$racine/scripts/cible.py" controler racine "$image" 278528
echo "Images pretes. La puce n'est pas encore ecrite."
