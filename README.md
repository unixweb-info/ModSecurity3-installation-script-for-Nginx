# Script Description for Installing ModSecurity3 for Nginx on CentOS Stream 9, AlmaLinux 9, and Rocky Linux 9

## Overview

This script automates the installation and configuration of ModSecurity3 for Nginx on supported operating systems (CentOS Stream 9, AlmaLinux 9, and Rocky Linux 9). The script performs the following tasks:

1. Checks if the script is run as root.
2. Checks if the operating system is supported.
3. Temporarily disables SELinux enforcement.
4. Installs required packages and repositories.
5. Clones and installs ModSecurity.
6. Clones and compiles the ModSecurity module for Nginx.
7. Configures Nginx to use ModSecurity.
8. Cleans up temporary files and restarts Nginx.

## Prerequisites

- Operating System: CentOS Stream 9, AlmaLinux 9, or Rocky Linux 9.
- Internet access for downloading packages and repositories.
- Root privileges.

## Function Descriptions

- **error_exit**: Displays an error message and exits the script.
- **log_message**: Logs messages to the file `/var/log/install-modsecurity3-for-Nginx.log`.
- **warn**: Displays a warning for non-critical errors.
- **check_os**: Checks if the current operating system is supported.

## Main Steps of the Script

1. **Check if the operating system is supported**:
    ```bash
    cat /etc/*release | grep '^PRETTY_NAME=' | cut -d '=' -f 2 | tr -d '"'
    ```

2. **Temporarily disable SELinux enforcement**:
    ```bash
    setenforce 0 || error_exit "Failed to disable SELinux"
    log_message "SELinux enforcement disabled"
    ```

3. **Install required packages and repositories**:
    ```bash
    sudo cat <<EOF > /etc/yum.repos.d/nginx.repo
    [nginx-stable]
    name=nginx stable repo
    baseurl=http://nginx.org/packages/rhel/\$releasever/\$basearch/
    gpgcheck=1
    enabled=1
    gpgkey=https://nginx.org/keys/nginx_signing.key
    module_hotfixes=true
    
    [nginx-mainline]
    name=nginx mainline repo
    baseurl=http://nginx.org/packages/mainline/rhel/\$releasever/\$basearch/
    gpgcheck=1
    enabled=0
    gpgkey=https://nginx.org/keys/nginx_signing.key
    module_hotfixes=true
    EOF
    sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-9.noarch.rpm -y
    sudo dnf install http://rpms.remirepo.net/enterprise/remi-release-9.rpm -y
    sudo dnf config-manager --set-enabled crb -y
    sudo dnf --enablerepo=remi install GeoIP-devel -y
    # Install additional packages
    sudo dnf install git wget dnf-utils nano -y
    vdnf install httpd-devel pcre pcre-devel libxml2 libxml2-devel curl curl-devel openssl openssl-devel nginx -y
    sudo dnf install doxygen yajl-devel gcc-c++ flex bison yajl zlib-devel autoconf automake make pkgconfig libtool redhat-rpm-config geos geos-devel geocode-glib-devel geolite2-city geolite2-country -y
    
    # Installing the libmodsecurity package
    sudo dnf install libmodsecurity -y
    ```

4. **Clone and install ModSecurity**:
    ```bash
    sudo git clone --depth 1 -b v3/master --single-branch https://github.com/owasp-modsecurity/ModSecurity.git /usr/local/src/ModSecurity/
    sudo cd /usr/local/src/ModSecurity/
    sudo git submodule init
    sudo git submodule update
    sudo ./build.sh && sudo ./configure && sudo make -j"$(($(nproc) / 2))" && sudo make install
    ```

5. **Clone and compile the ModSecurity module for Nginx**:
    ```bash
    sudo git clone --depth 1 https://github.com/owasp-modsecurity/ModSecurity-nginx.git /usr/local/src/ModSecurity-nginx || error_exit "Failed to clone ModSecurity-nginx repository"
    sudo cd /usr/local/src/nginx/
    sudo nginx_version=$(nginx -v 2>&1 | cut -d '/' -f 2)
    sudo nginx_tar="nginx-$nginx_version.tar.gz"
    sudo wget "http://nginx.org/download/$nginx_tar"
    sudo tar xfz $nginx_tar
    sudo cd "nginx-$nginx_version"
    sudo ./configure --with-compat --with-http_ssl_module --add-dynamic-module=/usr/local/src/ModSecurity-nginx --with-ld-opt="-L/usr/local/modsecurity/lib" --with-cc-opt="-I/usr/local/modsecurity/include"
    sudo make modules && cp objs/ngx_http_modsecurity_module.so /usr/lib64/nginx/modules/
    ```

6. **Configure Nginx to use ModSecurity**:
    ```bash
    sudo grep -q "include /etc/nginx/modules-enabled/*.conf;" /etc/nginx/nginx.conf || sed -i '8a include /etc/nginx/modules-enabled/*.conf;' /etc/nginx/nginx.conf
    sudo sed -i '46i\    modsecurity on;' /etc/nginx/nginx.conf
    sudo sed -i '47i\    modsecurity_rules_file /etc/nginx/modsecurity.d/modsecurity.conf;' /etc/nginx/nginx.conf
    sudo echo 'load_module "/usr/lib64/nginx/modules/ngx_http_modsecurity_module.so";' > /etc/nginx/modules-enabled/modsecurity3.conf
    ```
    
7. **Creating log files modsec_audit.log and modsec_debug.log**:

    Create a modsec_audit.log file and a modsec_debug.log file in the /var/log/nginx directory.
    If the file already exists, the touch command will update the last access time
    ```bash
    sudo touch /var/log/nginx/modsec_audit.log
    sudo touch /var/log/nginx/modsec_debug.log
    ```
    
    Change the owner and group of the modsec_audit.log file and the modsec_debug.log file to nginx and adm respectively.
    This is necessary so that the nginx process can write data to this file
    ```bash
    sudo chown nginx:adm /var/log/nginx/modsec_audit.log
    sudo chown nginx:adm /var/log/nginx/modsec_debug.log
    ```
    
8. **Clean up temporary files and restart Nginx**:
    ```bash
    sudo rm -rf /usr/local/src/*
    sudo systemctl restart nginx
    ```

You can find the installation log file at `/var/log/install-modsecurity3-for-Nginx.log`.

## Install ModSecurity, ModSecurity Nginx connector and OWASP rules

The "Install ModSecurity, ModSecurity Nginx connector and OWASP rules" script loads a shell script (`install.sh`) from a GitHub repository (`https://github.com/unixweb-info/ModSecurity3-installation-script-for-Nginx/blob/main/install.sh`), sets executable permissions for the script using `sudo chmod +x`, and then executes the script (`./install.sh`). This process installs ModSecurity, ModSecurity Nginx connector and OWASP rules for the Nginx web server.

```bash
wget https://github.com/unixweb-info/ModSecurity3-installation-script-for-Nginx/blob/main/install.sh && chmod+x ./install.sh && sudo ./install.sh
```

## OWASP Rules Update

The "OWASP Rules Update" script loads a shell script (`upgrade-rules.sh`) from a GitHub repository (`https://github.com/unixweb-info/ModSecurity3-installation-script-for-Nginx/blob/main/upgrade-rules.sh`), sets executable permissions for the script using `sudo chmod +x`, and then executes the script (`./upgrade-rules.sh`). This process updates OWASP ModSecurity rules for Nginx web servers.

```bash
wget https://github.com/unixweb-info/ModSecurity3-installation-script-for-Nginx/blob/main/upgrade-rules.sh && chmod+x ./upgrade-rules.sh && sudo ./upgrade-rules.sh
```

## Contact


For more information or questions about the script, you can contact me at the following contacts:

- **Telegram**: [UnixWebAdmin_info](https://t.me/UnixWebAdmin_info)
- **WhatsApp**: +995 593-245-168
- **Website**: [UnixWeb.info](https://UnixWeb.info)

I am ready to provide support and advice on setting up and using the script for your server.

## License

This project is licensed under the MIT License.

---

Developed by Kriachko Aleksei © 2024. Enjoy using the ModSecurity3 installation script for Nginx!
