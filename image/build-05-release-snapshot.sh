#!/bin/bash
# Release image of "unofficial v1": a snapshot of a phone with every fix installed, over USB, into a fresh ext4 that keeps
# the partition layout, /home skeleton and /opt/click.ubuntu.com of an earlier clean image (OLD).
# Removed: personal data, Wi-Fi connections, SSH host keys, machine-id, Bluetooth address, proprietary firmware and sensor
# configs (the installer copies them from the phone). Then the password is set to 1111, two .debs are installed in a chroot,
# rfkill states are reset and the image is scanned for personal values.
# Usage: OLD=<earlier clean image> NEW=<new image> PATTERNS=<file with your own personal values, one per line> ./build-05-release-snapshot.sh
# Run in the folder that holds the images; OVERLAY= (default rootfs-overlay) gives the mobile-internet connection, DEBS= the two .debs.
set -eu
SP=${SP:-$PWD/work}; mkdir -p $SP/build
OLD=${OLD:?}; NEW=${NEW:?}; PATTERNS=${PATTERNS:?}; DEBS=${DEBS:-debs}; MNT=${MNT:-mnt-new}; OLDM=$SP/mnt-old; mkdir -p $OLDM $MNT
SSH="sshpass -p 1111 ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no root@172.16.42.1"
G=/usr/bin/grep
[ ! -e $NEW ] || { echo "$NEW exists"; exit 1; }
LO=$(sudo -n losetup -f --show -r -P --sector-size 4096 $OLD)
dd if=$OLD of=$NEW bs=4096 count=124928 status=none; truncate -s 4959207424 $NEW
GUID=$(sudo -n sgdisk -i 2 $LO | awk '/unique GUID/{print $4}')
L=$(sudo -n losetup -f --show --sector-size 4096 $NEW)
sudo -n sgdisk -e -d 2 -n 2:124928:1210623 -t 2:8305 -c 2:primary -u 2:$GUID $L >/dev/null 2>&1 || true
sudo -n sgdisk -v $L | tail -1 | cut -c1-70; sudo -n losetup -d $L
L=$(sudo -n losetup -f --show -P --sector-size 4096 $NEW)
sudo -n mkfs.ext4 -F -q -L pmOS_root -U 27c97050-ff55-4e42-b894-0f866eb5ad1f -b 4096 -I 256 -N 327680 -m 5 -E lazy_itable_init=0,lazy_journal_init=0 ${L}p2
sudo -n mount ${L}p2 $MNT; sudo -n mount -o ro,noload ${LO}p2 $OLDM
sudo -n mkdir -p $MNT/home; sudo -n cp -a $OLDM/home/. $MNT/home/
echo "== tar $(date +%T)"
$SSH 'cd / && systemd-inhibit --what=sleep:idle --who=snapshot --why=image tar --one-file-system --xattrs --acls --numeric-owner --warning=no-file-ignored -cf - --exclude=./proc/* --exclude=./sys/* --exclude=./dev/* --exclude=./run/* --exclude=./tmp/* --exclude=./mnt/* --exclude=./media/* --exclude=./boot/* --exclude=./root/* --exclude=./root/.[!.]* --exclude=./home/* --exclude=./opt/click.ubuntu.com/* --exclude=./lost+found --exclude=./var/log/* --exclude=./var/cache/* --exclude=./var/tmp/* --exclude=./var/crash/* --exclude=./var/lib/apt/lists/* --exclude=./var/lib/systemd/coredump/* --exclude=./var/lib/systemd/random-seed --exclude=./var/lib/NetworkManager/* --exclude=./var/lib/bluetooth/* --exclude=./var/lib/upower/* --exclude=./var/lib/sudo/* --exclude=./var/lib/usermetrics/* --exclude=./etc/NetworkManager/system-connections/* --exclude=./etc/netplan/90-NM-* --exclude=./etc/shadow- --exclude=./etc/shadow.m52xq.bak --exclude=./etc/.m52xq-shadow-backup --exclude=./etc/m52xq/bt_addr --exclude=./etc/m52xq/data-sim --exclude=./etc/ssh/ssh_host_* --exclude=./etc/systemd/system/m52xq-wizard-trace.service --exclude=./var/lib/whoopsie/* --exclude=./usr/share/qcom/sm7325/Samsung/m52xq/sensors/registry/* --exclude=./usr/share/qcom/sm7325/Samsung/m52xq/sensors/config/* --exclude=./usr/share/qcom/sm7325/Samsung/m52xq/sensors/sns_reg.conf --exclude=./usr/lib/firmware/adsp* --exclude=./usr/lib/firmware/modem* --exclude=./usr/lib/firmware/a660_zap* --exclude=./usr/lib/firmware/yupik_ipa_fws* --exclude=./usr/lib/firmware/qca/* --exclude=./usr/lib/firmware/qcom/vpu-2.0/* . ; echo tar-rc=$? >&2' 2>$SP/build/tar.err | sudo -n tar --xattrs --acls --numeric-owner -xpf - -C $MNT
tail -3 $SP/build/tar.err | cut -c1-140; $G -q 'tar-rc=[01]$' $SP/build/tar.err || { echo TAR-FAILED; exit 1; }
sudo -n mkdir -p $MNT/opt/click.ubuntu.com; sudo -n cp -a $OLDM/opt/click.ubuntu.com/. $MNT/opt/click.ubuntu.com/; sudo -n umount $OLDM; sudo -n losetup -d $LO
echo "== dirs $(date +%T)"
$SSH 'cd / && find var/log var/cache var/tmp -xdev -type d -print0 | tar --no-recursion --null -T - --numeric-owner -cf -' 2>/dev/null | sudo -n tar --numeric-owner -xpf - -C $MNT
sudo -n mkdir -p $MNT/root; sudo -n chmod 700 $MNT/root
sudo -n install -d -m755 $MNT/etc/NetworkManager/system-connections
sudo -n install -m600 -o root -g root ${OVERLAY:-rootfs-overlay}/etc/NetworkManager/system-connections/m52xq-mobile-internet.nmconnection $MNT/etc/NetworkManager/system-connections/
H=$(openssl passwd -6 1111)
sudo -n env H="$H" awk 'BEGIN{FS=OFS=":"} $1=="root"||$1=="user"{$2=ENVIRON["H"]} {print}' $MNT/etc/shadow > $SP/build/shadow.new
sudo -n sh -c "cat $SP/build/shadow.new > $MNT/etc/shadow"; rm -f $SP/build/shadow.new
sudo -n cp -a $MNT/etc/shadow $MNT/etc/shadow-; sudo -n cp -a $MNT/etc/shadow $MNT/etc/.m52xq-shadow-backup; sudo -n touch $MNT/etc/.m52xq-default-password-set
sudo -n sed -i 's/^user:x:10000:10000:[^:]*:/user:x:10000:10000:user:/' $MNT/etc/passwd
sudo -n sh -c ": > $MNT/etc/machine-id"; [ -L $MNT/var/lib/dbus/machine-id ] || sudo -n rm -f $MNT/var/lib/dbus/machine-id
sudo -n rm -f $MNT/etc/systemd/user/lomiri-indicators.target.wants/ayatana-indicator-datetime.service $MNT/etc/systemd/system/multi-user.target.wants/m52xq-virtualcam.service
echo "== debs $(date +%T)"
sudo -n mkdir -p $MNT/tmp/m52xq-debs; sudo -n cp $DEBS/libssl1.1_1.1.1f-1ubuntu2.24_arm64.deb $DEBS/qml-module-lomiri-pushnotifications_0.3.1-1_arm64.deb $MNT/tmp/m52xq-debs/
sudo -n mount --bind /dev $MNT/dev; sudo -n mount -t proc proc $MNT/proc
sudo -n chroot $MNT /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/m52xq-debs/libssl1.1_1.1.1f-1ubuntu2.24_arm64.deb /tmp/m52xq-debs/qml-module-lomiri-pushnotifications_0.3.1-1_arm64.deb 2>&1 | tail -4
sudo -n umount $MNT/proc; sudo -n umount $MNT/dev
sudo -n rm -f $MNT/tmp/m52xq-debs/libssl1.1_1.1.1f-1ubuntu2.24_arm64.deb $MNT/tmp/m52xq-debs/qml-module-lomiri-pushnotifications_0.3.1-1_arm64.deb; sudo -n rmdir $MNT/tmp/m52xq-debs
sudo -n chroot $MNT /usr/bin/dpkg-query -W -f='${Package} ${Version} ${Status}\n' libssl1.1 qml-module-lomiri-pushnotifications libkf6people6 libcamera0.7 libcamera-ipa gstreamer1.0-libcamera
sudo -n mkdir -p $MNT/var/lib/urfkill
printf '[BLUETOOTH]\nsoft=false\nprev-soft=false\n\n[WLAN]\nsoft=false\nprev-soft=false\n\n[NFC]\nsoft=false\nprev-soft=false\n\n[UWB]\nprev-soft=false\nsoft=false\n\n[WIMAX]\nprev-soft=false\nsoft=false\n' | sudo -n tee $MNT/var/lib/urfkill/saved-states >/dev/null
sudo -n chmod 444 $MNT/var/lib/urfkill/saved-states
echo urfkill: $(sudo -n /usr/bin/grep -c "soft=true" $MNT/var/lib/urfkill/saved-states) blocked, bt-firmware: $(sudo -n md5sum $MNT/usr/local/bin/m52xq-bt-firmware | cut -c1-8)
echo v8: zram $(sudo -n readlink $MNT/etc/systemd/system/swap.target.wants/m52xq-zram.service) gen $(sudo -n md5sum $MNT/etc/systemd/user-environment-generators/90-m52xq-lang | cut -c1-8) camsrc $(sudo -n md5sum $MNT/usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstm52xqcamsrc.so | cut -c1-8) libcamera $(sudo -n md5sum $MNT/usr/lib/aarch64-linux-gnu/libcamera.so.0.7.2 | cut -c1-8) start-lomiri $(sudo -n md5sum $MNT/usr/local/bin/m52xq-start-lomiri | cut -c1-8) viewfinder $(sudo -n md5sum $MNT/usr/share/lomiri-camera-app/qml/Viewfinder/ViewFinderView.qml | cut -c1-8)
sync; df -B1 $MNT | tail -1 | awk '{print "used",$3,"free",$4}'
echo "== scan $(date +%T)"
umask 077
$SSH 'cat /etc/m52xq/bt_addr; echo; cat /sys/class/net/wl*/address 2>/dev/null; mmcli -L 2>/dev/null | sed -n "s#.*/Modem/\([0-9]*\).*#\1#p" | while read m; do mmcli -m $m -K 2>/dev/null | sed -n "s/.*equipment-identifier *: *//p; s/.*own-numbers.value.*: *//p"; S=$(mmcli -m $m -K 2>/dev/null | sed -n "s#.*generic.sim *: */org/freedesktop/ModemManager1/SIM/##p"); [ -n "$S" ] && mmcli -i $S -K 2>/dev/null | sed -n "s/.*sim.properties.imsi *: *//p; s/.*sim.properties.iccid *: *//p"; done; nmcli -t -f NAME connection show 2>/dev/null; sed -n "s/^\(root\|user\):\([^:]*\):.*/\2/p" /etc/shadow' 2>/dev/null > $SP/build/p0.txt
cat "$PATTERNS" >> $SP/build/p0.txt   # your SSIDs, names, passwords, account names
/usr/bin/python3 -I - "$SP/build" <<'P'
import sys
d=sys.argv[1]; out=set(); skip={'lo','Wired connection 1','--'}
for l in open(d+'/p0.txt',errors='ignore'):
    l=l.strip()
    if len(l)<5 or l in skip: continue
    out|={l,l.lower(),l.upper()}
    if l.count(':')==5: out|={l.replace(':',''),l.replace(':','').lower()}
open(d+'/p.txt','w').write('\n'.join(sorted(out))+'\n'); print('patterns',len(out))
P
[ -s $SP/build/p.txt ]
sudo -n $G -rlaF -f $SP/build/p.txt $MNT 2>/dev/null | sed "s#^$MNT/##" > $SP/build/hits.txt || true
echo hits=$(wc -l < $SP/build/hits.txt); head -14 $SP/build/hits.txt
rm -f $SP/build/p0.txt $SP/build/p.txt
for f in etc/m52xq/bt_addr etc/m52xq/data-sim usr/lib/firmware/adsp.mdt usr/lib/firmware/modem.mdt usr/lib/firmware/a660_zap.mdt usr/lib/firmware/qca/msnv11.bin usr/lib/firmware/qcom/vpu-2.0/venus.mbn usr/lib/firmware/yupik_ipa_fws.mdt; do sudo -n test -e $MNT/$f && echo "HAS $f"; done
echo welcome: $(sudo -n md5sum $MNT/usr/share/lomiri/Wizard/Pages/10-welcome.qml | cut -c1-8) keep: $(sudo -n ls $MNT/usr/lib/firmware/wpss.mdt $MNT/usr/lib/firmware/a660_sqe.fw 2>&1 | wc -l) click: $(sudo -n ls $MNT/opt/click.ubuntu.com | tr '\n' ' ') dialer: $(sudo -n md5sum $MNT/usr/bin/plasma-dialer | cut -c1-8) ssh: $(sudo -n ls $MNT/etc/ssh | $G -c ssh_host)
sudo -n umount $MNT; sudo -n e2fsck -fn ${L}p2 2>&1 | tail -1; sudo -n losetup -d $L
echo BUILD-OK-$(date +%T)
