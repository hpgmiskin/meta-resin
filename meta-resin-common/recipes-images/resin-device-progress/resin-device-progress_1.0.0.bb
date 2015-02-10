DESCRIPTION = "resin device progress"
SECTION = "console/utils"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${RESIN_COREBASE}/COPYING.Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

PR = "r1.1"

SRC_URI = "file://resin-device-progress"

FILES_${PN} = "${bindir}/*"
RDEPENDS_${PN} = "bash curl"

do_install() {
	install -d ${D}${bindir}
	install -m 0775 ${WORKDIR}/resin-device-progress ${D}${bindir}/resin-device-progress
}

pkg_postinst_${PN} () {
#!/bin/sh -e
# Commands to carry out
# Remove networking
}
