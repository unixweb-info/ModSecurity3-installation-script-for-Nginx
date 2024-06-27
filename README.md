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

1. **Check if the script is run as root**:
    ```bash
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root" >&2
        exit 1
    fi
    ```

2. **Check if the operating system is supported**:
    ```bash
    supported_os=("CentOS Stream 9" "AlmaLinux 9\.[0-9] \(Seafoam Ocelot\)" "Rocky Linux 9\.[0-9] \(Blue Onyx\)")
    current_os=$(cat /etc/*release | grep '^PRETTY_NAME=' | cut -d '=' -f 2 | tr -d '"')
    for os in "${supported_os[@]}"; do
        if [[ "$current_os" =~ $os ]]; then
            return 0
        fi
    done
    return 1
    ```

3. **Temporarily disable SELinux enforcement**:
    ```bash
    setenforce 0 || error_exit "Failed to disable SELinux"
    log_message "SELinux enforcement disabled"
    ```

4. **Install required packages and repositories**:
    ```bash
    dnf install $epel_packages -y || error_exit "Failed to install epel-release and epel-next-release packages"
    dnf install $remi_repo -y || error_exit "Failed to install remi-release-9.rpm package"
    dnf config-manager --set-enabled crb -y || error_exit "Failed to enable crb repository"
    dnf --enablerepo=remi install GeoIP-devel -y || error_exit "Failed to install GeoIP-devel package from remi repository"
    log_message "Necessary packages installed"
    ```

5. **Clone and install ModSecurity**:
    ```bash
    git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity /usr/local/src/ModSecurity/  || error_exit "Failed to clone ModSecurity repository"
    cd /usr/local/src/ModSecurity/
    git submodule init
    git submodule update
    ./build.sh && ./configure && make -j"$(($(nproc) / 2))" && make install || error_exit "Failed to build and install ModSecurity"
    log_message "ModSecurity built and installed"
    ```

6. **Clone and compile the ModSecurity module for Nginx**:
    ```bash
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git $modsecurity_nginx_dir || error_exit "Failed to clone ModSecurity-nginx repository"
    cd /usr/local/src/nginx/
    nginx_version=$(nginx -v 2>&1 | cut -d '/' -f 2)
    nginx_tar="nginx-$nginx_version.tar.gz"
    wget "http://nginx.org/download/$nginx_tar" || error_exit "Failed to download nginx source code"
    tar xfz $nginx_tar || error_exit "Failed to extract nginx source code"
    cd "nginx-$nginx_version"
    ./configure --with-compat --with-http_ssl_module --add-dynamic-module=$modsecurity_nginx_dir --with-ld-opt="-L$modsecurity_lib_dir" --with-cc-opt="-I$modsecurity_include_dir" || error_exit "Failed to configure nginx with ModSecurity module"
    make modules && cp objs/ngx_http_modsecurity_module.so /usr/lib64/nginx/modules/ || error_exit "Failed to make and copy ModSecurity module to nginx modules directory"
    log_message "Nginx configured with ModSecurity module"
    ```

7. **Configure Nginx to use ModSecurity**:
    ```bash
    grep -q "include /etc/nginx/modules-enabled/*.conf;" /etc/nginx/nginx.conf || sed -i '8a include /etc/nginx/modules-enabled/*.conf;' /etc/nginx/nginx.conf
    sed -i '46i\    modsecurity on;' /etc/nginx/nginx.conf || error_exit "Failed to update nginx.conf"
    sed -i '47i\    modsecurity_rules_file /etc/nginx/modsecurity.d/modsecurity.conf;' /etc/nginx/nginx.conf || error_exit "Failed to update nginx.conf"
    log_message "Nginx.conf updated with ModSecurity module and rules"
    echo 'load_module "/usr/lib64/nginx/modules/ngx_http_modsecurity_module.so";' > /etc/nginx/modules-enabled/modsecurity3.conf || error_exit "Failed to create modsecurity3.conf file"
    log_message "Directory for nginx modules and modsecurity3.conf created"
    ```

8. **Clean up temporary files and restart Nginx**:
    ```bash
    rm -rf /usr/local/src/* || error_exit "Failed to clean up downloaded source files"
    log_message "Downloaded source files cleaned up"
    systemctl restart nginx || warn "Failed to restart nginx service"
    log_message "Nginx service restarted"
    ```

## Completion

After successful execution of the script, the following message will be displayed:
```bash
echo "Setup completed successfully"
```

You can find the installation log file at `/var/log/install-modsecurity3-for-Nginx.log`.

## Install ModSecurity, ModSecurity Nginx connector and OWASP rules

The "Install ModSecurity, ModSecurity Nginx connector and OWASP rules" script loads a shell script (`install.sh`) from a GitHub repository (`https://github.com/unixweb-info/ModSecurity3-installation-script-for-Nginx/blob/main/install.sh`), sets executable permissions for the script using `sudo chmod +x`, and then executes the script (`./install.sh`). This process installs ModSecurity, ModSecurity Nginx connector and OWASP rules for the Nginx web server.

```bash
wget https://github.com/unixweb-info/ModSecurity3-installation-script-for-Nginx/blob/main/install.sh && sudo chmod+x ./install.sh && sudo ./install.sh
```

## OWASP Rules Update

The "OWASP Rules Update" script loads a shell script (`upgrade-rules.sh`) from a GitHub repository (`https://github.com/unixweb-info/ModSecurity3-installation-script-for-Nginx/blob/main/upgrade-rules.sh`), sets executable permissions for the script using `sudo chmod +x`, and then executes the script (`./upgrade-rules.sh`). This process updates OWASP ModSecurity rules for Nginx web servers.

```bash
wget https://github.com/unixweb-info/ModSecurity3-installation-script-for-Nginx/blob/main/upgrade-rules.sh && sudo chmod+x ./upgrade-rules.sh && sudo ./upgrade-rules.sh
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
