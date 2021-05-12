#!/bin/bash

set -e

# sudo permission checker
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Install pip3 and virtualenv
echo "Install pip3 and virtualenv"
sudo apt install python3-pip -y
# sudo python3 -m pip install virtualenv
sudo apt-get install python3-venv -y

# Install jupyterhub
echo "Install jupyterhub"
sudo python3 -m venv /opt/jupyterhub/
sudo /opt/jupyterhub/bin/python3 -m pip install wheel
sudo /opt/jupyterhub/bin/python3 -m pip install --upgrade pip
sudo /opt/jupyterhub/bin/python3 -m pip install jupyterhub jupyterlab
sudo /opt/jupyterhub/bin/python3 -m pip install ipywidgets
sudo /opt/jupyterhub/bin/python3 -m pip install jupyterhub-idle-culler

# sudo apt-get update
# sudo apt-get install nodejs-dev node-gyp libssl1.0-dev
# sudo apt install nodejs npm
# Install npm & configurable-http-proxy
echo "Install npm configurable-http-proxy"
sudo apt remove --purge nodejs npm
sudo apt clean
sudo apt autoclean
sudo apt install -f
sudo apt autoremove
sudo apt install curl -y
curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash - #  nodejs 12.X for jupyterlab-git
sudo apt-get install -y nodejs
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
sudo apt-get update && sudo apt-get install yarn -y
sudo npm install -g configurable-http-proxy

# Create the configuration for Jupyterhub
echo "Create the configuration for Jupyterhub"
sudo mkdir -p /opt/jupyterhub/etc/jupyterhub/
# cd /opt/jupyterhub/etc/jupyterhub/

# sudo /opt/jupyterhub/bin/jupyterhub --generate-config # generate config file

sudo echo "
c.Authenticator.admin_users = {'wuyushu',}

c.JupyterHub.active_user_window = 2

c.JupyterHub.ssl_cert = '/etc/nginx/ssl/certificate.pem'

c.JupyterHub.ssl_key = '/etc/nginx/ssl/key.pem'

c.JupyterHub.bind_url = 'http://:55555/jupyter'

c.JupyterHub.redirect_to_server = False

c.Spawner.default_url = '/lab'

c.Spawner.env_keep.append('LD_LIBRARY_PATH')

c.LocalAuthenticator.create_system_users = False

c.JupyterHub.allow_named_servers = False

# c.JupyterHub.named_server_limit_per_user = 3

c.Authenticator.delete_invalid_users = True
import sys
c.JupyterHub.services = [
    {
        'name': 'idle-culler',
        'admin': True,
        'command': [
            sys.executable,
            '-m', 'jupyterhub_idle_culler',
            '--timeout=86400'
        ],
    }
]" > /opt/jupyterhub/etc/jupyterhub/jupyterhub_config.py

# Setup Systemd service
echo "Setup Systemd service"
sudo mkdir -p /opt/jupyterhub/etc/systemd
sudo echo "[Unit]
Description=JupyterHub
After=syslog.target network.target

[Service]
User=root
Environment=\"PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/jupyterhub/bin\"
ExecStart=/opt/jupyterhub/bin/jupyterhub -f /opt/jupyterhub/etc/jupyterhub/jupyterhub_config.py

[Install]
WantedBy=multi-user.target" > /opt/jupyterhub/etc/systemd/jupyterhub.service

# Link system service
echo "Link system service"
sudo ln -s /opt/jupyterhub/etc/systemd/jupyterhub.service /etc/systemd/system/jupyterhub.service
# sudo systemctl daemon-reload
# sudo systemctl enable jupyterhub.service
# sudo systemctl start jupyterhub.service
# sudo systemctl status jupyterhub.service


# Setting up a reverse proxy by Nginx
echo "Setting up a reverse proxy by Nginx"
sudo apt install nginx -y

sudo mkdir -p /etc/nginx/ssl

# create ssl key & cert
echo "create ssl key & cert"
sudo openssl req -newkey rsa:2048 -nodes -keyout /etc/nginx/ssl/key.pem -x509 -days 365 -out /etc/nginx/ssl/certificate.pem           

sudo echo "##
# You should look at the following URL's in order to grasp a solid understanding
# of Nginx configuration files in order to fully unleash the power of Nginx.
# https://www.nginx.com/resources/wiki/start/
# https://www.nginx.com/resources/wiki/start/topics/tutorials/config_pitfalls/
# https://wiki.debian.org/Nginx/DirectoryStructure
#
# In most cases, administrators will remove this file from sites-enabled/ and
# leave it as reference inside of sites-available where it will continue to be
# updated by the nginx packaging team.
#
# This file will automatically load configuration files provided by other
# applications, such as Drupal or Wordpress. These applications will be made
# available underneath a path with that package name, such as /drupal8.
#
# Please see /usr/share/doc/nginx-doc/examples/ for more detailed examples.
##

# Default server configuration
#
map \$http_upgrade \$connection_upgrade {
        default upgrade;
        '' close;
    }
server {
    listen 80;
    server_name _;

    # Tell all requests to port 80 to be 302 redirected to HTTPS
    # return 302 https://\$host\$request_uri;
}
server {
	# listen 80 default_server;
	# listen [::]:80 default_server;

	# SSL configuration
	#
	# listen 443 ssl default_server;
	# listen [::]:443 ssl default_server;
	listen 443;	
	ssl on;
	server_name _;

	ssl_certificate /etc/nginx/ssl/certificate.pem;
	ssl_certificate_key /etc/nginx/ssl/key.pem;
	
	ssl_ciphers \"AES128+EECDH:AES128+EDH\";
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains\";
        add_header X-Content-Type-Options nosniff;
        ssl_stapling on; # Requires nginx >= 1.3.7
        ssl_stapling_verify on; # Requires nginx => 1.3.7
        resolver_timeout 5s;

        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;	

	# Note: You should disable gzip for SSL traffic.
	# See: https://bugs.debian.org/773332
	#
	# Read up on ssl_ciphers to ensure a secure configuration.
	# See: https://bugs.debian.org/765782
	#
	# Self signed certs generated by the ssl-cert package
	# Don't use them in a production server!
	#
	# include snippets/snakeoil.conf;

	root /var/www/html;

	# Add index.php to the list if you are using PHP
	index index.html index.htm index.nginx-debian.html;

	server_name _;

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		try_files \$uri \$uri/ =404;
	}
	location /jupyter/ {
	   # NOTE important to also set base url of jupyterhub to /jupyter in its config
	   proxy_pass https://127.0.0.1:55555;

	   proxy_redirect   off;
	   proxy_set_header X-Real-IP \$remote_addr;
	   proxy_set_header Host \$host;
	   proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	   proxy_set_header X-Forwarded-Proto \$scheme;

	   # websocket headers
	   proxy_set_header Upgrade \$http_upgrade;
	   proxy_set_header Connection \$connection_upgrade;

 	}
	# pass PHP scripts to FastCGI server
	#
	#location ~ \.php$ {
	#	include snippets/fastcgi-php.conf;
	#
	#	# With php-fpm (or other unix sockets):
	#	fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
	#	# With php-cgi (or other tcp sockets):
	#	fastcgi_pass 127.0.0.1:9000;
	#}

	# deny access to .htaccess files, if Apache's document root
	# concurs with nginx's one
	#
	#location ~ /\.ht {
	#	deny all;
	#}
}


# Virtual Host configuration for example.com
#
# You can move that to a different file under sites-available/ and symlink that
# to sites-enabled/ to enable it.
#
#server {
#	listen 80;
#	listen [::]:80;
#
#	server_name example.com;
#
#	root /var/www/example.com;
#	index index.html;
#
#	location / {
#		try_files \$uri \$uri/ =404;
#	}
#}

" > /etc/nginx/sites-available/default

# test ngnix
echo "test ngnix"
sudo nginx -t


# Install Jupyterlab extension
echo "Install jupyter extension"
sudo /opt/jupyterhub/bin/python3 -m pip install ipympl                                  # matplotlib
sudo /opt/jupyterhub/bin/python3 -m pip install jupyterlab-topbar                       # topbar
sudo /opt/jupyterhub/bin/python3 -m pip install jupyterlab_theme_hale                   # hale theme
sudo /opt/jupyterhub/bin/python3 -m pip install jupyterlab_theme_solarized_dark         # solarized_dark 
sudo /opt/jupyterhub/bin/python3 -m pip install jupyterlab-system-monitor               # system monitor
sudo /opt/jupyterhub/bin/python3 -m pip install jupyterlab-code-snippets                # code snippets
sudo /opt/jupyterhub/bin/python3 -m pip install jupyterlab_execute_time                 # jupyterlab execute time
sudo /opt/jupyterhub/bin/python3 -m pip install jupyter-resource-usage                  # resource-usage
sudo /opt/jupyterhub/bin/python3 -m pip install jupyterlab-python-file                  # python-file

# sudo /opt/jupyterhub/bin/python3 -m pip install --upgrade jupyterlab-git     # jupyterlab-git

# Reload system service and test
echo "Reload system service and test"
sudo systemctl daemon-reload
sudo systemctl enable jupyterhub.service
sudo systemctl start jupyterhub.service
sudo systemctl status jupyterhub.service
sudo systemctl restart nginx.service

echo "#### Finish ####"


                                                
