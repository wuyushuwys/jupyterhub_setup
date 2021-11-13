# Jupyterhub
## Prerequisites
- Installing pip
  - `sudo apt install python3-pip`
- Virtual Environment
  - venv will be an helpful tool to organize all python environment
  - it will not damage globle setup
  - please install it as root user
  - `sudo python3 -m pip install virtualenv`
  - It's highly recommended all other package installed in virtual enviroments

## Install Jupyterhub

- Setup the JupyterHub and JupyterLab in a virtual environment


```
sudo python3 -m venv /opt/jupyterhub/
```


- Note that we use ***/opt/jupyterhub/bin/python3 -m pip install*** each time - this makes sure that the packages are installed to the correct virtual environment.


```
sudo /opt/jupyterhub/bin/python3 -m pip install wheel
sudo /opt/jupyterhub/bin/python3 -m pip install --upgrade pip
sudo /opt/jupyterhub/bin/python3 -m pip install jupyterhub jupyterlab
sudo /opt/jupyterhub/bin/python3 -m pip install ipywidgets
```


- JupyterHub also currently defaults to requiring configurable-http-proxy, which needs nodejs and npm. The versions of these available in Ubuntu therefore need to be installed first (they are a bit old but this is ok for our needs):


```
sudo apt install nodejs npm
```


- Then install configurable-http-proxy:


```
sudo npm install -g configurable-http-proxy
```


## Create the configuration for JupyterHub


- Now we start creating configuration files. To keep everything together, we put all the configuration into the folder created for the virtualenv, under ***/opt/jupyterhub/etc/***. For each thing needing configuration, we will create a further subfolder and necessary files.


- First create the folder for the JupyterHub configuration and navigate to it:


```
sudo mkdir -p /opt/jupyterhub/etc/jupyterhub/
cd /opt/jupyterhub/etc/jupyterhub/
```


- Then generate the default configuration file


```
sudo /opt/jupyterhub/bin/jupyterhub --generate-config
```

- This will produce the default configuration file ***/opt/jupyterhub/etc/jupyterhub/jupyterhub_config.py***

- You will need to edit the configuration file to make the JupyterLab interface by the default. Set the following configuration option in your jupyterhub_config.py file:

```python

# Setup default admin user
c.Authenticator.admin_users = {'admin1', 'admin2'} 
## Duration (in seconds) to determine the number of active users.
c.JupyterHub.active_user_window = 10
# Bind the port 8000 to jupyterhub
c.JupyterHub.bind_url = 'http://:8000/jupyter'
# Turn off server redirect
c.JupyterHub.redirect_to_server = False
# set jupyterlab as default interface in jupyterhub
c.Spawner.default_url = '/lab'      # if you want to set jupyter notebook as default interface, using '/tree'
# Add env path, in case jupyterhub unable to get access to CUDA
c.Spawner.env_keep.append('LD_LIBRARY_PATH')
# Disable create system user. Otherwise, if you create a new user in jupyterhub, it will create a new user in system as well
c.LocalAuthenticator.create_system_users = False
# Each user could name their servers
c.JupyterHub.allow_named_servers = True
# The number of server a user can named
c.JupyterHub.named_server_limit_per_user = 3


# For more funtionalities, please view https://jupyterhub.readthedocs.io/

```

## Setup Systemd service


- We will setup JupyterHub to run as a system service using Systemd (which is responsible for managing all services and servers that run on startup in Ubuntu). We will create a service file in a suitable location in the virtualenv folder and then link it to the system services. First create the folder for the service file:

```
sudo mkdir -p /opt/jupyterhub/etc/systemd
```

- Then create the following text file using your favourite editor at

```
/opt/jupyterhub/etc/systemd/jupyterhub.service
```

- Paste the following service unit definition into the file:


```
[Unit]
Description=JupyterHub
After=syslog.target network.target

[Service]
User=root
Environment="PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/jupyterhub/bin"
ExecStart=/opt/jupyterhub/bin/jupyterhub -f /opt/jupyterhub/etc/jupyterhub/jupyterhub_config.py

[Install]
WantedBy=multi-user.target
```

- Finally, we need to make systemd aware of our service file. First we symlink our file into systemd’s directory:

```
sudo ln -s /opt/jupyterhub/etc/systemd/jupyterhub.service /etc/systemd/system/jupyterhub.service
```

- Then tell systemd to reload its configuration files

```
sudo systemctl daemon-reload
```

- And finally enable the service

```
sudo systemctl enable jupyterhub.service
```

- The service will start on reboot, but we can start it straight away using:

```
sudo systemctl start jupyterhub.service
```

- check that it’s running using:

```
sudo systemctl status jupyterhub.service
```


## Setup venv for all users

- Install venv in a root directory
- Install ipykernel in venv
- Setup environment in jupyter
  - Global: in the venv, execute `sudo /path/to/kernel/env/bin/python -m ipykernel --name 'python' --display-name "Python (default)"`
  - User: in the venv, execute `/path/to/kernel/env/bin/python -m ipykernel --user --name 'python' --display-name "Python (default)"`
  
  
## Setting up a reverse proxy
### Using Nginx

- Install Nginx
  - Nginx is a mature and established web server and reverse proxy and is easy to install using `sudo apt install nginx`. Details on using Nginx as a reverse proxy can be found elsewhere. Here, we will only outline the additional steps needed to setup JupyterHub with Nginx and host it at a given URL. This could be useful for example if you are running several services or web pages on the same server.



- Now Nginx must be configured with a to pass all traffic from /jupyter to the the local address 127.0.0.1:8000. Add the following snippet to your nginx configuration file (e.g. /etc/nginx/sites-available/default).

```
 location /jupyter/ {
    # NOTE important to also set base url of jupyterhub to /jupyter in its config
    proxy_pass http://127.0.0.1:8000;

    proxy_redirect   off;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # websocket headers
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;

  }
```

- Also add this snippet before the server block:

```
map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }
```

- Nginx will not run if there are errors in the configuration, check your configuration using:

```
sudo nginx -t
```

- If there are no errors, you can restart the Nginx service for the new configuration to take effect.


```
sudo systemctl restart nginx.service
```

## Getting started using your new JupyterHub

Once you have setup JupyterHub and Nginx proxy as described, you can browse to your JupyterHub IP or URL (e.g. if your server IP address is 123.456.789.1 and you decided to host JupyterHub at the /jupyter URL, browse to 123.456.789.1/jupyter). You will find a login page where you enter your Linux username and password. On login you will be presented with the JupyterLab interface, with the file browser pane showing the contents of your users’ home directory on the server.

### For more information, please visit [Official Document](https://jupyterhub.readthedocs.io/)



## Troubleshooting

### Troubleshooting Command

Using this command below to get all debug info

```bash
<your-path-jupyterhub-venv>/bin/jupyterhub troubleshooting
```

After editing configuration, remenber to restart system service

```bash
sudo systemclt restart jupyterhub.service
```

### Spawn Failed

If you have error like

```
Spawn failed: Server at http://127.0.0.1:35990/user/username/ didn't respond in 30 seconds
```

It normally happen if you have jupyter in your server before. Simply remove the folder ` .jupyter`in your home folder will solve this problem.

```bash
rm -rf ~/.jupyter
```

if you get log in systemctl status like `PermissionError: [Errno 13] Permission denied: `, try
```bash
 sudo chown -R $USER:$USER ~/.local/share/jupyter 
 ```

Other options such as kill `configurable-http-proxy` and change configure file are not working in test.

### Update database

If you change any user profile in configuration file. Remember to update user database

```bash
<your-path-jupyterhub-venv>/bin/python -m jupyterhub update-db
```

