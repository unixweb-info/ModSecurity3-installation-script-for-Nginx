#!/bin/bash
# Copyright (C) 2024 Author: Kriachko Aleksei admin@unixweb.info

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Function to check supported operating system
function check_os {
    supported_os=("CentOS Stream 9" "AlmaLinux 9\.[0-9] \(Seafoam Ocelot\)" "Rocky Linux 9\.[0-9] \(Blue Onyx\)")
    current_os=$(cat /etc/*release | grep '^PRETTY_NAME=' | cut -d '=' -f 2 | tr -d '"')
    for os in "${supported_os[@]}"; do
        if [[ "$current_os" =~ $os ]]; then
            return 0
        fi
    done
    echo "Unsupported operating system. This script can only be run on ${supported_os[@]}" >&2
    exit 1
}

old_version=3.2.0
modsecurity_dir_coreruleset=/etc/nginx/modsecurity.d/coreruleset

# Check if the directory exists before trying to move it
if [ ! -d "$modsecurity_dir_coreruleset" ]; then
    echo "Directory $modsecurity_dir_coreruleset does not exist" >&2
    exit 1
fi

/bin/mv $modsecurity_dir_coreruleset $modsecurity_dir_coreruleset-$old_version

# This command increases Git's HTTP buffer size to 500 MB.
# It helps to prevent errors that can occur during operations like cloning large repositories.
/usr/bin/git config --global http.postBuffer 524288000

# Check the exit status of the git clone command
/usr/bin/git clone https://github.com/SpiderLabs/owasp-modsecurity-crs.git $modsecurity_dir_coreruleset || { echo "Failed to clone repository"; exit 1; }

/bin/mv $modsecurity_dir_coreruleset/crs-setup.conf.example $modsecurity_dir_coreruleset/crs-setup.conf

# Remove specific files and directories from the 'coreruleset' directory
/bin/rm -rf $modsecurity_dir_coreruleset/{.github,.gitignore,.gitmodules,.travis.yml,CHANGES,CONTRIBUTING.md,CONTRIBUTORS.md,docs,INSTALL,KNOWN_BUGS,LICENSE,README.md,SECURITY.md,tests,util}

/bin/mv $modsecurity_dir_coreruleset/rules $modsecurity_dir_coreruleset/activated_rules

# Check the configuration of nginx
/sbin/nginx -t || { echo "Nginx configuration test failed"; exit 1; }

# Restart nginx and check the status
/bin/systemctl restart nginx || { echo "Failed to restart Nginx"; exit 1; }

