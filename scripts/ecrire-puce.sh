#!/bin/sh
# Ecrit la puce par l'OTG. Sans --ecrire, n'ouvre pas la console.
set -eu

racine=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
outil=/usr/local/bin/rkdeveloptool
chargeur=$racine/vendor/rk3326_loader_v2.12.140.bin
dossier=$racine/out/cible
mbr=$dossier/mbr.bin
boot=$dossier/boot.img
image=$dossier/racine.img

python3 "$racine/scripts/cible.py" etat

if [ "${1:-}" != "--ecrire" ]; then
  echo "OTG pret. La puce n'est pas ecrite."
  echo "sudo scripts/ecrire-puce.sh --ecrire"
  exit 0
fi

if [ ! -x "$outil" ] || [ ! -f "$chargeur" ]; then
  echo "Outil ou chargeur absent." >&2
  exit 1
fi
if [ ! -f "$boot" ] || [ ! -f "$image" ]; then
  echo "boot.img ou racine.img absent. On n'ecrit pas une racine incomplete." >&2
  exit 1
fi

python3 "$racine/scripts/cible.py" controler mbr "$mbr" 0
python3 "$racine/scripts/cible.py" controler boot "$boot" 16384
python3 "$racine/scripts/cible.py" controler racine "$image" 278528

ports=
for noeud in /sys/bus/usb/devices/[0-9]*; do
  [ -f "$noeud/idVendor" ] || continue
  [ -f "$noeud/idProduct" ] || continue
  vendeur=$(cat "$noeud/idVendor")
  produit=$(cat "$noeud/idProduct")
  if [ "$vendeur" = "2207" ] && [ "$produit" = "330d" ]; then
    ports="$ports $noeud"
  fi
done
ports=$(echo "$ports" | awk '{$1=$1};1')
nombre=$(printf '%s\n' "$ports" | awk 'NF{c++} END{print c+0}')
if [ "$nombre" != "1" ]; then
  echo "Console OTG introuvable. Branche le port, mode chargeur 2207:330d." >&2
  exit 1
fi

export DISPLAY="${DISPLAY:-:0}"
export SUDO_ASKPASS="$racine/scripts/askpass-puce.sh"
cat > "$SUDO_ASKPASS" << 'EOF'
#!/bin/sh
export DISPLAY="${DISPLAY:-:0}"
zenity --password --title="Ecrire la puce r36os"
EOF
chmod 700 "$SUDO_ASKPASS"
trap 'rm -f "$SUDO_ASKPASS"' EXIT

attendre_rfi() {
  i=0
  while [ "$i" -lt 20 ]; do
    if "$outil" rfi >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

if ! attendre_rfi; then
  "$outil" db "$chargeur"
  if ! attendre_rfi; then
    sudo -A sh -c 'echo 0 > "$1/authorized"' sh "$ports"
    sleep 1
    sudo -A sh -c 'echo 1 > "$1/authorized"' sh "$ports"
    sleep 1
    "$outil" db "$chargeur"
    if ! attendre_rfi; then
      echo "La console ne repond pas sur l'OTG." >&2
      exit 1
    fi
  fi
fi
stockage=$("$outil" cs 1 2>&1) || {
  echo "Le chargeur n'a pas selectionne la puce interne." >&2
  printf '%s\n' "$stockage" >&2
  exit 1
}
case $stockage in
  *failed*|*Failed*)
    echo "Le chargeur n'a pas selectionne la puce interne." >&2
    printf '%s\n' "$stockage" >&2
    exit 1
    ;;
esac
"$outil" wl 0 "$mbr"
"$outil" wl 16384 "$boot"
"$outil" wl 278528 "$image"
if ! "$outil" rd; then
  echo "Ecriture terminee. La console n'a pas redemarre toute seule."
fi
echo "Puce ecrite. Le chargeur du secteur 64 n'a pas ete envoye."
