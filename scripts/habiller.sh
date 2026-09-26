#!/bin/sh
# Pose le même bureau sur une racine déjà copiée. Carte et puce passent par ici.
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: habiller.sh RACINE DEST" >&2
  exit 1
fi

racine=$1
dest=$2

install -d "$dest/sbin" "$dest/usr/bin" "$dest/usr/lib/r36os" \
  "$dest/usr/share/lxqt" "$dest/usr/share/applications" \
  "$dest/etc/X11/xorg.conf.d" "$dest/etc/xdg/autostart" \
  "$dest/etc/fonts" "$dest/root/.config/lxqt" \
  "$dest/root/.config/pcmanfm-qt/lxqt" \
  "$dest/root/Desktop" "$dest/root/Bureau" \
  "$dest/proc" "$dest/sys" "$dest/dev" "$dest/run" "$dest/tmp" "$dest/mnt" \
  "$dest/media/jeux" "$dest/media/tf2" "$dest/var/lib/r36os"

rm -f "$dest/sbin/init" "$dest/sbin/shutdown" "$dest/sbin/poweroff" \
  "$dest/sbin/reboot" "$dest/sbin/halt"

for f in "$racine"/rootfs/sbin/*; do
  if [ -f "$f" ]; then
    install -m 755 "$f" "$dest/sbin/$(basename "$f")"
  fi
done
ln -sf poweroff "$dest/sbin/halt"

for f in "$racine"/rootfs/usr/bin/*; do
  if [ -f "$f" ]; then
    install -m 755 "$f" "$dest/usr/bin/$(basename "$f")"
  fi
done

install -m 644 "$racine/rootfs/etc/os-release" "$dest/etc/os-release"
install -m 644 "$racine/rootfs/etc/issue" "$dest/etc/issue"
install -m 644 "$racine/rootfs/etc/hosts" "$dest/etc/hosts"
install -m 644 "$racine/rootfs/lxqt/power.conf" "$dest/usr/share/lxqt/power.conf"
install -m 644 "$racine/rootfs/xorg/xorg.conf" "$dest/etc/X11/xorg.conf"
install -m 644 "$racine/rootfs/xorg/joystick.conf" \
  "$dest/etc/X11/xorg.conf.d/50-joystick.conf"
install -m 644 "$racine/rootfs/fonts/local.conf" "$dest/etc/fonts/local.conf"
install -m 644 "$racine/scripts/cible.py" "$dest/usr/lib/r36os/cible.py"
install -m 755 "$racine/rootfs/usr/lib/r36os/udhcpc.sh" \
  "$dest/usr/lib/r36os/udhcpc.sh"
install -m 755 "$racine/vendor/busybox" "$dest/usr/bin/busybox"
install -m 644 "$racine/rootfs/lxqt/panel.conf" "$dest/root/.config/lxqt/panel.conf"
install -m 644 "$racine/rootfs/lxqt/session.conf" "$dest/root/.config/lxqt/session.conf"
install -m 644 "$racine/rootfs/lxqt/lxqt.conf" "$dest/root/.config/lxqt/lxqt.conf"
install -m 644 "$racine/rootfs/lxqt/pcmanfm.conf" \
  "$dest/root/.config/pcmanfm-qt/lxqt/settings.conf"

install -m 644 "$racine/rootfs/lxqt/no-globalkeys.desktop" \
  "$dest/etc/xdg/autostart/lxqt-globalkeyshortcuts.desktop"
install -m 644 "$racine/rootfs/lxqt/no-policykit.desktop" \
  "$dest/etc/xdg/autostart/lxqt-policykit-agent.desktop"
install -m 644 "$racine/rootfs/lxqt/no-runner.desktop" \
  "$dest/etc/xdg/autostart/lxqt-runner.desktop"
install -m 644 "$racine/rootfs/lxqt/no-xscreensaver.desktop" \
  "$dest/etc/xdg/autostart/lxqt-xscreensaver-autostart.desktop"
install -m 644 "$racine/rootfs/lxqt/manette.desktop" \
  "$dest/etc/xdg/autostart/r36os-manette.desktop"
install -m 644 "$racine/rootfs/lxqt/veille.desktop" \
  "$dest/etc/xdg/autostart/r36os-veille.desktop"
install -m 644 "$racine/rootfs/lxqt/son.desktop" \
  "$dest/etc/xdg/autostart/r36os-son.desktop"
install -m 644 "$racine/rootfs/lxqt/disques.desktop" \
  "$dest/etc/xdg/autostart/r36os-disques.desktop"

for nom in installer fichiers terminal jeux wifi; do
  install -m 644 "$racine/rootfs/lxqt/$nom.desktop" \
    "$dest/usr/share/applications/r36os-$nom.desktop"
  install -m 644 "$racine/rootfs/lxqt/$nom.desktop" \
    "$dest/root/Desktop/r36os-$nom.desktop"
  install -m 644 "$racine/rootfs/lxqt/$nom.desktop" \
    "$dest/root/Bureau/r36os-$nom.desktop"
done

if [ -d "$racine/rootfs/apport" ]; then
  cp -a "$racine/rootfs/apport/." "$dest/"
fi

if [ -f "$dest/etc/xdg/openbox/rc.xml" ]; then
  sed -i \
    -e 's/<animateIconify>yes<\/animateIconify>/<animateIconify>no<\/animateIconify>/' \
    -e 's/<drawContents>yes<\/drawContents>/<drawContents>no<\/drawContents>/' \
    "$dest/etc/xdg/openbox/rc.xml"
fi

rm -f "$dest/etc/r36os-ecraser-interne"
printf 'r36os\n' > "$dest/etc/hostname"
if [ -e "$dest/usr/share/zoneinfo/Europe/Paris" ]; then
  ln -sfn /usr/share/zoneinfo/Europe/Paris "$dest/etc/localtime"
  printf 'Europe/Paris\n' > "$dest/etc/timezone"
fi
chmod 1777 "$dest/tmp"

test -x "$dest/sbin/wpa_supplicant"
test -x "$dest/bin/ntfs-3g"
test -f "$dest/lib/firmware/rtlwifi/rtl8188fufw.bin"
test -x "$dest/usr/bin/r36os-clavier"
test -x "$dest/usr/bin/r36os-disques"
