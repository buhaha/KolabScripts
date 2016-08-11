#!/bin/bash

dist="unknown"
if [ `which yum` ]; then
  dist="CentOS"
  if [[ ! `which wget` || ! `which patch` ]]; then
    yum -y install wget patch
  fi
else
  if [ `which apt-get` ]; then
    dist="Debian"
    if [[ ! `which wget` || ! `which patch` ]]; then
      apt-get -y install wget patch;
    fi
  else echo "Neither yum nor apt-get available. On which platform are you?";
  exit 0
  fi
fi

#####################################################################################
# apply a couple of patches, see related kolab bugzilla number in filename, eg. https://issues.kolab.org/show_bug.cgi?id=2018
#####################################################################################
# different paths in debian and centOS
# Debian
pythonDistPackages=/usr/lib/python2.7/dist-packages
if [ ! -d $pythonDistPackages ]; then
  # centOS6
  pythonDistPackages=/usr/lib/python2.6/site-packages
  if [ ! -d $pythonDistPackages ]; then
    # centOS7
    pythonDistPackages=/usr/lib/python2.7/site-packages
  fi
fi

echo "applying setupkolab_yes_quietBug2598.patch to $pythonDistPackages/pykolab"
patch -p1 -i `pwd`/patches/setupkolab_yes_quietBug2598.patch -d $pythonDistPackages/pykolab || exit -1
echo "applying setupkolab_mysqlserverBug4971.patch"
patch -p1 -i `pwd`/patches/setupkolab_mysqlserverBug4971.patch -d $pythonDistPackages/pykolab || exit -1
echo "applying setupkolab_directory_manager_pwdBug2645.patch"
patch -p1 -i `pwd`/patches/setupkolab_directory_manager_pwdBug2645.patch -d $pythonDistPackages || exit -1
echo "applying cmdSyncSingleDomainBug5091.patch"
patch -p1 -i `pwd`/patches/cmdSyncSingleDomainBug5091.patch -d $pythonDistPackages || exit -1
echo "installing domain delete script"
mkdir -p /usr/share/kolab-webadmin/bin
touch /usr/share/kolab-webadmin/bin/domain_delete.php
patch -p1 -i `pwd`/patches/fixDomainDeleteBug5100.patch -d /usr/share/kolab-webadmin || exit -1

echo "fixing problem with importing Domains from Kolab2"
patch -p1 -i `pwd`/patches/fixDomainImport.patch -d /usr/share/kolab-webadmin || exit -1

echo "applying patch for Roundcube Kolab plugin for storage in MariaDB"
patch -p1 -i `pwd`/patches/roundcubeStorageMariadbBug4883.patch -d /usr/share/roundcubemail || exit -1

if [ -f /usr/lib/cyrus-imapd/cvt_cyrusdb_all ]
then
  echo "temporary fixes for Cyrus stop script"
  patch -p1 -d /usr/lib/cyrus-imapd -i `pwd`/patches/fixcyrusstop.patch || exit -1
fi
echo "applying patch for waiting after restart of dirsrv (necessary on Debian)"
patch -p1 -i `pwd`/patches/setupKolabSleepDirSrv.patch -d $pythonDistPackages || exit -1

# backported from upstream master:
echo "applying kolabsyncBug3975.patch to $pythonDistPackages/pykolab"
patch -p2 -i `pwd`/patches/kolabsyncBug3975.patch -d $pythonDistPackages/pykolab || exit -1
echo "applying wap-password-complexity-policy-bug4988.patch"
patch -p1 -i `pwd`/patches/wap-password-complexity-policy-bug4988.patch -d /usr/share/kolab-webadmin
echo "applying backport_checkbox_value_bug4815.patch"
patch -p1 -i `pwd`/patches/backport_checkbox_value_bug4815.patch -d /usr/share/kolab-webadmin
echo "applying backport fix for deletion domain from cli"
patch -p2 -i `pwd`/patches/domainDeleteForceBug5098.patch -d $pythonDistPackages/pykolab || exit -1
echo "applying packport fix for timeout issues of pykolab wapclient"
patch -p2 -i `pwd`/patches/backport_timeoutissue_wapclient.patch -d $pythonDistPackages/pykolab || exit -1

# need to fix alias: type=list also in formfields. see https://issues.kolab.org/show_bug.cgi?id=2219#c8
sed -i 's#\\"form_fields\\":{\\"alias\\":{\\"optional\\":true}#\\"form_fields\\":{\\"alias\\":{\\"type\":\\"list\\",\\"optional\\":true}#g' /usr/share/doc/kolab-webadmin-3.2.6/kolab_wap.sql

# TODO on Debian, we need to install the rewrite for the csrf token
if [ -f /etc/apache2/sites-enabled/000-default ]
then
      newConfigLines="\tRewriteEngine On\n \
\tRewriteRule ^/roundcubemail/[a-f0-9]{16}/(.*) /roundcubemail/\$1 [PT,L]\n \
\tRewriteRule ^/webmail/[a-f0-9]{16}/(.*) /webmail/\$1 [PT,L]\n \
\tRedirectMatch ^/$ /roundcubemail/\n"

#      sed -i -e "s~</VirtualHost>~$newConfigLines</VirtualHost>~" /etc/apache2/sites-enabled/000-default
fi
