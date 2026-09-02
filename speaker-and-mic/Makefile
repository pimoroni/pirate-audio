OVERLAY_DIR := $(firstword $(wildcard /boot/firmware/overlays /boot/overlays))

dtoverlay:
	dtc -I dts -O dtb -o adau7002-pcm5102a-io.dtbo adau7002-pcm5102a-io-overlay.dts

install: dtoverlay
	test -n "$(OVERLAY_DIR)" || { echo "Could not find an overlays directory"; exit 1; }
	install -m 644 adau7002-pcm5102a-io.dtbo $(OVERLAY_DIR)

.PHONY: dtoverlay install
