#!/bin/bash
set -x
export today=$(date '+%Y%m%d')
export MASSOSLASTVER=`curl https://api.github.com/repos/MassOS-Linux/MassOS/releases/latest | grep tag_name | awk '{print $2}' | tr -d '"'  | tr -d ','` 
export MASSOSLASTVERURL=`curl https://api.github.com/repos/MassOS-Linux/MassOS/releases/latest | grep browser_download_url | grep -m1 .tar.xz | awk '{print $2}'| tr -d '"'`

build_massos_container () {
  massbuilderimage=`docker image ls | grep massbuilder | awk '{print $1":"$2}'`  
  if [[ $massbuilderimage == "" ]];then
    echo "no massos build found. Building..."
    docker import $MASSOSLASTVERURL massbuilder:$MASSOSLASTVER
  elif [[ $massbuilderimage != "massbuilder:$MASSOSLASTVER" ]];then
    echo "old massos build found. Removing it and building a new..."
    docker rmi -f $massbuilderimage
    docker import $MASSOSLASTVERURL massbuilder:$MASSOSLASTVER
  elif [[ $massbuilderimage == "massbuilder:$MASSOSLASTVER" ]];then
    echo "already last version of massos in use"
  fi
}

#create_packages (name, method, project_home, git_url, api_option, api_filter, depandancies, description, pre_install, post_install, pre_remove, post_remove, pre_upgrade, post_upgrade) 
create_packages () {
  export VARMAINTAINER="adrien@vgr.pw"
  export VARPKGARCH=x86_64
  export VARPKGNAME="${1}"
  method="${2}"
  export VARPKGHOMEPAGE="${3}"
  git_url="${4}"
  api_option="${5}"
  api_filter="${6}"
  if [[ ${7} == "none" ]];then
    export VARDEPS=" "
  else
    export VARDEPS="${7}"
  fi
  export VARPKGDESCRIPTION="${8}"
  pre_install="${9}"
  post_install="${10}"
  pre_remove="${11}"
  post_remove="${12}"
  pre_upgrade="${13}"
  post_upgrade="${14}"
  export VARBUILDTAGS="${15}"
  export VARPKGVERORI=`curl https://api.github.com/repos/$api_option/releases/latest | grep tag_name | awk '{print $2}' | tr -d '"'  | tr -d ','` 
  export VARPKGVER=`echo $VARPKGVERORI | sed 's/^v//'` 
  envsubst < templates/manifest.tpl > /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest

  if [[ $pre_install != "none" ]];then
    printf "pre_install() {\n" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$pre_install" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "\n}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  if [[ $post_install != "none" ]];then
    printf "post_install() {\n" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$post_install" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "\n}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  if [[ $pre_remove != "none" ]];then
    printf "pre_remove() {\n" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$pre_remove" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "\n}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  if [[ $post_remove != "none" ]];then
    printf "post_remove() {\n" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$post_remove" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "\n}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest  
  fi
  if [[ $pre_upgrade != "none" ]];then
    printf "pre_upgrade() {" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$pre_upgrade" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest  
  fi
  if [[ $post_upgrade != "none" ]];then
    printf "post_upgrade() {\n" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$post_upgrade" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "\n}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  if [[ $VARPKGNAME == "podman-rootless" ]];then
    export WORKDIR="podman"
  else
    export WORKDIR=$VARPKGNAME
  fi
  mkdir -p /tmp/$VARPKGNAME-$today/usr/local
  mkdir -p /tmp/$VARPKGNAME-$today/usr/bin
  mkdir -p /tmp/$VARPKGNAME-$today/usr/src  
  mkdir -p /tmp/$VARPKGNAME-$today/usr/share/glib-2.0/schemas/
  mkdir -p /tmp/$VARPKGNAME-$today/usr/share/tilix/resources
  mkdir -p /tmp/$VARPKGNAME-$today/usr/share/tilix/pkg/desktop
  mkdir -p /tmp/$VARPKGNAME-$today/usr/share/tilix/pkg/metainfo
  mkdir -p /tmp/$VARPKGNAME-$today/usr/share/tilix/metainfo
  mkdir -p /tmp/$VARPKGNAME-$today/usr/share/dbus-1/services
  mkdir -p /tmp/$VARPKGNAME-$today/usr/share/nautilus-python/extensions
  mkdir -p /tmp/$VARPKGNAME-$today/usr/share/icons
  mkdir -p /tmp/$VARPKGNAME-$today/usr/share/applications
  mkdir -p /tmp/$VARPKGNAME-$today/usr/share/licences
  mkdir -p /tmp/$VARPKGNAME-$today/usr/share/metainfo
  if [[ $method == "git" ]];then
    #export GOVERSION=$(curl -s https://go.dev/dl/?mode=json | jq -r '.[0].version')
    cd /tmp/$VARPKGNAME-$today/
    docker run --name massbuilder -d massbuilder:$MASSOSLASTVER sleep 3600 
    docker exec massbuilder bash -c 'curl -fsS https://dlang.org/install.sh | bash -s dmd'
    docker exec --workdir /opt massbuilder git clone $git_url
    docker exec --workdir /opt/$WORKDIR massbuilder git checkout $VARPKGVERORI
    docker exec --workdir /opt/$WORKDIR massbuilder bash -c 'source /root/dlang/dmd-2.100.0/activate; dub build --build=release'
    docker cp massbuilder:/opt/$WORKDIR/tilix usr/bin/tilix
    docker cp massbuilder:/opt/$WORKDIR/share/ usr/src/tilix/
    docker cp massbuilder:/opt/$WORKDIR/data usr/src/tilix
    docker cp massbuilder:/opt/$WORKDIR/po usr/src/tilix
    docker cp massbuilder:/opt/$WORKDIR/LICENSE usr/share/licences/tilix
    find /tmp/$VARPKGNAME-$today/usr/ -type f -exec strip --strip-all {} ';' &>/dev/null || true
    find /tmp/$VARPKGNAME-$today/usr/ -type f -name \*.a -or -name \*.o -exec strip --strip-debug {} ';' &>/dev/null || true
    find /tmp/$VARPKGNAME-$today/usr/ -type f -name \*.so\* -exec strip --strip-unneeded {} ';' &>/dev/null || true    chmod -R +x /tmp/$VARPKGNAME-$today/usr/bin/tilix
    tar -cJf $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz *
    cp $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz /var/www/massos-repo/x86_64/archives/
    docker rm -f massbuilder
    cd -
  elif [[ $method == "std" ]];then
    export VARDOWNLOAD=`curl https://api.github.com/repos/$api_option/releases/latest | grep browser_download_url | grep -m1 $api_filter | awk '{print $2}'| tr -d '"'`
    mkdir -p /tmp/$VARPKGNAME-$today/usr/local/bin/
    wget $VARDOWNLOAD -O /tmp/$VARPKGNAME-$today/usr/local/bin/$VARPKGNAME
    chmod -R +x /tmp/$VARPKGNAME-$today/usr/local/
    cd /tmp/$VARPKGNAME-$today/
    tar -cJf $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz *
    cp $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz /var/www/massos-repo/x86_64/archives/
    cd -
  fi
  rm -r /tmp/$VARPKGNAME-$today/
}

build_massos_container
#create_packages name method project_home git_url api_option api_filter depandancies description pre_install_cmd post_install_cmd pre_remove_cmd post_remove_cmd pre_upgrade_cmd post_upgrade_cmd buildargs
create_packages "tilix" "git" "https://gnunn1.github.io/tilix-web" "https://github.com/gnunn1/tilix.git" "gnunn1/tilix" "unused" "" "A tiling terminal emulator for Linux using GTK+ 3" "none" "  glib-compile-schemas /usr/src/tilix/gsettings \n cp /usr/src/tilix/gsettings/com.gexperts.Tilix.gschema.xml /usr/share/glib-2.0/schemas/com.gexperts.Tilix.gschema.xml \n  cd /usr/src/tilix/resources \n  glib-compile-resources tilix.gresource.xml  \n   cp /usr/src/tilix/resources/tilix.gresource /usr/share/tilix/resources \n   cd /usr/src/tilix \n  msgfmt --desktop --template=/usr/src/tilix/pkg/desktop/com.gexperts.Tilix.desktop.in -d po -o /usr/share/tilix/pkg/desktop/com.gexperts.Tilix.desktop  \n    msgfmt --xml --template=/usr/src/tilix/metainfo/com.gexperts.Tilix.appdata.xml.in -d po -o /usr/share/tilix/metainfo/com.gexperts.Tilix.appdata.xml \n for f in \`ls /usr/src/tilix/po/*.po\`;do\n   echo \"Processing \$f\" \n LOCALE=\`basename \"\$f\" .po\` \n msgfmt \$f -o \"\$LOCALE.mo\" \n install -Dm 644 \"\$LOCALE.mo\" \"/usr/share/locale/\$LOCALE/LC_MESSAGES/tilix.mo\" \n rm -f \"\$LOCALE.mo\" \n   done\n   cp /usr/share/tilix/pkg/desktop/com.gexperts.Tilix.desktop  /usr/share/applications\n   cp /usr/share/tilix/metainfo/com.gexperts.Tilix.appdata.xml /usr/share/metainfo/\n   xdg-desktop-menu forceupdate --mode system \n   cp -r /usr/src/tilix/scripts /usr/share/tilix\n   cp /usr/src/tilix/dbus/com.gexperts.Tilix.service /usr/share/dbus-1/services/\n   cp -r /usr/src/tilix/schemes/ /usr/share/tilix\n   cp /usr/share/tilix/resources/tilix.gresource /usr/share\n   cp /usr/src/tilix/gsettings/gschemas.compiled /usr/share\n   glib-compile-schemas /usr/share/glib-2.0/schemas\n   cp /usr/src/tilix/icons/hicolor/scalable/apps/com.gexperts.Tilix* /usr/share/icons/hicolor/scalable/apps/ \n   gtk-update-icon-cache -f \"/usr/share/icons/hicolor/\"" "none" "none" "none" "none" "none" "none" 
