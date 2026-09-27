# r36os

Alpine Linux pour la console R36 Max, avec un petit bureau X. Le dépôt garde ce qui fait marcher le matériel de la console. Alpine fournit tout le reste.

Le PC écrit le système sur la puce interne par le port OTG. La partition des jeux n'est pas effacée.

## Matériel visé

Console R36 Max, puce Rockchip RK3326.

- Environ 1 Go de mémoire vive.
- Écran carré de 720 x 720 (modèle Type 1), dessiné par le processeur en framebuffer. Le Mali reste éteint : sur ce noyau 4.4, l'activer a déjà donné un écran noir.
- Puce interne Samsung d'environ 8 Go (15 269 888 secteurs de 512 octets). Le chargeur Rockchip est au secteur 64, on ne l'écrase pas.
- Manette `odroidgo3-joypad`, batterie et son sur le RK817, wifi USB Realtek 8188fu, rétroéclairage PWM.
- Pas de clavier physique.

## Ce que fait chaque morceau

| Morceau | Rôle |
| --- | --- |
| `vendor/Image`, dtb Type 1 | Noyau fournisseur 4.4, le seul qui fait marcher écran, manette et RK817 |
| `vendor/busybox` | Outils de l'initramfs |
| `vendor/rk3326_loader_v2.12.140.bin` | Chargeur envoyé par l'OTG si la console ne répond pas |
| `boot/boot.ini` | Charge noyau, initramfs et dtb |
| `scripts/activer-emmc.py` | Ouvre `dwmmc@ff390000` dans le dtb, sinon le noyau ne voit pas la puce |
| `scripts/pack-uinitrd.py` | Met l'initramfs au format attendu par le chargeur |
| `rootfs/init` | Initramfs : trouve la racine étiquetée `r36os`, puis passe la main à Alpine |
| `scripts/cible.py`, `ecrire-puce.sh` | Découpe de la puce et écriture par l'OTG |
| `rootfs/usr/bin/r36os-*` | Manette en souris, son, lumière, batterie, wifi, cartes, clavier à l'écran |
| `rootfs/local.d/` | Réglages du RK3326 au démarrage, démontage des cartes à l'arrêt |
| `rootfs/xorg/`, `rootfs/fonts/` | X en fbdev 24 bits, manette ignorée par X, polices sans lissage |
| `rootfs/firmware/` | Microprogramme du wifi 8188fu |
| `rootfs/x/` | Session : Openbox, barre tint2, menu |

## Construire

Il faut `qemu-aarch64-static` (paquet `qemu-user-static`), `curl`, `rsync`, `mkfs.vfat` et `mkfs.ext4` sur le PC.

```sh
sudo scripts/construire-alpine.sh
make
sudo scripts/assembler-cible.sh
```

`construire-alpine.sh` télécharge le minirootfs Alpine aarch64, vérifie son sha256 avec `latest-releases.yaml`, puis installe les paquets dans `alpine-root/`. La branche par défaut est `v3.22`, on la change avec `ALPINE_BRANCHE=v3.xx`.

`make` produit dans `out/` le `boot.ini`, le noyau, le dtb activé pour la puce et l'initramfs `uInitrd`.

`assembler-cible.sh` fabrique `out/cible/boot.img` (FAT32, 128 Mo) et `out/cible/racine.img` (ext4 étiquetée `r36os`). La couche matériel est posée par `scripts/habiller.sh`.

## Écrire la puce par l'OTG

Console éteinte, branchée par son port OTG, elle apparaît en USB `2207:330d`. L'outil est `/usr/local/bin/rkdeveloptool`.

```sh
sudo scripts/ecrire-puce.sh
sudo scripts/ecrire-puce.sh --ecrire
```

Sans `--ecrire`, le script vérifie les images et ne parle pas à la console. Avec `--ecrire`, il sélectionne la puce interne (`cs 1`) et envoie trois plages : le secteur 0, `BOOT` au secteur 16384 et la racine au secteur 278528. Le chargeur du secteur 64 n'est jamais envoyé.

La sauvegarde des 32 premiers Mo de la puce est dans `out/sauvegarde-emmc-debut.bin`. Il ne faut pas la supprimer : `cible.py` s'en sert pour le secteur 0.

Au premier démarrage, `resize2fs` agrandit la racine à toute la partition.

## Sur la console

Alpine démarre avec OpenRC. Le service `local` lance `perf.start` (gouverneur `performance`, `deadline`, zram de 256 Mo) et `r36os.start` (agrandissement au premier démarrage, cartes, lumière).

`inittab` lance `r36os-session` sur tty1, qui démarre X, Openbox et la barre. Si X s'arrête, on tombe sur un shell et `exit` relance le bureau. Un shell reste aussi sur le port série `ttyFIQ0`.

| Touche | Effet |
| --- | --- |
| Croix et stick gauche | Déplacent le curseur |
| A | Clic gauche |
| B | Clic droit |
| X | Menu Openbox |
| Y | Ouvre `/media/jeux` |
| Start | Terminal |
| L et R | Lumière |
| Select | Coupe ou remet le son |

La barre contient Menu, ABC (clavier à l'écran), les fenêtres, la lumière, le son, la batterie et l'heure. Un clic gauche sur la lumière ou le son monte, un clic droit baisse.

La partition `EASYROMS` est montée dans `/media/jeux` avec `ntfs-3g`. À l'arrêt, `r36os.stop` la démonte et attend que `ntfs-3g` ait fini d'écrire, avant que OpenRC remonte la racine en lecture seule.

Le wifi se règle avec Wifi dans le menu. Le mot de passe ne s'affiche pas pendant la saisie.

## Licences

Les scripts, les fichiers de réglage et ce README sont sous licence Apache 2.0, texte dans `LICENSE`.

| Morceau | Origine |
| --- | --- |
| `vendor/Image`, dtb | Noyau fournisseur 4.4, licence du noyau Linux |
| `vendor/busybox` | BusyBox, GPL |
| `vendor/rk3326_loader_v2.12.140.bin` | Chargeur Rockchip |
| `rootfs/firmware/rtl8188fufw.bin` | linux-firmware |

La racine construite par `construire-alpine.sh` est une Alpine Linux. Chaque paquet garde la licence indiquée par Alpine.
