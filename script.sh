#!/bin/bash

#--------------
#---Prepare----
#--------------

#Installing required packages and system updates
apt-get update
apt-get install squashfs-tool
apt-get install mkisofs

export NEW_NAME="linuxmint-taltech-edition"

#Removing the required directories if they are exist
rm -rf edit/ extract-cd/ mnt/ squashfs/ squashfs-root/

#Mounting 
#If ISO-file is in another directory, then add the path to it before the ISO-file name
mkdir mnt
mount -o loop linuxmint-20.1-cinnamon-64bit.iso mnt/

mkdir extract-cd
rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract-cd

mkdir squashfs
unsquashfs mnt/casper/filesystem.squashfs

mkdir edit
mv squashfs-root/* edit
#You can use next method, which is a little faster, but there is no visual display of the loading bar
#mount -t squashfs -o loop mnt/casper/filesystem.squashfs squashfs
#cp -a squashfs/* edit/
mount --bind /dev edit/dev

#--------------------------
#--Image modifing scripts--
#--------------------------

cat > edit/tmp/prepare.sh << ENDSCRIPT
#!/bin/bash
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts
export HOME=/root
export LC_ALL=C.UTF-8
#configure connectivity
export NAMESERVER="8.8.8.8"
echo "nameserver ${NAMESERVER}" > /etc/resolv.conf
apt update
exit
ENDSCRIPT

#----------------------------
#--Your customizations here--
#----------------------------
cat > edit/tmp/custom.sh << ENDSCRIPT
#!/bin/bash

apt upgrade

#ID-cart software 
wget -O id.sh https://installer.id.ee/media/ubuntu/install-open-eid.sh
sed ':a;N;$!ba; s/test_root//2' id.sh > id-new.sh
yes | sh id-mod.sh
rm id.sh id-mod.sh

#Brave browser
apt-get update
yes | apt install apt-transport-https curl
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
yes | apt update
yes | sudo apt install brave-browser

#Set incognito by default
mkdir /etc/skel/.local/share/applications/
cp usr/share/applications/brave-browser.desktop /etc/skel/.local/share/applications/brave-browser.desktop
sed -i 's/brave-browser-stable/brave-browser-stable --incognito --password-store=basic/g' /etc/skel/.local/share/applications/brave-browser.desktop 
sed -i 's/--incognito --password-store=basic --incognito/--incognito --password-store=basic/g' /etc/skel/.local/share/applications/brave-browser.desktop

cp usr/share/applications/firefox.desktop /etc/skel/.local/share/applications/firefox.desktop
sed -i 's/-private-window --password-store=basic %u/firefox -private-window --password-store=basic %u/g' /etc/skel/.local/share/applications/firefox.desktop
sed -i 's/firefox -new-window/firefox -private-window --password-store=basic %u/g' /etc/skel/.local/share/applications/firefox.desktop
sed -i 's/firefox -private-window/firefox -private-window --password-store=basic %u/g' /etc/skel/.local/share/applications/firefox.desktop

#Clear clipboard
cat > etc/skel/.local/clipboard.sh <<EOF
#!/bin/bash
xsel -bc
xsel -x -bc
xsel -x
EOF
(crontab -l 2>/dev/null; echo "* * * * * etc/skel/.local/clipboard.sh") | crontab -

#Other
sudo wget -O /usr/share/backgrounds/linuxmint/default_background.jpg https://portal-int.taltech.ee/sites/default/files/styles/manual_crop/public/news-image/TalTech_Zoom_taust_1920x1080px-09_0.jpg?itok=j0S5GA_7


yes | apt-get purge thunderbird*
yes | apt-get purge pidgin*
yes | apt-get purge gimp*xra
yes | apt-get purge mint-backgrounds-ulyssa*
yes | apt-get purge mint-backgrounds-ulyana*
yes | apt-get upgrade

exit
ENDSCRIPT

cat > edit/tmp/cleanup.sh << ENDSCRIPT
# Cleanups
echo "" > /etc/resolv.conf
apt clean
apt purge --auto-remove -y
rm -rf /tmp/*
rm -rf /var/cache/apt-xapian-index/*
rm -rf /var/lib/apt/lists/*
rm -rf ~/.bash_history
umount /proc/sys/fs/binfmt_misc || true
umount /sys
umount /dev/pts
umount /proc
exit
ENDSCRIPT


chmod +x edit/tmp/*.sh
chroot edit ./tmp/prepare.sh
#If you want to test something in the chroot environment, then uncomment next srtings
#chroot edit
#exit

chroot edit ./tmp/custom.sh
chroot edit ./tmp/cleanup.sh
umount edit/dev

#--------------------
#---ISO generating---
#--------------------
chmod +w extract-cd/casper/filesystem.manifest
chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > extract-cd/casper/filesystem.manifest
#chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > filesystem.manifest
#rm -f extract-cd/casper/filesystem.manifest
#mv filesystem.manifest extract-cd/casper
#sudo chown root:root extract-cd/casper/filesystem.manifest
chmod -w extract-cd/casper/filesystem.manifest

rm -f extract-cd/casper/filesystem.squashfs
#Default block size is 131072 bytes
mksquashfs edit extract-cd/casper/filesystem.squashfs
#Highest possible compression but it takes much more time
#mksquashfs edit extract-cd/casper/filesystem.squashfs -comp xz -e edit/boot

cd extract-cd
#Delete hashsums and generate the new with the sha256 algorithm
rm MD5SUMS
find -type f -print0 | sudo xargs -0 sha256sum | grep -v isolinux/boot.cat | sudo tee SHA256SUM

#Generate customized ISO-file
mkisofs -D -r -V "$NEW_NAME" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../$NEW_NAME.iso .

#---Checksum generating---
cd ../
sha256sum $NEW_NAME.iso > $NEW_NAME.iso.sha256
sha256sum -c $NEW_NAME.iso.sha256


#---Unmount and delete directories---
sudo umount ~/Desktop/ISO/squashfs 
sudo umount ~/Desktop/ISO/edit/dev 
sudo umount ~/Desktop/ISO/edit/run
sudo umount ~/Desktop/ISO/edit/proc
sudo umount ~/Desktop/ISO/edit/sys
sudo umount ~/Desktop/ISO/mnt
sudo rm -rf ~/Desktop/ISO/extract-cd
sudo rm -rf ~/Desktop/ISO/mnt
sudo rm -rf ~/Desktop/ISO/edit
sudo rm -rf ~/Desktop/ISO/squashfs
sudo rm -rf ~/Desktop/ISO/squashfs-root









