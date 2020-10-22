#!/usr/bin/bash
IMAGE="ubuntu-20.04.1-live-server-amd64.iso"
MAINPWD=$(pwd)
BPATH=${MAINPWD}/DATA/BUILD

#check and install/configure dependecies
[ $(dpkg -s isolinux 2>/dev/null | grep -c "ok installed") -eq 1 ] || sudo apt install --yes isolinux
[ $(dpkg -s xorriso  2>/dev/null | grep -c "ok installed") -eq 1 ] || sudo apt install --yes xorriso
[ -d ./SOURCEIMG ] || mkdir ./SOURCEIMG
[ -e ./SOURCEIMG/${IMAGE} ] || wget -O ./SOURCEIMG/${IMAGE} https://releases.ubuntu.com/20.04/${IMAGE}
[ -d ./DATA ] || ( mkdir -p ./DATA/{ISOMOUNT,FINAL,BUILD/{squashfs,custom,cd}} )
[ -d ${BPATH}/squashfs ] || mkdir -p ${BPATH}/{squashfs,custom,cd}
##### filesystem.squashfs update & including latest patches into the image
sudo mount -o loop ${MAINPWD}/SOURCEIMG/${IMAGE} ${MAINPWD}/DATA/ISOMOUNT
rsync --exclude=/casper/filesystem.squashfs/ -a ${MAINPWD}/DATA/ISOMOUNT/ ${BPATH}/cd 
sudo modprobe squashfs
sudo mount -t squashfs -o loop ${MAINPWD}/DATA/ISOMOUNT/casper/filesystem.squashfs ${BPATH}/squashfs
sudo rsync -a ${BPATH}/squashfs/ ${BPATH}/custom/

# network comfgiuration for modification in chroot env
sudo cp ${BPATH}/custom/etc/resolv.conf ${BPATH}/custom/etc/resolv.conf_bck
sudo cp ${BPATH}/custom/etc/hosts ${BPATH}/custom/etc/hosts_bck
sudo cp ${BPATH}/custom/etc/apt/sources.list ${BPATH}/custom/etc/apt/sources.list_bck 
sudo cp /etc/resolv.conf /etc/hosts ${BPATH}/custom/etc/
sudo cp /etc/apt/sources.list ${BPATH}/custom/etc/apt/

# modification inside chroot
sudo chroot ${BPATH}/custom << EOT
mount -t proc none /proc/
mount -t sysfs none /sys/
export HOME=/root
apt-get update
apt-get dist-upgrade -y
apt-get clean
umount /proc
umount /sys
EOT
#network configuration restored to default 
sudo cp ${BPATH}/custom/etc/resolv.conf_bck ${BPATH}/custom/etc/resolv.conf 
sudo cp ${BPATH}/custom/etc/hosts_bck ${BPATH}/custom/etc/hosts
sudo cp ${BPATH}/custom/etc/apt/sources.list_bck ${BPATH}/custom/etc/apt/sources.list

sudo chmod 777 ${BPATH}/cd/casper/filesystem.manifest 
sudo chroot ${BPATH}/custom dpkg-query -W --showformat='${Package} ${Version}\n' > ${BPATH}/cd/casper/filesystem.manifest
sudo mksquashfs ${BPATH}/custom ${BPATH}/cd/casper/filesystem.squashfs -noappend
sudo rm ${BPATH}/cd/md5sum.txt

# copy cloud-init
[ -d ${BPATH}/cd/nocloud ] || sudo mkdir ${BPATH}/cd/nocloud
sudo cp configs/user-data ${BPATH}/cd/nocloud/user-data
sudo touch ${BPATH}/cd/nocloud/meta-data

#
sudo rm -rf '${BPATH}/cd/[BOOT]'

# umount loops 
sudo umount ${BPATH}/squashfs
sudo umount ${MAINPWD}/DATA/ISOMOUNT

# update boot flags
sudo sed -i 's|---|autoinstall ds=nocloud\\\;s=/cdrom/nocloud/ locale=en_US console-setup/ask_detect=false  console-setup/layoutcode=us console-setup/layoutcode=us console-setup/modelcode=SKIP translation/warn-light=true localechooser/translation/warn-severe=true keyboard-configuration/modelcode=SKIP keyboard-configuration/layout="English (US)" keyboard-configuration/variant="English (US)" ---|g' ${BPATH}/cd/boot/grub/grub.cfg
sudo sed -i 's|---|autoinstall ds=nocloud;s=/cdrom/nocloud/ locale=en_US console-setup/ask_detect=false  console-setup/layoutcode=us console-setup/layoutcode=us console-setup/modelcode=SKIP translation/warn-light=true localechooser/translation/warn-severe=true keyboard-configuration/modelcode=SKIP keyboard-configuration/layout="English (US)" keyboard-configuration/variant="English (US)" ---|g' ${BPATH}/cd/isolinux/txt.cfg

#recreate md5sum
sudo -s << EOR
cd ${BPATH}/cd
find . -type f -print0 | xargs -0 md5sum > md5sum.txt
EOR

# create image
cd ${BPATH}/cd
xorriso -as mkisofs -r \
  -V "Ubuntu Server 20.04 custom amd64" -o ${MAINPWD}/DATA/FINAL/ubuntu-20.04.1-live-server-amd64-autoinstall.iso \
  -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin boot .
