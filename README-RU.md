# Скрипт установки ModSecurity3 для Nginx на CentOS Stream 9, AlmaLinux 9 и Rocky Linux 9

## Описание

Этот скрипт предназначен для автоматической установки и настройки ModSecurity3 для Nginx на поддерживаемых операционных системах (CentOS Stream 9, AlmaLinux 9 и Rocky Linux 9). Скрипт выполняет следующие действия:

1. Проверка запуска скрипта от имени root.
2. Проверка поддерживаемой операционной системы.
3. Временное отключение SELinux.
4. Установка необходимых пакетов и репозиториев.
5. Клонирование и установка ModSecurity.
6. Клонирование и компиляция модуля ModSecurity для Nginx.
7. Настройка Nginx для использования ModSecurity.
8. Очистка временных файлов и перезапуск Nginx.

## Предварительные требования

- Операционная система: CentOS Stream 9, AlmaLinux 9 или Rocky Linux 9.
- Доступ к интернету для загрузки пакетов и репозиториев.
- Права суперпользователя (root).

## Описание функций

- **error_exit**: Отображает сообщение об ошибке и завершает выполнение скрипта.
- **log_message**: Логирует сообщения в файл `/var/log/install-modsecurity3-for-Nginx.log`.
- **warn**: Отображает предупреждение для некритических ошибок.
- **check_os**: Проверяет, поддерживается ли текущая операционная система.

## Основные шаги скрипта

1. **Проверка запуска скрипта от имени root**:
    ```bash
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root" >&2
        exit 1
    fi
    ```

2. **Проверка поддерживаемой операционной системы**:
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

3. **Временное отключение SELinux**:
    ```bash
    setenforce 0 || error_exit "Failed to disable SELinux"
    log_message "SELinux enforcement disabled"
    ```

4. **Установка необходимых пакетов и репозиториев**:
    ```bash
    dnf install $epel_packages -y || error_exit "Failed to install epel-release and epel-next-release packages"
    dnf install $remi_repo -y || error_exit "Failed to install remi-release-9.rpm package"
    dnf config-manager --set-enabled crb -y || error_exit "Failed to enable crb repository"
    dnf --enablerepo=remi install GeoIP-devel -y || error_exit "Failed to install GeoIP-devel package from remi repository"
    log_message "Necessary packages installed"
    ```

5. **Клонирование и установка ModSecurity**:
    ```bash
    git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity /usr/local/src/ModSecurity/  || error_exit "Failed to clone ModSecurity repository"
    cd /usr/local/src/ModSecurity/
    git submodule init
    git submodule update
    ./build.sh && ./configure && make -j"$(($(nproc) / 2))" && make install || error_exit "Failed to build and install ModSecurity"
    log_message "ModSecurity built and installed"
    ```

6. **Клонирование и компиляция модуля ModSecurity для Nginx**:
    ```bash
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git $modsecurity_nginx_dir || error_exit "Failed to clone ModSecurity-nginx repository"
    cd /usr/local/src/nginx/
    nginx_version=$(nginx -v 2>&1 | cut -d '/' -f 2)
    nginx_tar="nginx-$nginx_version.tar.gz"
    wget "http://nginx.org/download/$nginx_tar" || error_exit "Failed to download nginx source code"
    tar xfz $nginx_tar || error_exit "Failed to extract nginx source code"
    cd "nginx-$nginx_version"
    ./configure --with-compat --add-dynamic-module=$modsecurity_nginx_dir --with-ld-opt="-L$modsecurity_lib_dir" --with-cc-opt="-I$modsecurity_include_dir" || error_exit "Failed to configure nginx with ModSecurity module"
    make modules && cp objs/ngx_http_modsecurity_module.so /usr/lib64/nginx/modules/ || error_exit "Failed to make and copy ModSecurity module to nginx modules directory"
    log_message "Nginx configured with ModSecurity module"
    ```

7. **Настройка Nginx для использования ModSecurity**:
    ```bash
    sed -i '8a include /usr/share/nginx/modules/*.conf;' /etc/nginx/nginx.conf || error_exit "Failed to update nginx.conf"
    sed -i '30a#\n    modsecurity on;\n    modsecurity_rules_file /etc/nginx/modsecurity.d/modsecurity.conf;' /etc/nginx/nginx.conf || error_exit "Failed to update nginx.conf"
    log_message "Nginx.conf updated with ModSecurity module and rules"
    ```

8. **Очистка временных файлов и перезапуск Nginx**:
    ```bash
    rm -rf /usr/local/src/* || error_exit "Failed to clean up downloaded source files"
    log_message "Downloaded source files cleaned up"
    systemctl restart nginx || warn "Failed to restart nginx service"
    log_message "Nginx service restarted"
    ```

## Завершение

После успешного выполнения скрипта будет выведено сообщение о завершении установки:
```bash
echo "Setup completed successfully"
```

Вы можете найти лог файл установки по пути `/var/log/install-modsecurity3-for-Nginx.log`.

## Обновление правил OWASP

Команда "Обновление правил OWASP" загружает сценарий оболочки (`upgrade-rules.sh`) из репозитория GitHub (`https://github.com/unixweb-info/ModSecurity3-installation-script-for-Nginx/blob/main/upgrade-rules.sh`), устанавливает разрешения на выполнение скрипта, используя `sudo chmod +x`, а затем выполняет скрипт (`./upgrade-rules.sh`). Этот процесс обновляет правила OWASP ModSecurity для веб-серверов Nginx.

```bash
wget https://github.com/unixweb-info/ModSecurity3-installation-script-for-Nginx/blob/main/upgrade-rules.sh && sudo chmod+x ./upgrade-rules.sh && sudo ./upgrade-rules.sh
```

## Контакт

Для получения дополнительной информации или вопросов по скрипту вы можете связаться со мной по следующим контактам:

- **Telegram**: [UnixWebAdmin_info](https://t.me/UnixWebAdmin_info)
- **WhatsApp**: +995 593-245-168
- **Веб-сайт**: [UnixWeb.info](https://UnixWeb.info)

Готов оказать поддержку и консультацию по настройке и использованию скрипта для вашего сервера.

## Лицензия

Этот проект распространяется по лицензии MIT.

---

Автор Крячко Алексей © 2024. Наслаждайтесь использованием скрипта установки ModSecurity3 для Nginx!
