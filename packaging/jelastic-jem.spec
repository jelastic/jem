Name:           jelastic-jem
Version:        %{?rpm_version}%{!?rpm_version:0.0.0}
Release:        %{?rpm_release}%{!?rpm_release:1}
Summary:        Jelastic environment management core
License:        Apache-2.0
BuildArch:      noarch
%global debug_package %{nil}
%global __brp_mangle_shebangs %{nil}
AutoReq:        no

Requires:       /bin/sh
Requires:       bind-utils
Requires:       logrotate
Requires:       net-tools
Requires:       policycoreutils
Requires:       rpcbind

Source0:        %{name}-%{version}.tar.gz

%description
Jelastic environment management command, modules, libraries, and runtime
configuration shared by application containers and hard nodes.

%prep
%setup -q

%build
# Shell package; no compilation is required.

%install
rm -rf %{buildroot}

install -d %{buildroot}/etc/jelastic %{buildroot}/etc/logrotate.d
install -d -m0755 %{buildroot}/etc/profile.d
install -d -m0750 %{buildroot}/etc/sudoers.d
install -d %{buildroot}/root %{buildroot}/usr/bin
install -d -m0500 %{buildroot}/usr/lib/jelastic/libs
install -d -m0500 %{buildroot}/usr/lib/jelastic/modules
install -d -m0500 %{buildroot}/usr/lib/jelastic/tpls
install -d %{buildroot}/var/lib/jelastic/libs
install -d -m0755 %{buildroot}/var/lib/jelastic/overrides

install -m0644 etc/jelastic/export.conf etc/jelastic/jelastic.conf \
    etc/jelastic/timeouts.conf %{buildroot}/etc/jelastic/
install -m0644 etc/logrotate.d/jemlog %{buildroot}/etc/logrotate.d/jemlog
install -m0755 etc/profile.d/history.sh %{buildroot}/etc/profile.d/history.sh
install -m0750 etc/sudoers.d/jelastic %{buildroot}/etc/sudoers.d/jelastic
install -m0700 root/.vimrc %{buildroot}/root/.vimrc
install -m0755 usr/bin/jem %{buildroot}/usr/bin/jem

install -m0400 usr/lib/jelastic/libs/* %{buildroot}/usr/lib/jelastic/libs/
install -m0400 usr/lib/jelastic/modules/* %{buildroot}/usr/lib/jelastic/modules/
install -m0400 usr/lib/jelastic/tpls/* %{buildroot}/usr/lib/jelastic/tpls/
install -m0755 var/lib/jelastic/libs/* %{buildroot}/var/lib/jelastic/libs/
install -m0755 var/lib/jelastic/overrides/* %{buildroot}/var/lib/jelastic/overrides/

%post
if [ ! -d "/var/lib/jelastic/" ] 
then
     mkdir -p /var/lib/jelastic
fi
[ -f /etc/sudoers ] && sed -i  "s/^\s*Defaults\s*requiretty/\#Defaults  requiretty/" /etc/sudoers

bashrcfile="/root/.bashrc"

[ -e $bashrcfile ] && sed  -i "/export LC_ALL=/d" $bashrcfile;

if ! grep -qP "LC_ALL=\"en_US.UTF-8\"" ${bashrcfile}
then
     #~ add defaut locale
     echo "export LC_ALL=\"en_US.UTF-8\"" >> $bashrcfile ;
fi

GREP=`which grep`
SED=`which sed`
sshfile="/etc/ssh/sshd_config";
if [ -f "${sshfile}" ]  ; then
if $GREP -qE "^Banner.*$" "${sshfile}"; then
        $SED -i 's/^Banner.*$/Banner \/etc\/jmotd/g' "${sshfile}"
else
    if $GREP -qE "^\#Banner.*$" "${sshfile}"; then
        $SED -i 's/^\#Banner.*$/Banner \/etc\/jmotd/g' "${sshfile}"
    else
        echo "Banner /etc/jmotd" >> ${sshfile};
    fi
fi
fi
if [ ! -f /etc/exports ]
then
    /usr/bin/touch /etc/exports
    /bin/chmod 0666 /etc/exports
fi


if [ -f /usr/bin/jem ]
then
    /bin/chmod 511 /usr/bin/jem
    /bin/chown root:root /usr/bin/jem
fi
/bin/chmod 750 /etc/sudoers.d
if [ -f /etc/sudoers.d/jelastic ]
then
    /bin/chmod 640 /etc/sudoers.d/jelastic
fi

[ -f /var/lib/jelastic/libs/gitssh.sh ] && { chmod a+x /var/lib/jelastic/libs/gitssh.sh ; }


[ ! -L  /usr/lib/jelastic/libs/envinfo.lib ] && { rm -f /usr/lib/jelastic/libs/envinfo.lib; ln -s /var/lib/jelastic/libs/envinfo.lib /usr/lib/jelastic/libs/envinfo.lib ; } ;
[ ! -L  /usr/lib/jelastic/libs/cartridge-sdk.lib ] && { rm -f /usr/lib/jelastic/libs/cartridge-sdk.lib; ln -s /var/lib/jelastic/libs/cartridge-sdk.lib /usr/lib/jelastic/libs/cartridge-sdk.lib ; } ;

if [ -f /usr/lib/jelastic/modules/docker.module ]; then
    echo "" > /etc/jmotd
else
echo "
  Welcome!

  This shell will assist you in managing your applications.

    ============================== ATTENTION ==============================
   Shell access is rather powerful and you can accidentally damage your application. 
   So please pay special attention to the actions you perform here.
    ============================== ATTENTION ==============================

"> /etc/jmotd
fi

%files
%defattr(-,root,root,-)
%attr(0644,root,root) /etc/jelastic/export.conf
%attr(0644,root,root) /etc/jelastic/jelastic.conf
%attr(0644,root,root) /etc/jelastic/timeouts.conf
%attr(0644,root,root) /etc/logrotate.d/jemlog
%dir %attr(0755,root,root) /etc/profile.d
%attr(0755,root,root) /etc/profile.d/history.sh
%dir %attr(0750,root,root) /etc/sudoers.d
%attr(0750,root,root) /etc/sudoers.d/jelastic
%attr(0700,root,root) /root/.vimrc
%attr(0755,root,root) /usr/bin/jem
%dir %attr(0500,root,root) /usr/lib/jelastic
%dir %attr(0500,root,root) /usr/lib/jelastic/libs
%attr(0400,root,root) /usr/lib/jelastic/libs/*
%dir %attr(0500,root,root) /usr/lib/jelastic/modules
%attr(0400,root,root) /usr/lib/jelastic/modules/*
%dir %attr(0500,root,root) /usr/lib/jelastic/tpls
%attr(0400,root,root) /usr/lib/jelastic/tpls/*
%attr(0755,root,root) /var/lib/jelastic/libs/*
%dir %attr(0755,root,root) /var/lib/jelastic/overrides
%attr(0755,root,root) /var/lib/jelastic/overrides/*

%changelog
* Mon Nov 02 2026 Andrey Mozharovsky <andrii.mozharovskyi@virtuozzo.com> - 0.0.0-1
- Add repository-owned EL7 and EL10 RPM packaging with legacy payload parity.
