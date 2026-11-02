#!/bin/sh
# внутри корня Ubuntu (образ mnt-new): имя, fstab, локали, пользователь, пакеты Qualcomm-слоя, сессия Lomiri, службы
set -e
echo samsung-m52xq-classic > /etc/hostname
printf '127.0.0.1 localhost\n127.0.1.1 samsung-m52xq-classic\n' > /etc/hosts
cat > /etc/fstab <<'F'
# классик: корень и /boot монтирует initramfs (vendor_boot); записи — для systemd
LABEL=pmOS_root / ext4 defaults,noatime 0 1
LABEL=pmOS_boot /boot ext2 defaults,nofail,noatime 0 2
F
locale-gen en_US.UTF-8 ru_RU.UTF-8 >/dev/null 2>&1 || true
update-locale LANG=en_US.UTF-8
id user >/dev/null 2>&1 || useradd -m -u 10000 -U -s /bin/bash -c "user" user
for g in sudo audio video input render plugdev netdev dialout adm bluetooth; do getent group $g >/dev/null && usermod -aG $g user; done
# пароль 1111 не проходит проверку pam_pwquality в Ubuntu: кладём готовый хеш (chpasswd -e)
HASH='$6$N7PQtCtPLYG9Fwae$azZvc759lw4FikgvkRC0KPogGModnBatRhCbThJQzSwcKfc2pqtDxp3GtUKoacstdxU2CDpa6b2.hyF7V1oBs.'
echo "user:$HASH" | chpasswd -e
echo "root:$HASH" | chpasswd -e
apt-get -y --no-install-recommends install rmtfs tqftpserv qrtr-tools hexagonrpcd iio-sensor-proxy alsa-ucm-conf iw rfkill usbutils bluez 2>&1 | tail -3
depmod -a 7.1.2 2>&1 | tail -2
# Ubuntu-вский repowerd заменяем нашим m52xq-powerkey; lightdm не нужен (сессию стартует своя служба)
systemctl disable repowerd.service lightdm.service 2>&1 | tail -1 || true
cat > /etc/systemd/system/m52xq-session.service <<'S'
[Unit]
Description=M52XQ: Ubuntu Touch session (autologin on tty1, like tinydm)
Conflicts=getty@tty1.service
After=systemd-user-sessions.service plymouth-quit-wait.service dbus.socket getty@tty1.service
OnFailure=getty@tty1.service
ConditionPathExists=/dev/tty0

[Service]
Environment=GRID_UNIT_PX=21
ExecStart=/usr/bin/ubuntu-touch-session
User=10000
Group=10000
PAMName=login
WorkingDirectory=~
Restart=always
RestartSec=2s
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty-fail
StandardOutput=journal
StandardError=journal
UtmpIdentifier=tty1
UtmpMode=user

[Install]
Alias=display-manager.service
WantedBy=graphical.target
S
systemctl set-default graphical.target 2>&1 | tail -1
systemctl enable m52xq-session.service m52xq-usbnet.service m52xq-powerkey.service ssh.service NetworkManager.service ModemManager.service 2>&1 | tail -4
: > /etc/machine-id
rm -f /etc/ssh/ssh_host_*   # ключи хоста создаются при первой загрузке (ssh-keygen -A в юните)
