#!/usr/bin/bash
IMAGE="ubuntu-20.04.1-live-server-amd64.iso"

#check and install/configure dependecies
[ $(dpkg -s isolinux 2>/dev/null | grep -c "ok installed") -eq 1 ] || sudo apt install --yes isolinux
[ $(dpkg -s xorriso  2>/dev/null | grep -c "ok installed") -eq 1 ] || sudo apt install --yes xorriso
[ $(dpkg -s p7zip-full  2>/dev/null | grep -c "ok installed") -eq 1 ] || sudo apt install --yes p7zip-full
[ -d ./SOURCEIMG ] || mkdir ./SOURCEIMG
[ -d ./BUILDS ] || mkdir ./BUILDS
[ -e ./SOURCEIMG/${IMAGE} ] || wget -O ./SOURCEIMG/${IMAGE} https://releases.ubuntu.com/20.04/${IMAGE}
[ -d ./DATA ] || ( mkdir ./DATA && 7z x ./SOURCEIMG/${IMAGE} -oDATA )

# copy cloud-init
[ -d ./DATA/nocloud ] || mkdir ./DATA/nocloud
cp configs/user-data DATA/nocloud/user-data
touch DATA/nocloud/meta-data

#
rm -rf 'DATA/[BOOT]'
# need to fix md5sum check, causing warning with 1 file found 

# update boot flags
sed -i 's|---|autoinstall ds=nocloud\\\;s=/cdrom/nocloud/ locale=en_US console-setup/ask_detect=false  console-setup/layoutcode=us console-setup/layoutcode=us console-setup/modelcode=SKIP translation/warn-light=true localechooser/translation/warn-severe=true keyboard-configuration/modelcode=SKIP keyboard-configuration/layout="English (US)" keyboard-configuration/variant="English (US)" ---|g' ./DATA/boot/grub/grub.cfg
sed -i 's|---|autoinstall ds=nocloud;s=/cdrom/nocloud/ locale=en_US console-setup/ask_detect=false  console-setup/layoutcode=us console-setup/layoutcode=us console-setup/modelcode=SKIP translation/warn-light=true localechooser/translation/warn-severe=true keyboard-configuration/modelcode=SKIP keyboard-configuration/layout="English (US)" keyboard-configuration/variant="English (US)" ---|g' ./DATA/isolinux/txt.cfg

# 
xorriso -as mkisofs -r \
  -V Ubuntu\ custom\ amd64 \
  -o BUILDS/ubuntu-20.04.1-live-server-amd64-autoinstall.iso \
  -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \
  -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
  -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin  \
  DATA/boot DATA
