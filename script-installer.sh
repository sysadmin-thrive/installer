#!/usr/bin/env bash
set -euo pipefail

log()  { echo -e "[INFO ] $*"; }
warn() { echo -e "[WARN ] $*" >&2; }
err()  { echo -e "[ERROR] $*" >&2; exit 1; }

########################################
# CEK ROOT & OS
########################################

if [[ "$(id -u)" -ne 0 ]]; then
  err "Script ini harus dijalankan sebagai root."
fi

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  err "/etc/os-release tidak ditemukan. Bukan Rocky Linux?"
fi

if [[ "${ID:-}" != "rocky" ]] || [[ "${VERSION_ID:-}" != 9* ]]; then
  err "Script ini disiapkan untuk Rocky Linux 9.x (sekarang: ${PRETTY_NAME:-unknown})."
fi

log "OS terdeteksi: ${PRETTY_NAME}"

########################################
# UPDATE OS & TOOLS DASAR
########################################

log "Update paket sistem..."
dnf -y update

log "Install tools dasar (curl, wget, tar, editor)..."
dnf install -y curl wget tar nano vim sudo

########################################
# EPEL + REMI (PHP 7.4)
########################################

log "Install EPEL & Remi repo..."
dnf install -y epel-release
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm

log "Enable modul PHP 7.4 dari Remi..."
dnf module reset php -y
dnf module enable php:remi-7.4 -y

########################################
# DATABASE SERVER: MARIADB (BUILT-IN ROCKY)
########################################

log "Install MariaDB server (pengganti MySQL)..."
dnf install -y mariadb-server

log "Enable & start mariadb..."
systemctl enable --now mariadb

log "MariaDB terinstall. Jalankan 'mysql_secure_installation' manual nanti untuk hardening."

########################################
# APACHE + PHP 7.4 + EXTENSION
########################################

log "Install Apache, PHP-FPM, dan extension penting..."

dnf install -y \
  httpd \
  php \
  php-cli \
  php-fpm \
  php-common \
  php-mbstring \
  php-xml \
  php-json \
  php-gd \
  php-intl \
  php-pdo \
  php-mysqlnd \
  php-opcache \
  php-zip \
  php-bcmath \
  php-soap \
  php-sodium \
  php-sqlite3 \
  php-bz2 \
  php-process \
  php-xsl

log "Install extension ekstra (ssh2, grpc, protobuf, mcrypt)..."
dnf install -y \
  php-pecl-ssh2 \
  php-pecl-grpc \
  php-pecl-protobuf \
  php-pecl-mcrypt || warn "Beberapa ekstensi PECL gagal dipasang, cek manual jika diperlukan."

log "Enable & start httpd + php-fpm..."
systemctl enable --now httpd php-fpm

########################################
# JAVA 11
########################################

log "Install OpenJDK 11..."
dnf install -y java-11-openjdk

########################################
# COMPOSER & GIT
########################################

log "Install Git..."
dnf install -y git

log "Install Composer (global di /usr/local/bin)..."
cd /usr/local/bin
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"

composer -V || warn "Composer terinstall tapi tidak bisa dijalankan, cek manual."

########################################
# RINGKASAN
########################################

echo
log "INSTALASI DASAR SELESAI (TANPA CONFIG)."
echo
echo "=== RINGKASAN ==="
echo "- OS              : ${PRETTY_NAME}"
echo "- DB Server       : MariaDB (mariadb-server)"
echo "- Apache          : httpd"
echo "- PHP             : $(php -v | head -n1)"
echo "- PHP modules     : cek dengan 'php -m'"
echo "- Apache status   : systemctl status httpd"
echo "- PHP-FPM status  : systemctl status php-fpm"
echo "- MariaDB status  : systemctl status mariadb"
echo "- Java            : $(java -version 2>&1 | head -n1 || echo 'n/a')"
echo "- Git             : $(git --version 2>/dev/null || echo 'git tidak terbaca di PATH')"
echo "- Composer        : $(composer -V 2>/dev/null || echo 'composer tidak terbaca di PATH')"
echo
echo "Script ini HANYA install paket & start servicenya."
echo "Konfigurasi vhost Apache, PHP-FPM pool, dan restore aplikasi/DB kamu lakukan manual."
echo
log "Selesai."
