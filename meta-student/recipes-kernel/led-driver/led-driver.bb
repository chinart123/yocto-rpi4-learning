SUMMARY = "Simple LED Driver for Raspberry Pi"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit module

SRC_URI = "file://led_driver.c \
           file://Makefile"

S = "${WORKDIR}"

# Dòng này đảm bảo module tương thích với kernel hiện tại
RPROVIDES_${PN} += "kernel-module-led-driver"
