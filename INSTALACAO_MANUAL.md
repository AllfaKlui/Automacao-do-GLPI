# Guia de Instalação Manual - GLPI 10

Este documento contém os passos para a instalação 100% manual do GLPI no Fedora Server. Utilize este guia caso não queira usar o script automatizado ou para fins de depuração e aprendizado.

## 1. Preparação do Sistema e Banco de Dados

Atualize os pacotes do sistema:
`sudo dnf -y update`

Instale, habilite e inicie o MariaDB:
`sudo dnf -y install mariadb-server`

`sudo systemctl enable --now mariadb`

`sudo systemctl status mariadb`

Execute o script de segurança do MariaDB:
`sudo mariadb-secure-installation`
* Switch to unix_socket authentication [Y/n] y
* Change the root password? [Y/n] y (ex: Senac2026)
* Remove anonymous users? [Y/n] y
* Disallow root login remotely? [Y/n] y
* Remove test database and access to it? [Y/n] y

Acesse o banco com o usuário root e crie o usuário do GLPI:
`sudo mysql -u root -p`

Dentro do MySQL, execute:
```sql
CREATE USER 'glpi'@'%' IDENTIFIED BY 'glpiDBSecret';
GRANT USAGE ON *.* TO 'glpi'@'%' IDENTIFIED BY 'glpiDBSecret';
CREATE DATABASE IF NOT EXISTS `glpi`;
GRANT ALL PRIVILEGES ON `glpi`.* TO 'glpi'@'%';
FLUSH PRIVILEGES;
EXIT;
```

## 2. PHP e Apache

Instale os repositórios EPEL:

`sudo dnf install -y epel-release`

`sudo dnf module reset php -y`

Instale o Apache e as extensões PHP centralizadas:

`sudo dnf -y install httpd php php-opcache php-apcu php-mysqli php-mbstring php-gd php-intl php-xml      php-simplexml php-dom php-pecl-apcu php-bz2 php-curl php-zip php-bcmath php-ldap`

Habilite o Apache:

`sudo systemctl enable --now httpd`

## 3. Firewall e SELinux (Básico)

Libere as portas no Firewall:

`sudo firewall-cmd --zone=public --add-service=http --permanent`

`sudo firewall-cmd --permanent --add-service=https`

`sudo firewall-cmd --reload`

Ajustes iniciais do SELinux:

`sudo setsebool -P httpd_can_network_connect on`

`sudo setsebool -P httpd_can_network_connect_db on`

`sudo setsebool -P httpd_can_sendmail on`

## 4. Download e Configuração do GLPI

Instale o Git, dependências de compilação e baixe o repositório oficial:

`sudo dnf install git composer patch nodejs gettext -y`

`cd /usr/share/`

`sudo git clone https://github.com/glpi-project/glpi.git`

`cd /usr/share/glpi`

Configurações de segurança de diretório do Git e cache:

`sudo git config --system --add safe.directory /usr/share/glpi`
`sudo chown -R apache:apache /usr/share/httpd`

`sudo -u apache git config --global --add safe.directory /usr/share/glpi`

`sudo mkdir -p /usr/share/httpd/.npm`

`sudo chown -R apache:apache /usr/share/httpd`

Instalação das dependências via Composer:

`sudo rm -rf /usr/share/glpi/node_modules`

`sudo chown -R apache:apache /usr/share/glpi`

`sudo -u apache php bin/console dependencies install`

Ajuste de permissões e contextos do SELinux nas pastas de dados:

`sudo chmod -R 775 /usr/share/glpi/files /usr/share/glpi/config /usr/share/glpi/marketplace /usr/share/glpi/public`

`sudo chcon -R -t httpd_sys_rw_content_t /usr/share/glpi/files`

`sudo chcon -R -t httpd_sys_rw_content_t /usr/share/glpi/config`

`sudo chcon -R -t httpd_sys_rw_content_t /usr/share/glpi/marketplace`

`sudo chcon -R -t httpd_sys_rw_content_t /usr/share/glpi/public`

## 5. Configuração do VirtualHost do Apache

Agora precisamos criar o arquivo que ensina o Apache a encontrar o GLPI 10.

Crie o arquivo de configuração:

`sudo vi /etc/httpd/conf.d/glpi.conf`

Dentro do editor vi:

Aperte a tecla `i` para entrar no modo de inserção `(INSERT)`.



Cole o conteúdo abaixo:

# Aviso
 Caso o seu IP seja diferente troque ele em `Require ip xxx.xxx.xxx.xxx/xx`

```
# 1. Apontando para a pasta PUBLIC (Requisito do GLPI 10)
Alias /glpi "/usr/share/glpi/public"

<Directory "/usr/share/glpi/public">
    Options FollowSymLinks
    # AllowOverride All é crucial para o redirecionamento do index.php
    AllowOverride All
    Require all granted

    # Forçar o roteamento para o index.php (caso o .htaccess falhe)
    <IfModule mod_rewrite.c>
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </IfModule>
</Directory>

# 2. Corrigindo o acesso ao Install
<Directory "/usr/share/glpi/install">
    <IfModule mod_authz_core.c>
        # Permitir acesso local e da rede
        Require local
        Require ip 192.168.12.0/24 
    </IfModule>
</Directory>
```

### Para salvar e sair:

Aperte a tecla `ESC`.

Digite `:wq` e aperte `Enter`.

Após sair do editor, reinicie o Apache para carregar a configuração:

`sudo systemctl restart httpd`

Crie a rotina do Crontab para que o GLPI execute tarefas automáticas:

`echo "* * * * * apache /usr/bin/php /usr/share/glpi/front/cron.php &>/dev/null" | sudo tee /etc/cron.d/glpi`

## 6. Acesso e Solução de Problemas

Descubra o IP do servidor (ip a) e acesse no navegador: `http://IP_DA_MAQUINA/glpi`

`Servidor SQL: localhost`

`Usuário SQL: glpi`

`Senha SQL: glpiDBSecret`

Troubleshooting (Se houver erro no final):

Verifique se o Apache está rodando: `sudo systemctl status httpd`

Certifique-se que o Firewall foi recarregado.

`sudo firewall-cmd --add-service=http --permanent`

`sudo firewall-cmd --add-service=https --permanent`

`sudo firewall-cmd --reload`

Se a página não abrir ou der erro 403, desative temporariamente o SELinux com `sudo setenforce 0`.

Quando conseguir acessar, volte o SELinux para enforcing (`sudo setenforce 1`) e garanta que os contextos das pastas de configuração estão corretos.