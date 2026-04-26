#!/bin/bash

# ==========================================
# FUNÇÃO: AGUARDAR INTERNET
# ==========================================
check_internet() {
    echo "Verificando conexão com a internet..."
    while ! ping -c 1 google.com &> /dev/null
    do
        echo "Sem internet... tentando novamente em 5s"
        sleep 5
    done
    echo "Internet OK!"
}

# ==========================================
# FUNÇÃO: RETRY (TENTAR NOVAMENTE)
# ==========================================
retry() {
    n=0
    until [ $n -ge 5 ]
    do
        "$@" && break
        n=$((n+1))
        echo "Erro... tentando novamente ($n/5)"
        sleep 3
    done
}

# ==========================================
# INÍCIO
# ==========================================
check_internet

echo "Atualizando sistema..."
retry sudo dnf upgrade -y

# ==========================================
# MARIADB
# ==========================================
retry sudo dnf install mariadb-server -y
sudo systemctl enable --now mariadb

DB_ROOT_PASS="Senac2026"
DB_GLPI_PASS="glpiDBSecret"

echo "Configurando MariaDB..."

sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# ==========================================
# BANCO GLPI
# ==========================================
sudo mysql -u root -p"${DB_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS glpi;
CREATE USER IF NOT EXISTS 'glpi'@'%' IDENTIFIED BY '${DB_GLPI_PASS}';
GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'%';
FLUSH PRIVILEGES;
EOF

# ==========================================
# PHP + APACHE
# ==========================================
retry sudo dnf install epel-release -y
sudo dnf module reset php -y

retry sudo dnf install -y httpd php php-opcache php-apcu php-mysqli php-mbstring php-gd php-intl php-xml php-bz2 php-curl php-zip php-bcmath composer git nodejs gettext

sudo systemctl enable --now httpd

# ==========================================
# FIREWALL
# ==========================================
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# ==========================================
# SELINUX
# ==========================================
sudo setsebool -P httpd_can_network_connect on
sudo setsebool -P httpd_can_network_connect_db on

# ==========================================
# DOWNLOAD GLPI
# ==========================================
cd /usr/share
retry sudo git clone https://github.com/glpi-project/glpi.git

cd /usr/share/glpi

# ==========================================
# PERMISSÕES
# ==========================================
sudo chown -R apache:apache /usr/share/glpi

# ==========================================
# DEPENDÊNCIAS
# ==========================================
sudo rm -rf node_modules
sudo -u apache php bin/console dependencies install

# ==========================================
# PERMISSÕES IMPORTANTES
# ==========================================
sudo chmod -R 775 files config marketplace public

# ==========================================
# SELINUX CONTEXTO
# ==========================================
sudo chcon -R -t httpd_sys_rw_content_t files config marketplace public

# ==========================================
# CRON
# ==========================================
echo "* * * * * apache /usr/bin/php /usr/share/glpi/front/cron.php &>/dev/null" | sudo tee /etc/cron.d/glpi

# ==========================================
# RESTART APACHE
# ==========================================
sudo systemctl restart httpd

# ==========================================
# FINAL
# ==========================================
echo "======================================="
echo "GLPI instalado com sucesso!"
echo "Acesse: http://IP_DO_SERVIDOR/glpi"
echo "======================================="

# ==========================================
# CONFIG MANUAL (DEIXADO POR ÚLTIMO)
# ==========================================
echo ""
echo "AGORA EXECUTE MANUALMENTE:"
echo "sudo vi /etc/httpd/conf.d/glpi.conf"
echo ""
echo "Cole a configuração do Apache que você já criou."