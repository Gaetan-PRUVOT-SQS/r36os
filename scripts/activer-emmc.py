#!/usr/bin/python3
# Active le contrôleur eMMC du dtb Type 1. Le chargeur de la puce n'est pas touché.
import struct
import sys

DEBUT = 1
FIN = 2
PROP = 3
TERM = 9


def align(n):
    return (n + 3) & ~3


def lire(chemin):
    data = open(chemin, "rb").read()
    if data[:4] != b"\xd0\r\xfe\xed":
        raise SystemExit("dtb illisible")
    champs = struct.unpack(">IIIIIIIII I", data[:40])
    off_struct, off_strings = champs[2], champs[3]
    size_strings, size_struct = champs[8], champs[9]
    chaines = data[off_strings:off_strings + size_strings]

    def nom(off):
        fin = chaines.index(b"\0", off)
        return chaines[off:fin].decode()

    p = off_struct
    pile = []
    courant = []
    arbre = []
    while p < off_struct + size_struct:
        p = align(p)
        tok = struct.unpack(">I", data[p:p + 4])[0]
        p += 4
        if tok == DEBUT:
            fin = data.index(b"\0", p)
            titre = data[p:fin].decode()
            p = align(fin + 1)
            noeud = [titre, []]
            if courant:
                courant[-1][1].append(noeud)
            else:
                arbre.append(noeud)
            courant.append(noeud)
            pile.append(titre)
        elif tok == FIN:
            courant.pop()
            pile.pop()
        elif tok == PROP:
            longueur, off = struct.unpack(">II", data[p:p + 8])
            p += 8
            valeur = data[p:p + longueur]
            p += longueur
            courant[-1][1].append((nom(off), valeur))
        elif tok == TERM:
            break
        elif tok != 4:
            raise SystemExit("jeton dtb inconnu")
    return arbre


def u32(n):
    return struct.pack(">I", n)


def activer(noeuds):
    for titre, corps in noeuds:
        if titre == "dwmmc@ff390000":
            props = {}
            for entree in corps:
                if isinstance(entree, tuple):
                    props[entree[0]] = entree[1]
            props["status"] = b"okay\0"
            props["bus-width"] = u32(8)
            props["non-removable"] = b""
            props["no-sd"] = b""
            props["no-sdio"] = b""
            props["cap-mmc-highspeed"] = b""
            props["pinctrl-names"] = b"default\0"
            props["pinctrl-0"] = u32(310) + u32(311) + u32(316)
            corps[:] = list(props.items())
            return True
        enfants = [entree for entree in corps if isinstance(entree, list)]
        if enfants and activer(enfants):
            return True
    return False


def ecrire(arbre, chemin):
    chaines = {}
    blob = bytearray()

    def off_nom(texte):
        if texte not in chaines:
            chaines[texte] = sum(len(c) + 1 for c in chaines)
        return chaines[texte]

    def poser(noeuds):
        for titre, corps in noeuds:
            blob.extend(u32(DEBUT))
            brut = titre.encode() + b"\0"
            blob.extend(brut)
            blob.extend(b"\0" * (align(len(blob)) - len(blob)))
            for entree in corps:
                if isinstance(entree, list):
                    poser([entree])
                    continue
                cle, valeur = entree
                blob.extend(u32(PROP))
                blob.extend(u32(len(valeur)))
                blob.extend(u32(off_nom(cle)))
                blob.extend(valeur)
                blob.extend(b"\0" * (align(len(blob)) - len(blob)))
            blob.extend(u32(FIN))

    poser(arbre)
    blob.extend(u32(TERM))
    table = bytearray()
    for texte in chaines:
        table.extend(texte.encode() + b"\0")
    reserve = b"\0" * 16
    entete = 40
    off_struct = entete + len(reserve)
    off_strings = off_struct + len(blob)
    fichier = bytearray(off_strings + len(table))
    struct.pack_into(
        ">IIIIIIIII I",
        fichier,
        0,
        0xD00DFEED,
        len(fichier),
        off_struct,
        off_strings,
        entete,
        17,
        16,
        0,
        len(table),
        len(blob),
    )
    fichier[entete:off_struct] = reserve
    fichier[off_struct:off_strings] = blob
    fichier[off_strings:] = table
    open(chemin, "wb").write(fichier)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: activer-emmc.py source.dtb sortie.dtb")
    arbre = lire(sys.argv[1])
    if not activer(arbre):
        raise SystemExit("contrôleur eMMC absent du dtb")
    ecrire(arbre, sys.argv[2])


if __name__ == "__main__":
    main()
