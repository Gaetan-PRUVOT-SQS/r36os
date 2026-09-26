#!/usr/bin/python3
# Découpe de la puce Samsung mesurée. L'USB n'écrit pas le chargeur.
import os
import re
import sys

SECTEUR = 512
BLOC = 1024
PUCE_SECTEURS = 15269888
DEBUT = 16384
QUEUE = 2048
BOOT_OCTETS = 128 * 1024 * 1024
CHARGEUR = 64
MMC_CARTE = 1
MMC_PUCE = 0
EXT4_BLOC = 4096
EXT4_STRIDE = 128


def decoupe(secteurs, debut):
    if debut < CHARGEUR or debut > 131072:
        raise ValueError("debut")
    if debut % BLOC or secteurs % BLOC:
        raise ValueError("alignement")
    p1n = BOOT_OCTETS // SECTEUR
    if p1n % BLOC:
        raise ValueError("alignement")
    p2d = debut + p1n
    p2n = secteurs - p2d - QUEUE
    if p2n % BLOC:
        raise ValueError("alignement")
    if p2n < 1024 * 1024 * 1024 // SECTEUR:
        raise ValueError("petite")
    if p2d > 0xFFFFFFFF or p2n > 0xFFFFFFFF:
        raise ValueError("lba")
    return p1n, p2d, p2n


def le32(n):
    if n < 0 or n > 0xFFFFFFFF:
        raise ValueError("lba")
    return bytes((n & 255, (n >> 8) & 255, (n >> 16) & 255, (n >> 24) & 255))


def entree(boot, typ, debut, nombre):
    return bytes((
        0x80 if boot else 0x00,
        0xFE, 0xFF, 0xFF,
        typ,
        0xFE, 0xFF, 0xFF,
    )) + le32(debut) + le32(nombre)


def appliquer_table(secteur, secteurs, debut):
    if len(secteur) != SECTEUR:
        raise ValueError("secteur")
    p1n, p2d, p2n = decoupe(secteurs, debut)
    out = bytearray(secteur)
    out[446:510] = (
        entree(True, 0x0C, debut, p1n)
        + entree(False, 0x83, p2d, p2n)
        + bytes(32)
    )
    out[510:512] = b"\x55\xaa"
    return bytes(out), p1n, p2d, p2n


def texte_boot(mmc, source):
    if mmc not in (MMC_CARTE, MMC_PUCE):
        raise ValueError("mmc")
    if source.count("\nload mmc ") != 3 and source.count("load mmc ") != 3:
        raise ValueError("boot")
    nouveau = re.sub(
        r"load mmc \d+:",
        "load mmc %d:" % mmc,
        source,
    )
    if nouveau.count("load mmc %d:" % mmc) != 3:
        raise ValueError("boot")
    return nouveau


def controler_plage(debut, nombre, secteurs=PUCE_SECTEURS):
    if nombre <= 0 or debut < 0:
        raise ValueError("plage")
    fin = debut + nombre
    if fin > secteurs:
        raise ValueError("hors puce")
    if debut == 0 and nombre != 1:
        raise ValueError("secteur zero")
    if debut < DEBUT and fin > 1:
        raise ValueError("chargeur")
    if 0 < debut < DEBUT:
        raise ValueError("chargeur")


def controler_fichier(chemin, lba, role):
    taille = os.path.getsize(chemin)
    if taille % SECTEUR:
        raise ValueError("fichier")
    nombre = taille // SECTEUR
    p1n, p2d, p2n = decoupe(PUCE_SECTEURS, DEBUT)
    if role == "mbr":
        if lba != 0 or nombre != 1:
            raise ValueError("mbr")
    elif role == "boot":
        if lba != DEBUT or nombre != p1n:
            raise ValueError("boot")
    elif role == "racine":
        if lba != p2d or nombre < 1 or nombre > p2n:
            raise ValueError("racine")
    else:
        raise ValueError("role")
    controler_plage(lba, nombre)
    return nombre


def verifier_sauvegarde(blob):
    if len(blob) < (CHARGEUR + 1) * SECTEUR:
        raise ValueError("courte")
    secteur, p1n, p2d, p2n = appliquer_table(blob[:SECTEUR], PUCE_SECTEURS, DEBUT)
    if secteur != blob[:SECTEUR]:
        raise ValueError("table")
    if blob[CHARGEUR * SECTEUR:(CHARGEUR + 1) * SECTEUR] == b"\0" * SECTEUR:
        raise ValueError("chargeur vide")
    return p1n, p2d, p2n


def racine_du_depot():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def preparer():
    depot = racine_du_depot()
    sauvegarde = os.path.join(depot, "out", "sauvegarde-emmc-debut.bin")
    with open(sauvegarde, "rb") as f:
        blob = f.read(34 * 1024 * 1024)
    p1n, p2d, p2n = verifier_sauvegarde(blob)
    dossier = os.path.join(depot, "out", "cible")
    boot = os.path.join(dossier, "boot")
    os.makedirs(boot, exist_ok=True)
    mbr = os.path.join(dossier, "mbr.bin")
    with open(mbr, "wb") as f:
        f.write(blob[:SECTEUR])
        f.flush()
        os.fsync(f.fileno())
    source_boot = os.path.join(depot, "boot", "boot.ini")
    with open(source_boot, "r", encoding="utf-8") as f:
        carte = f.read()
    if texte_boot(MMC_CARTE, carte) != carte:
        raise SystemExit("boot.ini de la carte incoherent")
    interne = texte_boot(MMC_PUCE, carte)
    chemin_ini = os.path.join(boot, "boot.ini")
    with open(chemin_ini, "w", encoding="utf-8") as f:
        f.write(interne)
        f.flush()
        os.fsync(f.fileno())
    liens = {
        "Image": os.path.join(depot, "out", "Image"),
        "uInitrd": os.path.join(depot, "out", "uInitrd"),
        "rk3326-r36max-type1-linux.dtb": os.path.join(
            depot, "out", "rk3326-r36max-type1-linux.dtb"
        ),
    }
    for nom, src in liens.items():
        dst = os.path.join(boot, nom)
        if os.path.lexists(dst):
            os.remove(dst)
        if not os.path.isfile(src):
            raise SystemExit("manque %s" % src)
        os.link(src, dst)
    plan = os.path.join(dossier, "plan")
    lignes = [
        "mbr_lba=0",
        "mbr_secteurs=1",
        "boot_lba=%d" % DEBUT,
        "boot_secteurs=%d" % p1n,
        "racine_lba=%d" % p2d,
        "racine_secteurs=%d" % p2n,
        "queue=%d" % QUEUE,
        "mmc=%d" % MMC_PUCE,
        "chargeur=%d" % CHARGEUR,
    ]
    with open(plan, "w", encoding="utf-8") as f:
        f.write("\n".join(lignes) + "\n")
    controler_fichier(mbr, 0, "mbr")
    return dossier


def etat():
    depot = racine_du_depot()
    dossier = os.path.join(depot, "out", "cible")
    mbr = os.path.join(dossier, "mbr.bin")
    if not os.path.isfile(mbr):
        print("mbr absent. Lance: python3 scripts/cible.py preparer")
        return 1
    controler_fichier(mbr, 0, "mbr")
    with open(mbr, "rb") as f:
        got = f.read()
    sauvegarde = os.path.join(depot, "out", "sauvegarde-emmc-debut.bin")
    with open(sauvegarde, "rb") as f:
        attendu = f.read(SECTEUR)
    if got != attendu:
        print("mbr different de la sauvegarde")
        return 1
    print("mbr 512 octets, identique au secteur 0 sauvegarde")
    for nom in ("boot.img", "racine.img"):
        chemin = os.path.join(dossier, nom)
        if os.path.isfile(chemin):
            print("present %s" % nom)
        else:
            print("absent %s" % nom)
    ini = os.path.join(dossier, "boot", "boot.ini")
    if os.path.isfile(ini):
        print("boot.ini interne pret")
    return 0


def main(argv):
    if len(argv) < 2:
        print("usage: cible.py preparer|etat|controler ROLE CHEMIN LBA")
        return 1
    if argv[1] == "preparer":
        print(preparer())
        return 0
    if argv[1] == "etat":
        return etat()
    if argv[1] == "controler":
        if len(argv) != 5:
            print("usage: cible.py controler ROLE CHEMIN LBA")
            return 1
        controler_fichier(argv[3], int(argv[4]), argv[2])
        print("plage acceptee")
        return 0
    print("commande inconnue")
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except (OSError, ValueError) as exc:
        print("r36os: %s" % exc)
        sys.exit(1)
