# Coquille de démarrage r36os. Voir docs/justifications/coquille-demarrage.md

VENDOR := vendor
OUT := out
STAGE := $(OUT)/stage

IMAGE := $(VENDOR)/Image
DTB := $(VENDOR)/rk3326-r36max-type1-linux.dtb
BUSYBOX := $(VENDOR)/busybox

.PHONY: all clean cible

all: $(OUT)/uInitrd $(OUT)/boot.ini $(OUT)/Image $(OUT)/rk3326-r36max-type1-linux.dtb $(OUT)/r36os-root.ext4

$(OUT)/boot.ini: boot/boot.ini
	mkdir -p $(OUT)
	cp $< $@

$(OUT)/Image: $(IMAGE)
	mkdir -p $(OUT)
	cp $< $@

$(OUT)/rk3326-r36max-type1-linux.dtb: $(DTB) scripts/activer-emmc.py
	mkdir -p $(OUT)
	python3 scripts/activer-emmc.py $< $@
	cp $(DTB) $(OUT)/rk3326-r36max-type1-linux.dtb.sans-emmc

$(OUT)/r36os-root.ext4: rootfs/sbin/init rootfs/etc/os-release rootfs/etc/issue \
		rootfs/etc/passwd rootfs/etc/group rootfs/etc/fstab \
		$(BUSYBOX) scripts/make-rootfs.sh
	mkdir -p $(OUT)
	chmod 755 scripts/make-rootfs.sh
	fakeroot scripts/make-rootfs.sh

$(OUT)/uInitrd: rootfs/init $(BUSYBOX) scripts/pack-uinitrd.py
	rm -rf $(STAGE)
	mkdir -p $(STAGE)/bin $(STAGE)/proc $(STAGE)/sys $(STAGE)/dev
	cp rootfs/init $(STAGE)/init
	chmod 755 $(STAGE)/init
	cp $(BUSYBOX) $(STAGE)/bin/busybox
	chmod 755 $(STAGE)/bin/busybox
	ln -s busybox $(STAGE)/bin/sh
	ln -s busybox $(STAGE)/bin/mount
	ln -s busybox $(STAGE)/bin/echo
	ln -s busybox $(STAGE)/bin/uname
	ln -s busybox $(STAGE)/bin/ls
	ln -s busybox $(STAGE)/bin/cat
	ln -s busybox $(STAGE)/bin/dmesg
	ln -s busybox $(STAGE)/bin/sleep
	ln -s busybox $(STAGE)/bin/mkdir
	ln -s busybox $(STAGE)/bin/dd
	ln -s busybox $(STAGE)/bin/tr
	ln -s busybox $(STAGE)/bin/switch_root
	ln -s busybox $(STAGE)/bin/poweroff
	ln -s busybox $(STAGE)/bin/reboot
	mkdir -p $(OUT)
	( cd $(STAGE) && find . -print0 | cpio --null -o -H newc ) > $(OUT)/initramfs.cpio
	python3 scripts/pack-uinitrd.py $(OUT)/initramfs.cpio $(OUT)/uInitrd

cible:
	python3 scripts/cible.py preparer

clean:
	rm -rf $(OUT)/stage $(OUT)/root-stage $(OUT)/sandbox $(OUT)/cible \
		$(OUT)/uInitrd $(OUT)/boot.ini $(OUT)/Image $(OUT)/initramfs.cpio \
		$(OUT)/r36os-root.ext4 $(OUT)/rk3326-r36max-type1-linux.dtb \
		$(OUT)/rk3326-r36max-type1-linux.dtb.sans-emmc
