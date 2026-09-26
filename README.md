# r36os

Système Linux pour la console R36 Max. La version dans l'arbre est la 0.9.

Le PC écrit le système sur la puce interne par le port OTG. La console est alors en mode chargeur, pas sous Linux. La carte microSD ne sert plus à poser le système. La partition des jeux n'est pas effacée.

Le texte, les scripts et les réglages écrits pour r36os sont sous licence Apache 2.0. Le noyau, BusyBox, le chargeur Rockchip, les paquets Debian et le microprogramme wifi gardent leur propre licence. Le détail est plus bas.

## Matériel visé

Console R36 Max, puce Rockchip RK3326.

- Environ 1 Go de mémoire vive.
- Écran carré d'environ 4 pouces. Le modèle Type 1 fait 720 x 720. L'image est dessinée par le processeur, en framebuffer. Le Mali est dans le noyau et reste éteint : sur ce noyau 4.4, l'activer a déjà donné un écran noir.
- Puce interne Samsung d'environ 8 Go (7456 Mo, 15 269 888 secteurs de 512 octets). Le chargeur Rockchip est au secteur 64. On ne l'écrase pas.
- TF1 et TF2 restent les lecteurs de cartes. La grosse carte garde `EASYROMS` pour les jeux. Le système, lui, est écrit sur la puce par l'OTG.
- Manette `odroidgo3-joypad`, batterie et son sur le RK817, wifi USB Realtek 8188fu, rétroéclairage PWM.
- Pas de clavier physique.

Le PC qui écrit le système parle au port OTG (`2207:330d`). Il ne formate pas la carte, et le SSD du PC n'est pas une cible.

## Cible mesurée

Les chiffres viennent de la puce lue le 2026-09-25. Ils sont dans `scripts/cible.py`.

Samsung, 15 269 888 secteurs de 512 octets, soit 7456 Mo. La page fait 2 Ko. Le bloc d'effacement fait 512 Ko, donc 1024 secteurs. `BOOT` et la racine commencent sur un de ces blocs.

| Zone | Secteur de départ | Taille | Contenu |
| --- | --- | --- | --- |
| Table DOS | 0 | 1 secteur, 512 octets | Recopiée depuis la sauvegarde des 32 premiers Mo |
| Chargeur Rockchip | 64 | dans les 8 premiers Mo | Déjà sur la puce. L'OTG ne l'envoie pas |
| Zone interdite | 1 à 16383 | | Un fichier qui déborde ici est refusé |
| `BOOT` | 16384 | 128 Mo, 262144 secteurs | FAT32, clusters de 2 Ko. `boot.ini` charge `mmc 0` |
| Racine | 278528 | 14 989 312 secteurs | ext4, blocs de 4 Ko, stride 128, étiquette `r36os` |
| Fin de puce | après la racine | 2048 secteurs | Laissés vides |

`racine.img` fait la taille du système plus 512 Mo. Au premier démarrage, `resize2fs` l'étend à toute la partition. Le dtb ouvre `dwmmc@ff390000` en largeur 8, sans HS200. Sans ça, le noyau ne voit pas la puce.

L'écriture OTG envoie trois fichiers, après `cs 1` : le secteur 0, le secteur 16384, le secteur 278528.

## Bureau

X tourne avec le pilote `fbdev`, profondeur 24, `ShadowFB`. La profondeur 16 ne peint que la moitié gauche. La profondeur 32 est refusée.

La barre du bas contient le menu, Installer, ABC, les fenêtres, le volume, la lumière, la batterie et le bureau.

La manette sert de souris.

| Touche | Effet |
| --- | --- |
| Croix et stick gauche | Déplacent le curseur |
| A | Clic gauche |
| B | Clic droit |
| X | Ouvre le menu, en bas à gauche |
| Y | Ouvre `/media/jeux` |
| Start | Ouvre le terminal |
| L et R | Baisse et monte la lumière |
| Select | Coupe ou remet le son |
| ABC dans la barre | Clavier à l'écran |

Un seul clic ouvre un fichier. Les lettres sont à 120 dpi, sans lissage : lisser chaque glyphe coûte trop cher quand le processeur peint l'écran. Le fond du bureau est une couleur unie. L'écran s'éteint après 180 secondes. La batterie s'affiche toutes les 20 secondes, avec un `+` pendant la charge.

La lumière part à 70 % au premier allumage, puis le niveau choisi est gardé. Le son passe par Alsa sur le codec RK817. PulseAudio n'est pas lancé.

L'icône Wifi ouvre un terminal. On tape le nom du réseau et le mot de passe avec le clavier ABC. `wpa_supplicant` associe la puce 8188fu, puis busybox prend le bail. Le fichier `rtl8188fufw.bin` est fourni avec les sources.

La partition dont l'étiquette est `EASYROMS` est montée dans `/media/jeux` avec `ntfs-3g`. Une autre partition de carte (FAT, NTFS ou exFAT), qui n'est ni la racine ni `BOOT`, va dans `/media/tf2` s'il en reste une. L'horloge est sur `Europe/Paris`.

Au démarrage, `/sbin/perf` laisse les cœurs sur le gouverneur `performance`, l'ordonnanceur `deadline` sur les cartes mémoire, `noatime`, et 256 Mo de zram en `lzo` si le noyau l'expose. Les pages mémoire transparentes sont coupées. `/tmp` est un tmpfs de 64 Mo. Le lanceur clavier global, l'agent PolicyKit et XScreenSaver sont masqués : ils plantaient ou tournaient pour rien sur cette machine.

## Démarrage

`boot/boot.ini` de la puce charge le noyau, l'initramfs et le dtb depuis `mmc 0:1`. Le fichier de la carte, s'il sert encore, charge `mmc 1:1`.

`rootfs/init` lit l'étiquette ext4 à l'octet 1144.

- Si la carte et la puce portent toutes les deux `r36os`, la carte gagne quand son disque dépasse 10 Go.
- Sinon la puce `r36os` est montée.
- Sinon une partition `live` est montée.
- Si rien ne convient, l'init s'arrête sur un shell avec `r36os: racine introuvable`.

La copie du dtb sans l'activation de la puce est gardée sous le nom `rk3326-r36max-type1-linux.dtb.sans-emmc`. Si l'écran devient noir après un essai, on remet ce fichier à la place du dtb de `BOOT`, depuis le PC.

`r36os-installer` et `copier-emmc` restent dans l'arbre. Ce n'est plus le chemin pour écrire le système. L'écriture se fait par l'OTG, sur la découpe du tableau ci-dessus.

## Arborescence

| Dossier | Rôle |
| --- | --- |
| `boot/` | `boot.ini` de la carte |
| `rootfs/` | Init, bureau, scripts du poste, réglages LXQt et X |
| `rootfs/apport/` | Binaires ajoutés au bureau : wifi, NTFS, microprogramme |
| `scripts/` | Construction de la racine et image de la puce |
| `vendor/` | Noyau, dtb Type 1, BusyBox, chargeur RK3326 |
| `debian-root/` | Racine Debian arm64. Absente du dépôt |
| `out/` | Fichiers construits. Absents du dépôt |

`scripts/habiller.sh` pose le même bureau sur la carte et sur l'image de la puce. Les deux chemins appellent ce script, pour ne pas diverger.

## Ce qui reste sur le PC

`debian-root/` pèse environ 900 Mo et contient un fichier de plus de 100 Mo. GitHub refuse ce fichier. `out/` contient les images, dont une racine de plus de 2 Go. Les deux sont dans `.gitignore`.

Il faut donc reconstruire la racine Debian une fois, en root, avec `debootstrap`, `qemu-aarch64-static` et un accès au miroir Debian :

```sh
sudo scripts/construire-bureau.sh
```

Le script part de Debian bookworm arm64 et installe LXQt, Openbox, pcmanfm-qt, qterminal, X en framebuffer, dbus et les polices DejaVu. La locale générée est `fr_FR.UTF-8`.

Ensuite :

```sh
make
```

`make` produit dans `out/` le `boot.ini`, le noyau, le dtb activé pour la puce, l'initramfs `uInitrd` et une petite racine ext4 de secours. Le bureau complet, lui, vient de `debian-root` plus `rootfs`, au moment de `assembler-cible.sh`.

## Écrire la puce par l'OTG

La console éteinte, branchée par son port OTG, apparaît en USB `2207:330d`. Ce n'est pas un shell Linux. L'outil est `/usr/local/bin/rkdeveloptool`.

Les images du 2026-09-25 sont déjà dans `out/cible/` : `mbr.bin`, `boot.img` (128 Mo) et `racine.img`. On les reconstruit seulement si le bureau a changé.

```sh
sudo scripts/assembler-cible.sh
sudo scripts/ecrire-puce.sh
sudo scripts/ecrire-puce.sh --ecrire
```

Sans `--ecrire`, le script ne parle pas à la console. Avec `--ecrire`, il attend que le chargeur réponde, sélectionne la puce interne (`cs 1`), puis envoie les trois plages du tableau. Le chargeur du secteur 64 n'est pas dans ces morceaux. Une carte laissée dans un lecteur n'est pas la cible.

La première racine construite ainsi est plus petite que la partition. Au premier démarrage, `resize2fs` l'agrandit. On retire la carte système de TF1 et on allume.

`scripts/poser.sh` ne formate plus la carte. L'ancien geste reste `sudo scripts/poser.sh --carte`.

## Licences

Les scripts, les fichiers de réglage et ce README sont distribués sous la licence Apache 2.0. Le texte est dans `LICENSE`.

D'autres morceaux sont seulement transportés, et ils gardent leur licence :

| Morceau | Origine |
| --- | --- |
| `vendor/Image`, dtb, initramfs d'origine | Noyau fournisseur 4.4, licence du noyau Linux |
| `vendor/busybox` | BusyBox, GPL |
| `vendor/rk3326_loader_v2.12.140.bin` | Chargeur Rockchip |
| `rootfs/apport/` (`wpa_supplicant`, `ntfs-3g`, bibliothèques) | Debian bookworm arm64 |
| `rtl8188fufw.bin` | linux-firmware |

La racine Debian construite par `construire-bureau.sh` est un système Debian. Chaque paquet garde la licence indiquée par Debian.
