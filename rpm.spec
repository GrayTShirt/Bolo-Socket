%define modulename Bolo::Socket

Name:          perl-Bolo-Socket
Provides:      perl(Bolo::Socket)
Obsoletes:     perl-Bolo-Socket
Version:       0.02
Release:       2%{?_dist}
Summary:       ZMQ wrapper to connect to Bolo endpoints
URL:           https://github.com/GrayTShirt/Bolo-Socket
License:       GPLv3
Group:         Development/Libraries

BuildRoot:     %{_tmppath}/%{name}-root
BuildArch:     noarch
Source0:       https://github.com/GrayTShirt/Bolo-Socket/archive/Bolo-Socket-%{version}.tar.gz

BuildRequires: perl(ExtUtils::MakeMaker)
BuildRequires: perl(Test::More)

%description
ZMQ wrapper to connect to Bolo endpoints

%prep
%setup -q -n Bolo-Socket-%{version}

%build
CFLAGS="$RPM_OPT_FLAGS" perl Makefile.PL INSTALLDIRS=vendor INSTALL_BASE=''
make

%check
make test

%clean
rm -rf $RPM_BUILD_ROOT

%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT
if [ -d rpm_files ]; then cp -r rpm_files/* $RPM_BUILD_ROOT; fi

[ -x /usr/lib/rpm/brp-compress ] && /usr/lib/rpm/brp-compress

find $RPM_BUILD_ROOT -name .packlist     -print0 | xargs -0 /bin/rm -f
find $RPM_BUILD_ROOT -name perllocal.pod -print0 | xargs -0 /bin/rm -f
find $RPM_BUILD_ROOT -name rpm_files     -print0 | xargs -0 /bin/rm -fr

find $RPM_BUILD_ROOT -type f -print | \
    sed "s@^$RPM_BUILD_ROOT@@g" | \
    grep -v perllocal.pod | \
    grep -v "\\.packlist" > %{modulename}-%{version}-filelist

if [ "$(cat %{modulename}-%{version}-filelist)X" = "X" ] ; then
    echo "ERROR: EMPTY FILE LIST"
    exit -1
fi


%files -f %{modulename}-%{version}-filelist
%defattr(-,root,root)
