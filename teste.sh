#!/bin/bash

# =================================================================
# 1. ATUALIZANDO OS PACOTES DO SISTEMA
# =================================================================
sudo dnf upgrade -y

echo "Atualizacao concluida com sucesso!"

# =================================================================
# 2. INSTALANDO E HABILITANDO O MARIADB
# =================================================================
sudo dnf install mariadb-server -y
sudo systemctl enable --now mariadb

echo "Servidor de banco de dados instalado com sucesso!"
echo "Serviço do mariadb execução! obs: [active] em verde"

# =================================================================
# 3. AUTOMAÇÃO DA SEGURANÇA 
# =================================================================
DB_ROOT_PASS="Senac2026"
DB_GLPI_PASS="glpiDBSecret"

echo "Configurando a segurança do MariaDB de forma automática..."

# Define a senha do root e limpa usuários/bancos de teste
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS';"
sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -e "DROP DATABASE IF EXISTS test;"
sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
sudo mysql -e "FLUSH PRIVILEGES;"

# =================================================================
# 4. CRIAÇÃO DO BANCO E USUÁRIO DO GLPI
# Usamos o 'Heredoc' (<<EOF) para mandar todos os comandos de uma vez.
# =================================================================
echo "Criando o banco de dados 'glpi' / glpi= a user glpiDBSecret= Senha secreta"

sudo mysql -u root -p"$DB_ROOT_PASS" <<EOF
CREATE USER 'glpi'@'%' IDENTIFIED BY '$DB_GLPI_PASS';
GRANT USAGE ON *.* TO 'glpi'@'%' IDENTIFIED BY '$DB_GLPI_PASS';
CREATE DATABASE IF NOT EXISTS \`glpi\`;
GRANT ALL PRIVILEGES ON \`glpi\`.* TO 'glpi'@'%';
FLUSH PRIVILEGES;
EXIT;
EOF

# =================================================================
# 5. Instalação Repositório EPEL (Fornecem as versões mais recentes do PHP)
# =================================================================
sudo dnf install epel-release -y    
sudo dnf module reset php -y

echo "Repositório EPEL instalado e módulo PHP resetado com sucesso!"

# =================================================================
# 6. Instalação do PHP e apache
# =================================================================
sudo dnf -y install httpd php php-opcache php-apcu php-mysqli php-mbstring php-gd php-intl php-xml php-simplexml php-dom php-pecl-apcu php-bz2 php-curl php-zip php-bcmath
sudo systemctl enable --now httpd

echo "Servidor web Apache e PHP instalados com sucesso!"

# =================================================================
# 7. Regras de firewall para permitir o tráfego HTTP e HTTPS
# =================================================================
sudo firewall-cmd --zone=public --add-service=http --permanent
sudo firewall-cmd --permanent --add-service=https  
sudo firewall-cmd --reload 

echo "Regras de firewall configuradas para HTTP e HTTPS!"

# =================================================================
# 8. SELINUX: Configurando o SELinux para permitir que o Apache acesse os arquivos do GLPI
# =================================================================
sudo setsebool -P httpd_can_network_connect on
sudo setsebool -P httpd_can_network_connect_db on
sudo setsebool -P httpd_can_sendmail on 

echo "Configurações do SELinux aplicadas para o Apache!"

# =================================================================
# 9. Instalar git e baixar o GLPI
# =================================================================
sudo dnf install git -y 
cd /usr/share/

echo "Baixando o código fonte do GLPI usando git..."

#=================================================================
# 10. Baixando o código fonte atualizado direto do projeto oficial
#=================================================================
sudo git clone https://github.com/glpi-project/glpi.git 

cd /usr/share/glpi 

echo "Código fonte do GLPI baixado com sucesso!"

#=================================================================
# 11. Instalando pacotes do SO necessários para compilação e dependências
#=================================================================
sudo dnf install composer patch nodejs gettext -y    

echo "Pacotes necessários para o GLPI instalados com sucesso!"

#=================================================================
# 12. Configuração vitalícia para o git não reclamar de diretórios de outros usuários
#=================================================================
sudo git config --system --add safe.directory /usr/share/glpi 
sudo chown -R apache:apache /usr/share/httpd 
sudo -u apache git config --global --add safe.directory /usr/share/glpi 
sudo git config --system --add safe.directory /usr/share/glpi 

echo "Configurações do git aplicadas para o diretório do GLPI!"

#=================================================================
# 13. Cria a pasta de cache se não existir e define o dono
#=================================================================
sudo mkdir -p /usr/share/httpd/.npm 
sudo chown -R apache:apache /usr/share/httpd 

echo "Pasta de cache criada e permissões definidas para o Apache!"

#=================================================================
# 14. Limpando módulos velhos (caso existam) e instalando as dependências do projeto
#=================================================================
cd /usr/share/glpi
sudo rm -rf /usr/share/glpi/node modules

echo "Instalando as dependências do projeto GLPI usando composer e npm..."

#=================================================================
# 15. Define o dono de tudo como apache (O servidor web)
#=================================================================
sudo chown -R apache:apache /usr/share/glpi
sudo -u apache php bin/console dependencies install

echo "Dependências do GLPI instaladas com sucesso!"

#=================================================================
# 16. Permissões de pasta para o GLPI
#=================================================================
sudo chmod -R 775 /usr/share/glpi/files
sudo chmod -R 775 /usr/share/glpi/config
sudo chmod -R 775 /usr/share/glpi/marketplace
sudo chmod -R 775 /usr/share/glpi/public

echo "Permissões de pasta para o GLPI configuradas com sucesso!"

#=================================================================
# 17. SELinux reforçado para Fedora 43 Server
#=================================================================
sudo setsebool -P httpd_can_network_connect on
sudo setsebool -P httpd_can_network_connect_db on

echo "Configurações do SELinux reforçadas para o Fedora 43 Server!"

#=================================================================
# 18. Aplicando o contexto de leitura e escrita nas pastas de dados
#=================================================================
sudo chcon -R -t httpd_sys_rw_content_t /usr/share/glpi/files
sudo chcon -R -t httpd_sys_rw_content_t /usr/share/glpi/config
sudo chcon -R -t httpd_sys_rw_content_t /usr/share/glpi/marketplace
sudo chcon -R -t httpd_sys_rw_content_t /usr/share/glpi/public 

echo "Contexto de leitura e escrita aplicado nas pastas de dados do GLPI!"

#=================================================================
# 19. CONFIGURAÇÃO DO APACHE (MÉTODO DE CÓPIA)
#=================================================================
echo "Copiando arquivo de configuração pré-definido..."

# Descobre onde o script está rodando para não errar o caminho do arquivo
DIR_ATUAL=$(dirname "$(readlink -f "$0")")

if [ -f "$DIR_ATUAL/glpi_apache.conf" ]; then
    # Se o arquivo existir, faz a configuração
    sudo cp "$DIR_ATUAL/glpi_apache.conf" /etc/httpd/conf.d/glpi.conf
    sudo restorecon -v /etc/httpd/conf.d/glpi.conf
    
    # Reinicia o serviço e aplica sua correção de firewall
    sudo systemctl restart httpd
    sudo firewall-cmd --add-service=http --permanent
    sudo firewall-cmd --reload
    
    echo "Apache e Firewall configurados com sucesso!"
else
    # SE NÃO EXISTIR, aí sim ele avisa o erro e para
    echo "ERRO: O arquivo glpi_apache.conf não foi encontrado em $DIR_ATUAL"
    exit 1
fi

#=================================================================
# 20. Fora do glpi.conf
#=================================================================
cd
echo "* * * * * apache /usr/bin/php /usr/share/glpi/front/cron.php &>/dev/null" | sudo tee /etc/cron.d/glpi

echo "Tarefa cron para o GLPI criada com sucesso!"

#=================================================================
# 21. Reiniciar o Apache para ler o novo arquivo glpi.conf e aplicar as mudanças
#=================================================================
sudo systemctl restart httpd

echo "Servidor Apache reiniciado para aplicar as configurações do GLPI!"

#=================================================================
# 22. Adiciona permissão para o serviço HTTP e HTTPS
#=================================================================
# Adiciona permissão para o serviço HTTP e HTTPS
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

echo "Permissões para HTTP e HTTPS adicionadas ao firewall com sucesso!"

#=================================================================
# 22. Mensagem final de sucesso
#=================================================================

echo "Instalação do GLPI concluída com sucesso! Agora acesse http://ip_do_servidor/glpi para finalizar."
