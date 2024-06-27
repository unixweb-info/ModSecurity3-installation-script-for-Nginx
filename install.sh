#!/bin/bash
# Copyright (C) 2024 Author: Kriachko Aleksei admin@unixweb.info

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Function to display error message and exit
function error_exit {
    echo "Error: $1" >&2
    exit 1
}

# Logging function
function log_message {
    echo "$(date +"%Y-%m-%d %H:%M:%S") $1" >> /var/log/install-modsecurity3-for-Nginx.log
}

# Warning function (for non-critical errors)
function warn {
    echo "Warning: $1" >&2
}

# Function to check supported operating system
function check_os {
    supported_os=("CentOS Stream 9" "AlmaLinux 9\.[0-9] \(Seafoam Ocelot\)" "Rocky Linux 9\.[0-9] \(Blue Onyx\)")
    current_os=$(cat /etc/*release | grep '^PRETTY_NAME=' | cut -d '=' -f 2 | tr -d '"')
    for os in "${supported_os[@]}"; do
        if [[ "$current_os" =~ $os ]]; then
            return 0
        fi
    done
    return 1
}

# Check if operating system is supported
check_os || error_exit "Unsupported operating system: $current_os"

# Disable SELinux enforcement temporarily
setenforce 0 || error_exit "Failed to disable SELinux"
log_message "SELinux enforcement disabled"

# Define package variables
other_packages="git wget dnf-utils nano"
nginx_packages="httpd-devel pcre pcre-devel libxml2 libxml2-devel curl curl-devel openssl openssl-devel nginx"
modsecurity_packages="doxygen yajl-devel gcc-c++ flex bison yajl zlib-devel autoconf automake make pkgconfig libtool redhat-rpm-config geos geos-devel geocode-glib-devel geolite2-city geolite2-country GeoIP-devel"
epel_packages="https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-9.noarch.rpm"
remi_repo="http://rpms.remirepo.net/enterprise/remi-release-9.rpm"
nginx_repo_file="/etc/yum.repos.d/nginx.repo"

# Check if nginx repository is already added
if [ ! -f "$nginx_repo_file" ]; then
    # Create nginx repository configuration file
    cat <<EOF > "$nginx_repo_file"
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
    log_message "Nginx repository added"
else
    log_message "Nginx repository already exists, skipping this step"
fi

# Install necessary packages
dnf install $epel_packages -y || error_exit "Failed to install epel-release and epel-next-release packages"
dnf install $remi_repo -y || error_exit "Failed to install remi-release-9.rpm package"
dnf config-manager --set-enabled crb -y || error_exit "Failed to enable crb repository"
dnf --enablerepo=remi install GeoIP-devel -y || error_exit "Failed to install GeoIP-devel package from remi repository"
log_message "Necessary packages installed"

# Install additional packages
dnf install $other_packages -y || error_exit "Failed to install other and required packages"
dnf install $nginx_packages -y || error_exit "Failed to install Nginx and required packages"
dnf install $modsecurity_packages -y || error_exit "Failed to install modsecurity packages"
log_message "Necessary packages installed"

# Clone ModSecurity repository and checkout the v3/master branch
if [ -d "/usr/local/src/ModSecurity" ]; then
    rm -rf /usr/local/src/ModSecurity || error_exit "Failed to remove existing directory /usr/local/src/ModSecurity"
fi

git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity /usr/local/src/ModSecurity/  || error_exit "Failed to clone ModSecurity repository"

cd /usr/local/src/ModSecurity/
git submodule init
git submodule update

# Build and install ModSecurity
./build.sh && ./configure && make -j"$(($(nproc) / 2))" && make install || error_exit "Failed to build and install ModSecurity"
log_message "ModSecurity built and installed"

# Check if the ModSecurity-nginx directory already exists and is not empty
modsecurity_nginx_dir="/usr/local/src/ModSecurity-nginx"
if [ -d "$modsecurity_nginx_dir" ] && [ "$(ls -A $modsecurity_nginx_dir)" ]; then
    log_message "Directory $modsecurity_nginx_dir already exists and is not empty, skipping clone"
else
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git $modsecurity_nginx_dir || error_exit "Failed to clone ModSecurity-nginx repository"
fi

# Set library and include paths
modsecurity_lib_dir=${MODSECURITY_LIB_DIR:-/usr/local/modsecurity/lib}
modsecurity_include_dir=${MODSECURITY_INCLUDE_DIR:-/usr/local/modsecurity/include}

# Download nginx source code
mkdir -p /usr/local/src/nginx
cd /usr/local/src/nginx/
nginx_version=$(nginx -v 2>&1 | cut -d '/' -f 2)
nginx_tar="nginx-$nginx_version.tar.gz"
wget "http://nginx.org/download/$nginx_tar" || error_exit "Failed to download nginx source code"
tar xfz $nginx_tar || error_exit "Failed to extract nginx source code"
cd "nginx-$nginx_version"

# Configure nginx with ModSecurity module 
./configure --with-compat --with-http_ssl_module --add-dynamic-module=$modsecurity_nginx_dir --with-ld-opt="-L$modsecurity_lib_dir" --with-cc-opt="-I$modsecurity_include_dir" || error_exit "Failed to configure nginx with ModSecurity module"
make modules && cp objs/ngx_http_modsecurity_module.so /usr/lib64/nginx/modules/ || error_exit "Failed to make and copy ModSecurity module to nginx modules directory"
log_message "Nginx configured with ModSecurity module"

# Create directory for nginx modules and create modsecurity3.conf file
if [ ! -d "/etc/nginx/modules-enabled" ]; then
  mkdir /etc/nginx/modules-enabled || error_exit "Failed to create directory for nginx modules"
fi

# Update nginx.conf to include ModSecurity module and rules
if ! grep -q "include /etc/nginx/modules-enabled/\*.conf;" /etc/nginx/nginx.conf; then
  sed -i '8a include /etc/nginx/modules-enabled/*.conf;' /etc/nginx/nginx.conf || error_exit "Failed to update nginx.conf"
fi
sed -i '46i\    modsecurity on;' /etc/nginx/nginx.conf || error_exit "Failed to update nginx.conf"
sed -i '47i\    modsecurity_rules_file /etc/nginx/modsecurity.d/modsecurity.conf;' /etc/nginx/nginx.conf || error_exit "Failed to update nginx.conf"
log_message "Nginx.conf updated with ModSecurity module and rules"

echo 'load_module "/usr/lib64/nginx/modules/ngx_http_modsecurity_module.so";' > /etc/nginx/modules-enabled/modsecurity3.conf || error_exit "Failed to create modsecurity3.conf file"
log_message "Directory for nginx modules and modsecurity3.conf created"

# Create a modsec_audit.log file and a ModSecurity-Debug.log file in the /var/log/nginx directory.
# If the file already exists, the touch command will update the last access time
touch /var/log/nginx/modsec_audit.log
touch /var/log/nginx/ModSecurity-Debug.log

# Change the owner and group of the modsec_audit.log file and the ModSecurity-Debug.log file to nginx and adm respectively.
# This is necessary so that the nginx process can write data to this file
chown nginx:adm /var/log/nginx/modsec_audit.log
chown nginx:adm /var/log/nginx/ModSecurity-Debug.log

# Directory path
modsecurity_dir="/etc/nginx/modsecurity.d"

# Checking and deleting a directory if it exists
if [ -d "$modsecurity_dir" ]; then
    rm -rf "$modsecurity_dir" || error_exit "Failed to remove existing directory $modsecurity_dir"
fi

# Clone modsecurity.d repository
git clone https://github.com/unixweb-info/modsecurity.d.git "$modsecurity_dir" || error_exit "Failed to clone modsecurity.d repository"

# Navigate to the 'coreruleset' directory in 'modsecurity_dir'
cd $modsecurity_dir/coreruleset

# Remove specific files and directories from the 'coreruleset' directory
rm -rf $modsecurity_dir/coreruleset/{.github,.gitignore,.gitmodules,.travis.yml}

# Inform user about completion of basic setup
echo "The basic setup is complete, then you need to perform additional setup manually."
log_message "Basic setup completed"

# Removing packages with modsecurity dependencies
dnf remove $modsecurity_packages -y || error_exit "Failed to remove packages with modsecurity dependencies"
log_message "Installed packages have been removed"

# Installing the libmodsecurity package
dnf install libmodsecurity -y  || error_exit "Failed to install libmodsecurity dependency package"
log_message "The libmodsecurity package is installed"

# Restart nginx service 
systemctl restart nginx || warn "Failed to restart nginx service"
log_message "Nginx service restarted"

# Clean up downloaded source files
rm -rf /usr/local/src/* || error_exit "Failed to clean up downloaded source files"
log_message "Downloaded source files cleaned up"

echo "Setup completed successfully"
