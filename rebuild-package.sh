#!/bin/bash
# disable proxy
unset http_proxy
unset no_proxy 
unset https_proxy

# install rpm devtools
cd /home
swupd update --quiet -W20 --retry-delay=1
swupd bundle-add curl dnf git --quiet 
git clone https://github.com/clearfraction/"$1".git && mv "$1"/* .
# manage dependencies
shopt -s expand_aliases && alias dnf='dnf -q -y --releasever=latest --disableplugin=changelog,needs_restarting'
dnf config-manager --add-repo https://cdn.download.clearlinux.org/current/x86_64/os --add-repo https://cdn-alt.download.clearlinux.org/current/x86_64/os --add-repo https://download.clearlinux.org/current/x86_64/os
echo -e "[main]\nmax_parallel_downloads=20\nretries=30\nfastestmirror=True" >> /etc/dnf/dnf.conf
dnf groupinstall build srpm-build && dnf install createrepo_c
[ -d "/tmp/repository" ] && createrepo_c --database /tmp/repository && dnf config-manager --add-repo /tmp/repository
dnf builddep *.spec || { echo "Failed to handle build dependencies"; exit 1; }


# enable x86_64-v3
sed -i '/^export CFLAGS=.*/ s/\ "/ -march=x86-64-v3 -m64 -Wl,-z,x86-64-v3\ "/' *.spec
sed -i '/^export CXXFLAGS=.*/ s/\ "/ -march=x86-64-v3 -m64 -Wl,-z,x86-64-v3\ "/' *.spec
sed -i '/^export FFLAGS=.*/ s/\ "/ -march=x86-64-v3 -m64-Wl,-z,x86-64-v3\ "/' *.spec
sed -i '/^export FCFLAGS=.*/ s/\ "/ -march=x86-64-v3 -m64\ "/' *.spec
sed -i '/^export LDFLAGS=.*/ s/\ "/ -march=x86-64-v3 -m64\ "/' *.spec
sed -i '/^export RUSTFLAGS=.*/ s/-C target-cpu=westmere/-C target-cpu=haswell/' *.spec
sed -i '/^export RUSTFLAGS=.*/ s/-C target-feature=+avx/-C target-feature=+avx,+avx2,+fma/' *.spec


# build the package
echo 'exit 0' > /usr/lib/rpm/clr/brp-create-abi
rpmbuild --quiet -bb *.spec --define "_topdir $PWD" \
         --define "_sourcedir $PWD" --undefine=_disable_source_fetch \
         --define "abi_package %{nil}" ||  { echo "Build failed"; exit 1; }

# deployment
count=`ls -1 $PWD/RPMS/*/*.rpm 2>/dev/null | wc -l`
if [ $count != 0 ]
then
echo "Start deployment..."
[ ! -d "/tmp/repository" ] && mkdir /tmp/repository
mv $PWD/RPMS/*/*.rpm /tmp/repository
fi 
