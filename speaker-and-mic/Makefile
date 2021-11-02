dtoverlay:
	dtc -I dts -O dtb -o adau7002-pcm5102a-io.dtbo adau7002-pcm5102a-io-overlay.dts

install: dtoverlay
	cp adau7002-pcm5102a-io.dtbo /boot/overlays
