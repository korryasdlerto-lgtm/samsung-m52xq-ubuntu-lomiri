cat > /etc/apt/sources.list.d/ubports.sources <<'L'
Types: deb
URIs: http://repo.ubports.com/
Suites: 26.04-1.x
Components: main
Architectures: arm64
Trusted: yes
L
mkdir -p /etc/apt/preferences.d
cat > /etc/apt/preferences.d/ubports.pref <<'L'
Package: *
Pin: origin repo.ubports.com
Pin-Priority: 1001
L
apt-get update 2>&1 | tail -3
apt-cache policy lomiri ubuntu-touch-session mir-graphics-drivers-desktop | head -20
apt-get -s install ubuntu-touch-session 2>&1 | tail -6
