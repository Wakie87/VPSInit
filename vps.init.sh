#!/bin/bash
#=================================================================================#
#        MagenX e-commerce stack for Magento 2                                    #
#        Copyright (C) 2013-2020 admin@magenx.com                                 #
#        All rights reserved.                                                     #
#=================================================================================#
SELF=$(basename $0)
MAGENX_VER="2.8.240.1"
MAGENX_BASE="https://magenx.sh"

# Config path
MAGENX_CONFIG_PATH="/opt/magenx/config"

###################################################################################
###                            DEFINE LINKS AND PACKAGES                        ###
###################################################################################

# CentOS version lock
CENTOS_VERSION="8"

# ELK version lock
ELKREPO="7.x"

# Magento
MAGE_VERSION="2"
MAGE_VERSION_FULL=$(curl -s https://api.github.com/repos/magento/magento${MAGE_VERSION}/tags 2>&1 | head -3 | grep -oP '(?<=")\d.*(?=")')
REPO_MAGE="composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition"
COMPOSER_VERSION="1.10.16"

# Repositories
REPO_PERCONA="https://repo.percona.com/yum/percona-release-latest.noarch.rpm"
REPO_REMI="http://rpms.famillecollet.com/enterprise/remi-release-${CENTOS_VERSION}.rpm"

# WebStack Packages
EXTRA_PACKAGES="autoconf automake dejavu-fonts-common dejavu-sans-fonts libtidy libpcap gettext-devel recode gflags tbb ed lz4 libyaml libdwarf bind-utils e2fsprogs svn screen gcc iptraf inotify-tools iptables smartmontools net-tools mlocate unzip vim wget curl sudo bc mailx clamav-filesystem clamav-server clamav-update clamav-milter-systemd clamav-data clamav-server-systemd clamav-scanner-systemd clamav clamav-milter clamav-lib logrotate git patch ipset strace rsyslog ncurses-devel GeoIP GeoIP-devel geoipupdate openssl-devel ImageMagick libjpeg-turbo-utils pngcrush jpegoptim moreutils lsof net-snmp net-snmp-utils xinetd python3-virtualenv python3-wheel-wheel python3-pip python3-devel ncftp postfix augeas-libs libffi-devel mod_ssl dnf-automatic sysstat libuuid-devel uuid-devel attr iotop expect unixODBC gcc-c++"
PHP_PACKAGES=(cli common fpm opcache gd curl mbstring bcmath soap mcrypt mysqlnd pdo xml xmlrpc intl gmp gettext-gettext phpseclib recode symfony-class-loader symfony-common tcpdf tcpdf-dejavu-sans-fonts tidy snappy lz4) 
PHP_PECL_PACKAGES=(pecl-redis pecl-lzf pecl-geoip pecl-zip pecl-memcache pecl-oauth)
PERL_MODULES=(LWP-Protocol-https Config-IniFiles libwww-perl CPAN Template-Toolkit Time-HiRes ExtUtils-CBuilder ExtUtils-Embed ExtUtils-MakeMaker TermReadKey DBI DBD-MySQL Digest-HMAC Digest-SHA1 Test-Simple Moose Net-SSLeay devel)

# Nginx extra configuration
REPO_MAGENX_TMP="https://raw.githubusercontent.com/magenx/Magento-2-server-installation/master/"
NGINX_VERSION=$(curl -s http://nginx.org/en/download.html | grep -oP '(?<=gz">nginx-).*?(?=</a>)' | head -1)
NGINX_BASE="https://raw.githubusercontent.com/magenx/Magento-nginx-config/master/"
GITHUB_REPO_API_URL="https://api.github.com/repos/magenx/Magento-nginx-config/contents/magento2"

# Debug Tools
MYSQL_TUNER="https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl"
MYSQL_TOP="https://raw.githubusercontent.com/magenx/Magento-mysql/master/mytop"

###################################################################################
###                                    COLORS                                   ###
###################################################################################

RED="\e[31;40m"
GREEN="\e[32;40m"
YELLOW="\e[33;40m"
WHITE="\e[37;40m"
BLUE="\e[0;34m"
### Background
DGREYBG="  \e[100m"
BLUEBG="  \e[1;44m"
REDBG="  \e[41m"
### Styles
BOLD="\e[1m"
### Reset
RESET="\e[0m"

###################################################################################
###                            ECHO MESSAGES DESIGN                             ###
###################################################################################

function WHITETXT() {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "  ${WHITE}${MESSAGE}${RESET}"
}
function BLUETXT() {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "  ${BLUE}${MESSAGE}${RESET}"
}
function REDTXT() {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "  ${RED}${MESSAGE}${RESET}"
}
function GREENTXT() {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "  ${GREEN}${MESSAGE}${RESET}"
}
function YELLOWTXT() {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "  ${YELLOW}${MESSAGE}${RESET}"
}
function BLUEBG() {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "${BLUEBG}${MESSAGE}${RESET}"
}

###################################################################################
###                            PROGRESS BAR AND PAUSE                           ###
###################################################################################

function pause() {
   read -p "  $*"
}
function start_progress {
  while true
  do
    echo -ne "#"
    sleep 1
  done
}
function quick_progress {
  while true
  do
    echo -ne "#"
    sleep 0.05
  done
}
function long_progress {
  while true
  do
    echo -ne "#"
    sleep 3
  done
}

function stop_progress {
kill $1
wait $1 2>/dev/null
echo -en "\n"
}

include_config () {
    [[ -f "$1" ]] && . "$1"
}

_echo () {
  echo -en "  $@"
}

###################################################################################
###                            ARROW KEYS UP/DOWN MENU                          ###
###################################################################################

updown_menu () {
i=1;for items in $(echo $1); do item[$i]="${items}"; let i=$i+1; done
i=1
echo -e "\n---> Use up/down arrow keys then press Enter to select $2"
while [ 0 ]; do
  if [ "$i" -eq 0 ]; then i=1; fi
  if [ ! "${item[$i]}" ]; then let i=i-1; fi
  echo -en "\r                                 " 
  echo -en "\r${item[$i]}"
  read -sn 1 selector
  case "${selector}" in
    "B") let i=i+1;;
    "A") let i=i-1;;
    "") echo; read -sn 1 -p "To confirm [ ${item[$i]} ] press y or n for new selection" confirm
      if [[ "${confirm}" =~ ^[Yy]$  ]]; then
        printf -v "$2" '%s' "${item[$i]}"
        break
      else
        echo
        echo -e "\n---> Use up/down arrow keys then press Enter to select $2"
      fi
      ;;
  esac
done }

clear
###################################################################################
###                              CHECK IF WE CAN RUN IT                         ###
###################################################################################

echo
echo
# root?
if [[ ${EUID} -ne 0 ]]; then
  echo
  REDTXT "[!] THIS SCRIPT MUST BE RUN AS ROOT!"
  YELLOWTXT "[!] USE SUPER-USER PRIVILEGES."
  exit 1
  else
  GREENTXT "PASS: ROOT!"
fi

# some selinux, sir?
if [ ! -f "${MAGENX_CONFIG_PATH}/selinux" ]; then
  mkdir -p ${MAGENX_CONFIG_PATH}
  SELINUX=$(awk -F "=" '/^SELINUX=/ {print $2}' /etc/selinux/config)
    if [[ ! "${SELINUX}" =~ (disabled|permissive) ]]; then
    echo
    REDTXT "[!] SELINUX IS NOT DISABLED OR PERMISSIVE"
    YELLOWTXT "[!] PLEASE CHECK YOUR SELINUX SETTINGS"
    echo
    echo "  [!] System will be configured with SELinux if you answer 'n'"
    echo
    _echo "[?] Would you like to disable SELinux and reboot ?  [y/n][y]:"
    read selinux_disable
    if [ "${selinux_disable}" == "y" ];then
      sed -i "s/SELINUX=${SELINUX}/SELINUX=disabled/" /etc/selinux/config
      echo "disabled" > ${MAGENX_CONFIG_PATH}/selinux
      reboot
    else
   echo
  GREENTXT "PASS: SELINUX IS ${SELINUX^^}"
  echo "${SELINUX}" > ${MAGENX_CONFIG_PATH}/selinux
  ## selinux
  if grep -q "enforcing" ${MAGENX_CONFIG_PATH}/selinux >/dev/null 2>&1 ; then
   ## selinux config
   setsebool -P httpd_can_network_connect true
   setsebool -P httpd_setrlimit true
   setsebool -P httpd_enable_homedirs true
   setsebool -P httpd_can_sendmail true
   setsebool -P httpd_execmem true
  fi
  fi
 fi
fi

# network is up?
host1=google.com
host2=github.com

RESULT=$(((ping -w3 -c2 ${host1} || ping -w3 -c2 ${host2}) > /dev/null 2>&1) && echo "up" || (echo "down" && exit 1))
if [[ ${RESULT} == up ]]; then
  GREENTXT "PASS: NETWORK IS UP. GREAT, LETS START!"
  else
  echo
  REDTXT "[!] NETWORK IS DOWN ?"
  YELLOWTXT "[!] PLEASE CHECK YOUR NETWORK SETTINGS."
  echo
  echo
  exit 1
fi

# check if you need update
    MD5_NEW=$(curl -sL ${MAGENX_BASE} > magenx.sh.new && md5sum magenx.sh.new | awk '{print $1}')
        MD5=$(md5sum ${SELF} | awk '{print $1}')
            if [[ "${MD5_NEW}" == "${MD5}" ]]; then
            GREENTXT "PASS: INTEGRITY CHECK FOR '${SELF}' OK"
            rm magenx.sh.new
            elif [[ "${MD5_NEW}" != "${MD5}" ]]; then
            echo
            YELLOWTXT "INTEGRITY CHECK FOR '${SELF}'"
            YELLOWTXT "DETECTED DIFFERENT MD5 CHECKSUM"
            YELLOWTXT "REMOTE REPOSITORY FILE HAS SOME CHANGES"
            REDTXT "IF YOU HAVE LOCAL CHANGES - SKIP UPDATES"
            echo
                _echo "[?] Would you like to update the file now?  [y/n][y]:"
		read update_agree
		if [ "${update_agree}" == "y" ];then
		mv magenx.sh.new ${SELF}
		echo
                GREENTXT "THE FILE HAS BEEN UPGRADED, PLEASE RUN IT AGAIN"
		echo
                exit 1
            else
        echo
        YELLOWTXT "NEW FILE SAVED TO magenx.sh.new"
        echo
  fi
fi


# do we have CentOS?
if grep "CentOS.* ${CENTOS_VERSION}\." /etc/centos-release > /dev/null 2>&1; then
  GREENTXT "PASS: CENTOS RELEASE ${CENTOS_VERSION}"
  else
  echo
  REDTXT "[!] UNABLE TO FIND CENTOS ${CENTOS_VERSION}"
  YELLOWTXT "[!] THIS CONFIGURATION FOR CENTOS ${CENTOS_VERSION}"
  echo
  exit 1
fi

# check if x64. if not, beat it...
ARCH=$(uname -m)
if [ "${ARCH}" = "x86_64" ]; then
  GREENTXT "PASS: 64-BIT"
  else
  echo
  REDTXT "[!] 32-BIT SYSTEM?"
  YELLOWTXT "[!] CONFIGURATION FOR 64-BIT ONLY."
  echo
  exit 1
fi

# check if memory is enough
TOTALMEM=$(awk '/MemTotal/ { print $2 }' /proc/meminfo)
if [ "${TOTALMEM}" -gt "3000000" ]; then
  GREENTXT "PASS: YOU HAVE ${TOTALMEM} Kb OF RAM"
  else
  echo
  REDTXT "[!] YOU HAVE LESS THAN 3Gb OF RAM"
  YELLOWTXT "[!] TO PROPERLY RUN COMPLETE STACK YOU NEED 4Gb+"
  echo
fi

# check if webstack is clean
if ! grep -q "webstack_is_clean" ${MAGENX_CONFIG_PATH}/webstack >/dev/null 2>&1 ; then
installed_packages="$(rpm -qa --qf '%{name} ' 'mysqld?|firewalld|Percona*|maria*|php-?|nginx*|*ftp*|varnish*|certbot*|redis*|webmin')"
  if [ ! -z "$installed_packages" ]; then
  REDTXT  "[!] WEBSTACK PACKAGES ALREADY INSTALLED"
  YELLOWTXT "[!] YOU NEED TO REMOVE THEM OR RE-INSTALL MINIMAL OS VERSION"
  echo
  echo -e "\t\t dnf remove ${installed_packages} --noautoremove"
  echo
  echo
  exit 1
    else
  mkdir -p ${MAGENX_CONFIG_PATH}
  echo "webstack_is_clean" > ${MAGENX_CONFIG_PATH}/webstack
  fi
fi

GREENTXT "PATH: ${PATH}"
echo
if ! grep -q "yes" ${MAGENX_CONFIG_PATH}/systest >/dev/null 2>&1 ; then
echo
BLUEBG "~    QUICK SYSTEM TEST    ~"
WHITETXT "-------------------------------------------------------------------------------------"
echo
    dnf -y install epel-release > /dev/null 2>&1
    dnf -y install time bzip2 tar > /dev/null 2>&1
    
    test_file=vpsbench__$$
    tar_file=tarfile
    now=$(date +"%m/%d/%Y")

    cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo )
    cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
    freq=$( awk -F: ' /cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo )
    tram=$( free -m | awk 'NR==2 {print $2}' )   
    echo  
    echo -n "  PROCESSING I/O PERFORMANCE "
    start_progress &
    pid="$!"
    io=$( ( dd if=/dev/zero of=$test_file bs=64k count=16k conv=fdatasync && rm -f $test_file ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
    stop_progress "$pid"

    echo -n "  PROCESSING CPU PERFORMANCE "
    dd if=/dev/urandom of=$tar_file bs=1024 count=25000 >>/dev/null 2>&1
    start_progress &
    pid="$!"
    tf=$( (/usr/bin/time -f "%es" tar cfj $tar_file.bz2 $tar_file) 2>&1 )
    stop_progress "$pid"
    rm -f tarfile*
    echo
    echo

    if [ ${io% *} -ge 250 ] ; then
        IO_COLOR="${GREEN}$io - excellent result"
    elif [ ${io% *} -ge 200 ] ; then
        IO_COLOR="${YELLOW}$io - average result"
    else
        IO_COLOR="${RED}$io - very bad result"
    fi

    if [ ${tf%.*} -ge 10 ] ; then
        CPU_COLOR="${RED}$tf - very bad result"
    elif [ ${tf%.*} -ge 5 ] ; then
        CPU_COLOR="${YELLOW}$tf - average result"
    else
        CPU_COLOR="${GREEN}$tf - excellent result"
    fi

  WHITETXT "${BOLD}SYSTEM DETAILS"
  WHITETXT "CPU model: $cname"
  WHITETXT "Number of cores: $cores"
  WHITETXT "CPU frequency: $freq MHz"
  WHITETXT "Total amount of RAM: $tram MB"
  echo
  WHITETXT "${BOLD}BENCHMARKS RESULTS"
  WHITETXT "[I/O speed]: ${IO_COLOR}"
  WHITETXT "[CPU Time]: ${CPU_COLOR}"

echo
mkdir -p ${MAGENX_CONFIG_PATH} && echo "yes" > ${MAGENX_CONFIG_PATH}/systest
echo
pause "[] Press [Enter] key to proceed"
echo
fi
echo
# ssh test
if ! grep -q "yes" ${MAGENX_CONFIG_PATH}/sshport >/dev/null 2>&1 ; then
      touch ${MAGENX_CONFIG_PATH}/sshport
      echo
      sed -i "s/.*LoginGraceTime.*/LoginGraceTime 30/" /etc/ssh/sshd_config
      sed -i "s/.*MaxAuthTries.*/MaxAuthTries 6/" /etc/ssh/sshd_config     
      sed -i "s/.*X11Forwarding.*/X11Forwarding no/" /etc/ssh/sshd_config
      sed -i "s/.*PrintLastLog.*/PrintLastLog yes/" /etc/ssh/sshd_config
      sed -i "s/.*TCPKeepAlive.*/TCPKeepAlive yes/" /etc/ssh/sshd_config
      sed -i "s/.*ClientAliveInterval.*/ClientAliveInterval 600/" /etc/ssh/sshd_config
      sed -i "s/.*ClientAliveCountMax.*/ClientAliveCountMax 3/" /etc/ssh/sshd_config
      sed -i "s/.*UseDNS.*/UseDNS no/" /etc/ssh/sshd_config
      sed -i "s/.*PrintMotd.*/PrintMotd yes/" /etc/ssh/sshd_config
      
      echo
      SSH_PORT="$(awk '/#?Port [0-9]/ {print $2}' /etc/ssh/sshd_config)"
      if [ "${SSH_PORT}" == "22" ]; then
        REDTXT "[!] DEFAULT SSH PORT :22 DETECTED"
	 cp /etc/ssh/sshd_config /etc/ssh/sshd_config.BACK
          SSH_PORT_NEW=$(shuf -i 9537-9554 -n 1)
         sed -i "s/.*Port 22/Port ${SSH_PORT_NEW}/g" /etc/ssh/sshd_config
	SSH_PORT=${SSH_PORT_NEW}
      fi
      SFTP_PORT=$(shuf -i 5121-5132 -n 1)
      sed -i "/^Port ${SSH_PORT}/a Port ${SFTP_PORT}" /etc/ssh/sshd_config
      
cat >> /etc/ssh/sshd_config <<END
# SFTP port configuration
Match LocalPort ${SFTP_PORT} User *,!root
ChrootDirectory %h
ForceCommand internal-sftp -u 0007 -l VERBOSE
PasswordAuthentication no
AllowTCPForwarding no
X11Forwarding no
END
     echo
        GREENTXT "SSH PORT AND SETTINGS WERE UPDATED  -  OK"
	echo
        GREENTXT "[!] SSH MAIN PORT: ${SSH_PORT}"
	echo
	if grep -q "enforcing" ${MAGENX_CONFIG_PATH}/selinux >/dev/null 2>&1 ; then
	## selinux config
	semanage port -a -t ssh_port_t -p tcp ${SSH_PORT}
	semanage port -a -t ssh_port_t -p tcp ${SFTP_PORT}
	fi
        systemctl restart sshd.service
        ss -tlp | grep sshd
     echo
echo
REDTXT "[!] IMPORTANT: NOW OPEN NEW SSH SESSION WITH THE NEW PORT!"
REDTXT "[!] IMPORTANT: DO NOT CLOSE YOUR CURRENT SESSION!"
echo
_echo "[?] Have you logged in another session? [y/n][n]:"
read ssh_test
if [ "${ssh_test}" == "y" ];then
      echo
        GREENTXT "[!] SSH MAIN PORT: ${SSH_PORT}"
	GREENTXT "[!] SFTP+CHROOT PORT: ${SFTP_PORT}"
	echo
        echo "# yes" > ${MAGENX_CONFIG_PATH}/sshport
	echo "SSH_PORT=${SSH_PORT}" >> ${MAGENX_CONFIG_PATH}/sshport
	echo "SFTP_PORT=${SFTP_PORT}" >> ${MAGENX_CONFIG_PATH}/sshport
	echo
	echo
	pause "[] Press [Enter] key to proceed"
        else
	echo
        mv /etc/ssh/sshd_config.BACK /etc/ssh/sshd_config
        REDTXT "RESTORING sshd_config FILE BACK TO DEFAULTS ${GREEN} [ok]"
        systemctl restart sshd.service
        echo
        GREENTXT "SSH PORT HAS BEEN RESTORED  -  OK"
	if grep -q "enforcing" ${MAGENX_CONFIG_PATH}/selinux >/dev/null 2>&1 ; then
	## selinux config
	semanage port -d -p tcp ${SSH_PORT}
	semanage port -d -p tcp ${SFTP_PORT}
	fi
        ss -tlp | grep sshd
fi
fi
echo
echo
###################################################################################
###                                  AGREEMENT                                  ###
###################################################################################
echo
if ! grep -q "yes" ${MAGENX_CONFIG_PATH}/terms >/dev/null 2>&1 ; then
printf "\033c"
echo
  YELLOWTXT "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo
  YELLOWTXT "BY INSTALLING THIS SOFTWARE AND BY USING ANY AND ALL SOFTWARE"
  YELLOWTXT "YOU ACKNOWLEDGE AND AGREE:"
  echo
  YELLOWTXT "THIS SOFTWARE AND ALL SOFTWARE PROVIDED IS PROVIDED AS IS"
  YELLOWTXT "UNSUPPORTED AND WE ARE NOT RESPONSIBLE FOR ANY DAMAGE"
  echo
  YELLOWTXT "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo
   echo
    _echo "[?] Do you agree to these terms ?  [y/n][y]:"
    read terms_agree
  if [ "${terms_agree}" == "y" ];then
    echo "yes" > ${MAGENX_CONFIG_PATH}/terms
          else
        REDTXT "Going out. EXIT"
        echo
    exit 1
  fi
fi
