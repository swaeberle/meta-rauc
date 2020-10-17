# Class for creating rauc bundles
#
# Description:
# 
# You have to set the slot images in your recipe file following this example:
#
#   RAUC_BUNDLE_COMPATIBLE ?= "My Super Product"
#   RAUC_BUNDLE_VERSION ?= "v2015-06-07-1"
#
#   SRC_URI += "hook.sh"
#
#   RAUC_BUNDLE_HOOKS[file] ?= "hook.sh"
#   RAUC_BUNDLE_HOOKS[hooks] ?= "install-check"
#
#   RAUC_BUNDLE_SLOTS ?= "rootfs kernel dtb bootloader"
#   
#   RAUC_SLOT_rootfs ?= "core-image-minimal"
#   RAUC_SLOT_rootfs[fstype] = "ext4"
#   RAUC_SLOT_rootfs[hooks] ?= "install;post-install"
#   
#   RAUC_SLOT_kernel ?= "linux-yocto"
#   RAUC_SLOT_kernel[type] ?= "kernel"
#   
#   RAUC_SLOT_bootloader ?= "barebox"
#   RAUC_SLOT_bootloader[type] ?= "boot"
#   RAUC_SLOT_bootloader[file] ?= "barebox.img"
#
#   RAUC_SLOT_dtb ?= linux-yocto
#   RAUC_SLOT_dtb[type] ?= "file"
#   RAUC_SLOT_dtb[file] ?= "${MACHINE}.dtb"
#
# To use a different image name, e.g. for variants
#   RAUC_SLOT_dtb ?= linux-yocto
#   RAUC_SLOT_dtb[name] ?= "dtb.my,compatible"
#   RAUC_SLOT_dtb[type] ?= "file"
#   RAUC_SLOT_dtb[file] ?= "${MACHINE}-variant1.dtb"
#
# To override the file name used in the bundle use 'rename'
#   RAUC_SLOT_rootfs ?= "core-image-minimal"
#   RAUC_SLOT_rootfs[rename] ?= "rootfs.ext4"
#
# To add additional artifacts to the bundle you can use RAUC_BUNDLE_EXTRA_FILES
# and RAUC_BUNDLE_EXTRA_DEPENDS.
# For files from the WORKDIR (fetched using SRC_URI) you can write:
#
#   SRC_URI += "file://myfile"
#   RAUC_BUNDLE_EXTRA_FILES += "myfile"
#
# For files from the DEPLOY_DIR_IMAGE (generated by another recipe) you can write:
#
#   RAUC_BUNDLE_EXTRA_DEPENDS += "myfile-recipe-pn"
#   RAUC_BUNDLE_EXTRA_FILES += "myfile.img"
#
# Extra arguments may be passed to the bundle command with BUNDLE_ARGS eg:
#   BUNDLE_ARGS += ' --mksquashfs-args="-comp zstd -Xcompression-level 22" '
#
# Likewise, extra arguments can be passed to the convert command with
# CONVERT_ARGS.
#
# Additionally you need to provide a certificate and a key file
#
#   RAUC_KEY_FILE ?= "development-1.key.pem"
#   RAUC_CERT_FILE ?= "development-1.cert.pem"
#
# For bundle signature verification a keyring file must be provided
#
#   RAUC_KEYRING_FILE ?= "ca.cert.pem"
#
# Enable building casync bundles with
#
#   RAUC_CASYNC_BUNDLE = "1"

LICENSE = "MIT"

PACKAGE_ARCH = "${MACHINE_ARCH}"

PACKAGES = ""
INHIBIT_DEFAULT_DEPS = "1"

RAUC_IMAGE_FSTYPE ??= "${@(d.getVar('IMAGE_FSTYPES') or "").split()[0]}"
RAUC_IMAGE_FSTYPE[doc] = "Specifies the default file name extension to expect for collecting image artifacts. Defaults to first element set in IMAGE_FSTYPES."

do_fetch[cleandirs] = "${S}"
do_patch[noexec] = "1"
do_compile[noexec] = "1"
do_install[noexec] = "1"
do_populate_sysroot[noexec] = "1"
do_package[noexec] = "1"
do_package_qa[noexec] = "1"
do_packagedata[noexec] = "1"
deltask do_package_write_ipk
deltask do_package_write_deb
deltask do_package_write_rpm

RAUC_BUNDLE_COMPATIBLE  ??= "${MACHINE}-${TARGET_VENDOR}"
RAUC_BUNDLE_VERSION     ??= "${PV}"
RAUC_BUNDLE_DESCRIPTION ??= "${SUMMARY}"
RAUC_BUNDLE_BUILD       ??= "${DATETIME}"
RAUC_BUNDLE_BUILD[vardepsexclude] = "DATETIME"
RAUC_BUNDLE_COMPATIBLE[doc] = "Specifies the mandatory bundle compatible string. See RAUC documentation for more details."
RAUC_BUNDLE_VERSION[doc] = "Specifies the bundle version string. See RAUC documentation for more details."
RAUC_BUNDLE_DESCRIPTION[doc] = "Specifies the bundle description string. See RAUC documentation for more details."
RAUC_BUNDLE_BUILD[doc] = "Specifies the bundle build stamp. See RAUC documentation for more details."

RAUC_BUNDLE_SLOTS[doc] = "Space-separated list of slot classes to include in bundle (manifest)"
RAUC_BUNDLE_HOOKS[doc] = "Allows to specify an additional hook executable and bundle hooks (via varflags '[file'] and ['hooks'])"

RAUC_BUNDLE_EXTRA_FILES[doc] = "Specifies list of additional files to add to bundle. Files must either be located in WORKDIR (added by SRC_URI) or DEPLOY_DIR_IMAGE (assured by RAUC_BUNDLE_EXTRA_DEPENDS)"
RAUC_BUNDLE_EXTRA_DEPENDS[doc] = "Specifies list of recipes that create artifacts in DEPLOY_DIR_IMAGE. For recipes not depending on do_deploy task also <recipename>:do_<taskname> notation is supported"

RAUC_CASYNC_BUNDLE ??= "0"

# Create dependency list from images
python __anonymous() {
    d.appendVarFlag('do_unpack', 'vardeps', ' RAUC_BUNDLE_HOOKS')
    for slot in (d.getVar('RAUC_BUNDLE_SLOTS') or "").split():
        slotflags = d.getVarFlags('RAUC_SLOT_%s' % slot)
        imgtype = slotflags.get('type') if slotflags else None
        if not imgtype:
            bb.debug(1, "No [type] given for slot '%s', defaulting to 'image'" % slot)
            imgtype = 'image'
        image = d.getVar('RAUC_SLOT_%s' % slot)

        if not image:
            bb.error("No image set for slot '%s'. Specify via 'RAUC_SLOT_%s = \"<recipe-name>\"'" % (slot, slot))
            return

        d.appendVarFlag('do_unpack', 'vardeps', ' RAUC_SLOT_%s' % slot)
        depends = slotflags.get('depends') if slotflags else None
        if depends:
            d.appendVarFlag('do_unpack', 'depends', ' ' + depends)
            continue

        if imgtype == 'image':
            d.appendVarFlag('do_unpack', 'depends', ' ' + image + ':do_image_complete')
        else:
            d.appendVarFlag('do_unpack', 'depends', ' ' + image + ':do_deploy')

    for image in (d.getVar('RAUC_BUNDLE_EXTRA_DEPENDS') or "").split():
        imagewithdep = image.split(':')
        deptask = imagewithdep[1] if len(imagewithdep) > 1 else 'do_deploy'
        d.appendVarFlag('do_unpack', 'depends', ' %s:%s' % (image, deptask))
        bb.note('adding extra dependency %s:%s' % (image,  deptask))
}

S = "${WORKDIR}"
B = "${WORKDIR}/build"
BUNDLE_DIR = "${S}/bundle"

RAUC_KEY_FILE ??= ""
RAUC_KEY_FILE[doc] = "Specifies the path to the RAUC key file used for signing. Use COREBASE to reference files located in any shared BSP folder."
RAUC_CERT_FILE ??= ""
RAUC_CERT_FILE[doc] = "Specifies the path to the RAUC cert file used for signing. Use COREBASE to reference files located in any shared BSP folder."
RAUC_KEYRING_FILE ??= ""
RAUC_KEYRING_FILE[doc] = "Specifies the path to the RAUC keyring file used for bundle signature verification. Use COREBASE to reference files located in any shared BSP folder."
BUNDLE_ARGS ??= ""
BUNDLE_ARGS[doc] = "Specifies any extra arguments to pass to the rauc bundle command."
CONVERT_ARGS ??= ""
CONVERT_ARGS[doc] = "Specifies any extra arguments to pass to the rauc convert command."


DEPENDS = "rauc-native squashfs-tools-native"
DEPENDS += "${@bb.utils.contains('RAUC_CASYNC_BUNDLE', '1', 'virtual/fakeroot-native casync-native', '', d)}"

def write_manifest(d):
    import shutil

    machine = d.getVar('MACHINE')
    bundle_path = d.expand("${BUNDLE_DIR}")

    bb.utils.mkdirhier(bundle_path)
    try:
        manifest = open('%s/manifest.raucm' % bundle_path, 'w')
    except OSError:
        raise bb.build.FuncFailed('Unable to open manifest.raucm')

    manifest.write('[update]\n')
    manifest.write(d.expand('compatible=${RAUC_BUNDLE_COMPATIBLE}\n'))
    manifest.write(d.expand('version=${RAUC_BUNDLE_VERSION}\n'))
    manifest.write(d.expand('description=${RAUC_BUNDLE_DESCRIPTION}\n'))
    manifest.write(d.expand('build=${RAUC_BUNDLE_BUILD}\n'))
    manifest.write('\n')

    hooksflags = d.getVarFlags('RAUC_BUNDLE_HOOKS')
    have_hookfile = False
    if 'file' in hooksflags:
        have_hookfile = True
        manifest.write('[hooks]\n')
        manifest.write("filename=%s\n" % hooksflags.get('file'))
        if 'hooks' in hooksflags:
            manifest.write("hooks=%s\n" % hooksflags.get('hooks'))
        manifest.write('\n')
    elif 'hooks' in hooksflags:
        bb.warn("Suspicious use of RAUC_BUNDLE_HOOKS[hooks] without RAUC_BUNDLE_HOOKS[file]")

    for slot in (d.getVar('RAUC_BUNDLE_SLOTS') or "").split():
        slotflags = d.getVarFlags('RAUC_SLOT_%s' % slot)
        if slotflags and 'name' in slotflags:
            slotname = slotflags.get('name')
        else:
            slotname = slot
        manifest.write('[image.%s]\n' % slotname)
        if slotflags and 'type' in slotflags:
            imgtype = slotflags.get('type')
        else:
            imgtype = 'image'

        if slotflags and 'fstype' in slotflags:
            img_fstype = slotflags.get('fstype')
        else:
            img_fstype = d.getVar('RAUC_IMAGE_FSTYPE')

        if imgtype == 'image':
            if slotflags and 'file' in slotflags:
                imgsource = d.getVarFlag('RAUC_SLOT_%s' % slot, 'file')
            else:
                imgsource = "%s-%s.%s" % (d.getVar('RAUC_SLOT_%s' % slot), machine, img_fstype)
            imgname = imgsource
        elif imgtype == 'kernel':
            # TODO: Add image type support
            if slotflags and 'file' in slotflags:
                imgsource = d.getVarFlag('RAUC_SLOT_%s' % slot, 'file')
            else:
                imgsource = "%s-%s.bin" % ("zImage", machine)
            imgname = "%s.%s" % (imgsource, "img")
        elif imgtype == 'boot':
            if slotflags and 'file' in slotflags:
                imgsource = d.getVarFlag('RAUC_SLOT_%s' % slot, 'file')
            else:
                imgsource = "%s" % ("barebox.img")
            imgname = imgsource
        elif imgtype == 'file':
            if slotflags and 'file' in slotflags:
                imgsource = d.getVarFlag('RAUC_SLOT_%s' % slot, 'file')
            else:
                raise bb.build.FuncFailed('Unknown file for slot: %s' % slot)
            imgname = "%s.%s" % (imgsource, "img")
        else:
            raise bb.build.FuncFailed('Unknown image type: %s' % imgtype)

        if slotflags and 'rename' in slotflags:
            imgname = d.getVarFlag('RAUC_SLOT_%s' % slot, 'rename')

        manifest.write("filename=%s\n" % imgname)
        if slotflags and 'hooks' in slotflags:
            if not have_hookfile:
                bb.warn("A hook is defined for slot %s, but RAUC_BUNDLE_HOOKS[file] is not defined" % slot)
            manifest.write("hooks=%s\n" % slotflags.get('hooks'))
        manifest.write("\n")

        bundle_imgpath = "%s/%s" % (bundle_path, imgname)
        bb.note("adding image to bundle dir: '%s'" % imgname)
        searchpath = d.expand("${DEPLOY_DIR_IMAGE}/%s") % imgsource
        if os.path.isfile(searchpath):
            shutil.copy(searchpath, bundle_imgpath)
        else:
            raise bb.fatal("Failed adding image '%s' to bundle: not present in DEPLOY_DIR_IMAGE" % imgsource)

    manifest.close()

python do_configure() {
    import shutil
    import os
    import stat

    write_manifest(d)

    hooksflags = d.getVarFlags('RAUC_BUNDLE_HOOKS')
    if hooksflags and 'file' in hooksflags:
        hf = hooksflags.get('file')
        dsthook = d.expand("${BUNDLE_DIR}/%s" % hf)
        bb.note("adding hook file to bundle dir: '%s'" % hf)
        shutil.copy(d.expand("${WORKDIR}/%s" % hf), dsthook)
        st = os.stat(dsthook)
        os.chmod(dsthook, st.st_mode | stat.S_IEXEC)

    for file in (d.getVar('RAUC_BUNDLE_EXTRA_FILES') or "").split():
        searchpath = d.expand("${DEPLOY_DIR_IMAGE}/%s") % file
        destpath = d.expand("${BUNDLE_DIR}/%s") % file
        if os.path.isfile(searchpath):
            bb.note("adding extra file from deploy dir to bundle dir: '%s'" % file)
            shutil.copy(searchpath, destpath)
            continue

        searchpath = d.expand("${WORKDIR}/%s") % file
        if os.path.isfile(searchpath):
            bb.note("adding extra file from workdir to bundle dir: '%s'" % file)
            shutil.copy(searchpath, destpath)
            continue

        bb.error("extra file '%s' neither found in workdir nor in deploy dir!" % file)
}

BUNDLE_BASENAME ??= "${PN}"
BUNDLE_BASENAME[doc] = "Specifies desired output base name of generated bundle."
BUNDLE_NAME ??= "${BUNDLE_BASENAME}-${MACHINE}-${DATETIME}"
BUNDLE_NAME[doc] = "Specifies desired full output name of generated bundle."
# Don't include the DATETIME variable in the sstate package sigantures
BUNDLE_NAME[vardepsexclude] = "DATETIME"
BUNDLE_LINK_NAME ??= "${BUNDLE_BASENAME}-${MACHINE}"
BUNDLE_EXTENSION ??= ".raucb"
BUNDLE_EXTENSION[doc] = "Specifies desired custom filename extension of generated bundle"

do_bundle() {
	if [ -z "${RAUC_KEY_FILE}" ]; then
		bbfatal "'RAUC_KEY_FILE' not set. Please set to a valid key file location."
	fi

	if [ -z "${RAUC_CERT_FILE}" ]; then
		bbfatal "'RAUC_CERT_FILE' not set. Please set to a valid certificate file location."
	fi

	${STAGING_DIR_NATIVE}${bindir}/rauc bundle \
		--debug \
		--cert="${RAUC_CERT_FILE}" \
		--key="${RAUC_KEY_FILE}" \
		${BUNDLE_ARGS} \
		${BUNDLE_DIR} \
		${B}/bundle.raucb

	if [ ${RAUC_CASYNC_BUNDLE} -eq 1 ]; then
		if [ -z "${RAUC_KEYRING_FILE}" ]; then
			bbfatal "'RAUC_KEYRING_FILE' not set. Please set a valid keyring file location."
		fi

		# There is no package providing a binary named "fakeroot" but instead a
		# replacement named "pseudo". But casync requires fakeroot to be
		# installed, thus make a symlink.
		if ! [ -x "$(command -v fakeroot)" ]; then
			ln -sf ${STAGING_DIR_NATIVE}${bindir}/pseudo ${STAGING_DIR_NATIVE}${bindir}/fakeroot
		fi
		PSEUDO_PREFIX=${STAGING_DIR_NATIVE}/usr ${STAGING_DIR_NATIVE}${bindir}/rauc convert \
			--debug \
			--cert=${RAUC_CERT_FILE} \
			--key=${RAUC_KEY_FILE} \
			--keyring=${RAUC_KEYRING_FILE} \
			${CONVERT_ARGS} \
			${B}/bundle.raucb \
			${B}/casync-bundle.raucb
	fi
}
do_bundle[dirs] = "${B}"
do_bundle[cleandirs] = "${B}"

addtask bundle after do_configure before do_build

inherit deploy

do_deploy() {
	install -d ${DEPLOYDIR}
	install -m 0644 ${B}/bundle.raucb ${DEPLOYDIR}/${BUNDLE_NAME}${BUNDLE_EXTENSION}
	ln -sf ${BUNDLE_NAME}${BUNDLE_EXTENSION} ${DEPLOYDIR}/${BUNDLE_LINK_NAME}${BUNDLE_EXTENSION}

	if [ ${RAUC_CASYNC_BUNDLE} -eq 1 ]; then
		install ${B}/casync-bundle${BUNDLE_EXTENSION} ${DEPLOYDIR}/casync-${BUNDLE_NAME}${BUNDLE_EXTENSION}
		cp -r ${B}/casync-bundle.castr ${DEPLOYDIR}/casync-${BUNDLE_NAME}.castr
		ln -sf casync-${BUNDLE_NAME}${BUNDLE_EXTENSION} ${DEPLOYDIR}/casync-${BUNDLE_LINK_NAME}${BUNDLE_EXTENSION}
		ln -sf casync-${BUNDLE_NAME}.castr ${DEPLOYDIR}/casync-${BUNDLE_LINK_NAME}.castr
	fi
}

addtask deploy after do_bundle before do_build

do_deploy[cleandirs] = "${DEPLOYDIR}"
