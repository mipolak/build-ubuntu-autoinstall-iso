#!/usr/bin/bash
IMAGE="ubuntu-20.04.1-live-server-amd64.iso"
MAINPWD=$(pwd)

#check and install/configure dependecies
[ $(dpkg -s isolinux 2>/dev/null | grep -c "ok installed") -eq 1 ] || sudo apt install --yes isolinux
[ $(dpkg -s xorriso  2>/dev/null | grep -c "ok installed") -eq 1 ] || sudo apt install --yes xorriso
[ -d ./SOURCEIMG ] || mkdir ./SOURCEIMG
[ -e ./SOURCEIMG/${IMAGE} ] || wget -O ./SOURCEIMG/${IMAGE} https://releases.ubuntu.com/20.04/${IMAGE}
[ -d ./DATA ] || ( mkdir -p ./DATA/{ISOMOUNT,FINAL,BUILD/{squashfs,custom,cd}} )

##### filesystem.squashfs update & including latest patches into the image
sudo mount -o loop ./SOURCEIMG/${IMAGE} ./DATA/ISOMOUNT
rsync --exclude=/casper/filesystem.squashfs/ -a ./DATA/ISOMOUNT ./DATA/BUILD/cd 
sudo modprobe squashfs
sudo mount -t squashfs -o loop ./DATA/ISOMOUNT/casper/filesystem.squashfs ./DATA/BUILD/squashfs
sudo rsync -a ./DATA/BUILD/squashfs/ ./DATA/BUILD/custom

# network data for chroot env
sudo cp ./DATA/BUILD/custom/etc/resolv.conf ./DATA/BUILD/custom/etc/resolv.conf_bck
sudo cp ./DATA/BUILD/custom/etc/hosts ./DATA/BUILD/custom/etc/hosts_bck
sudo cp ./DATA/BUILD/custom/etc/apt/sources.list ./DATA/BUILD/custom/etc/apt/sources.list_bck 
sudo cp /etc/resolv.conf /etc/hosts ./DATA/BUILD/custom/etc/
sudo cp /etc/apt/sources.list ./DATA/BUILD/custom/etc/apt/

# modification inside chroot
sudo chroot ./DATA/BUILD/custom << EOT
mount -t proc none /proc/
mount -t sysfs none /sys/
export HOME=/root
apt-get update
apt-get dist-upgrade
apt-get clean
umount /proc
umount /sys
EOT

sudo cp ./DATA/BUILD/custom/etc/resolv.conf_bck ./DATA/BUILD/custom/etc/resolv.conf 
sudo cp ./DATA/BUILD/custom/etc/hosts_bck ./DATA/BUILD/custom/etc/hosts
sudo cp ./DATA/BUILD/custom/etc/apt/sources.list_bck ./DATA/BUILD/custom/etc/apt/sources.list

sudo mv ./DATA/BUILD/cd/casper/filesystem.manifest ./DATA/BUILD/cd/casper/filesystem.manifest_old
sudo chroot ./DATA/BUILD/custom dpkg-query -W --showformat='${Package} ${Version}\n' > ./DATA/BUILD/cd/casper/filesystem.manifest
sudo mksquashfs ./DATA/BUILD/custom ./DATA/BUILD/cd/casper/filesystem.squashfs
sudo rm ./DATA/BUILD/cd/md5sum.txt

# copy cloud-init
[ -d ./DATA/BUILD/cd/nocloud ] || sudo mkdir ./DATA/BUILD/cd/nocloud
sudo cp configs/user-data ./DATA/BUILD/cd/nocloud/user-data
sudo touch ./DATA/BUILD/cd/nocloud/meta-data

#
sudo rm -rf './DATA/BUILD/cd/[BOOT]'

# umount loops 
sudo umount ${MAINPWD}/DATA/BUILD/squashfs
sudo umount ${MAINPWD}/DATA/ISOMOUNT

# update boot flags
sed -i 's|---|autoinstall ds=nocloud\\\;s=/cdrom/nocloud/ locale=en_US console-setup/ask_detect=false  console-setup/layoutcode=us console-setup/layoutcode=us console-setup/modelcode=SKIP translation/warn-light=true localechooser/translation/warn-severe=true keyboard-configuration/modelcode=SKIP keyboard-configuration/layout="English (US)" keyboard-configuration/variant="English (US)" ---|g' ${MAINPWD}/DATA/BUILD/cd/boot/grub/grub.cfg
sed -i 's|---|autoinstall ds=nocloud;s=/cdrom/nocloud/ locale=en_US console-setup/ask_detect=false  console-setup/layoutcode=us console-setup/layoutcode=us console-setup/modelcode=SKIP translation/warn-light=true localechooser/translation/warn-severe=true keyboard-configuration/modelcode=SKIP keyboard-configuration/layout="English (US)" keyboard-configuration/variant="English (US)" ---|g' ${MAINPWD}/DATA/BUILD/cd/isolinux/txt.cfg

cd ${MAINPWD}


sudo -s << EOR
cd ./DATA/BUILD/cd
find . -type f -print0 | xargs -0 md5sum > md5sum.txt
EOR

# create image
cd ${MAINPWD}/DATA/BUILD/cd
xorriso -as mkisofs -r \
  -V "Ubuntu Server 20.04 custom amd64" -o ${MAINPWD}/DATA/FINAL/ubuntu-20.04.1-live-server-amd64-autoinstall.iso \
  -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin boot .
