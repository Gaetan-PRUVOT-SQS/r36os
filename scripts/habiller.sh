#!/bin/sh
# Pose la couche materiel r36os sur une racine Alpine deja copiee.
# Voir docs/justifications/alpine.md
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: habiller.sh RACINE DEST" >&2
  exit 1
fi

racine=$1
dest=$2
r=$racine/rootfs

install -d "$dest/usr/bin" "$dest/usr/lib/r36os" "$dest/etc/local.d" \
  "$dest/etc/X11/xorg.conf.d" "$dest/etc/fonts" \
  "$dest/lib/firmware/rtlwifi" \
  "$dest/root/.config/openbox" "$dest/root/.config/tint2" \
  "$dest/root/.config/libfm" \
  "$dest/media/jeux" "$dest/media/tf2" "$dest/var/lib/r36os"

# Outils materiel : manette, son, lumiere, batterie, wifi, cartes, clavier.
for f in "$r"/usr/bin/*; do
  install -m 755 "$f" "$dest/usr/bin/$(basename "$f")"
done
install -m 755 "$r/usr/lib/r36os/udhcpc.sh" "$dest/usr/lib/r36os/udhcpc.sh"

# Demarrage et arret : OpenRC lance local.d.
for f in "$r"/local.d/*; do
  install -m 755 "$f" "$dest/etc/local.d/$(basename "$f")"
done

# Microprogramme du wifi 8188fu, aux deux chemins que le pilote essaie.
install -m 644 "$r/firmware/rtl8188fufw.bin" "$dest/lib/firmware/rtl8188fufw.bin"
install -m 644 "$r/firmware/rtl8188fufw.bin" \
  "$dest/lib/firmware/rtlwifi/rtl8188fufw.bin"

# Ecran en framebuffer, manette ignoree par X, polices sans lissage.
install -m 644 "$r/xorg/xorg.conf" "$dest/etc/X11/xorg.conf"
install -m 644 "$r/xorg/joystick.conf" \
  "$dest/etc/X11/xorg.conf.d/50-joystick.conf"
install -m 644 "$r/fonts/local.conf" "$dest/etc/fonts/local.conf"

# Session : tty1 lance X, Openbox et la barre.
install -m 755 "$r/x/xinitrc" "$dest/root/.xinitrc"
install -m 644 "$r/x/menu.xml" "$dest/root/.config/openbox/menu.xml"
install -m 644 "$r/x/tint2rc" "$dest/root/.config/tint2/tint2rc"
install -m 644 "$r/x/libfm.conf" "$dest/root/.config/libfm/libfm.conf"

# rc.xml d'Alpine, avec Super+m pour le menu et sans animation.
sed \
  -e 's|</keyboard>|<keybind key="W-m"><action name="ShowMenu"><menu>root-menu</menu></action></keybind></keyboard>|' \
  -e 's|<animateIconify>yes</animateIconify>|<animateIconify>no</animateIconify>|' \
  -e 's|<drawContents>yes</drawContents>|<drawContents>no</drawContents>|' \
  "$dest/etc/xdg/openbox/rc.xml" > "$dest/root/.config/openbox/rc.xml"

# tty1 lance la session, ttyFIQ0 garde un shell sur le port serie.
sed -i \
  -e 's|^tty1::.*|tty1::respawn:/usr/bin/r36os-session|' \
  "$dest/etc/inittab"
if ! grep -q ttyFIQ0 "$dest/etc/inittab"; then
  printf 'ttyFIQ0::respawn:/sbin/getty -L 115200 ttyFIQ0 vt100\n' \
    >> "$dest/etc/inittab"
fi
if [ -f "$dest/etc/securetty" ] && ! grep -q ttyFIQ0 "$dest/etc/securetty"; then
  printf 'ttyFIQ0\n' >> "$dest/etc/securetty"
fi

install -m 644 "$r/etc/fstab" "$dest/etc/fstab"
printf 'r36os\n' > "$dest/etc/hostname"
printf '127.0.0.1 localhost r36os\n' > "$dest/etc/hosts"
ln -sfn /usr/share/zoneinfo/Europe/Paris "$dest/etc/localtime"
printf 'Europe/Paris\n' > "$dest/etc/timezone"

# Alpine range certains binaires dans /sbin, d'autres dans /usr/sbin.
present() {
  for d in sbin usr/sbin bin usr/bin; do
    if [ -x "$dest/$d/$1" ]; then
      return 0
    fi
  done
  echo "Manque $1 dans la racine." >&2
  return 1
}
for b in wpa_supplicant ntfs-3g resize2fs openbox tint2 startx python3; do
  present "$b"
done
grep -q r36os-session "$dest/etc/inittab"
grep -q root-menu "$dest/root/.config/openbox/rc.xml"
