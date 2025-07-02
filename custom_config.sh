#!/usr/bin/env bash
set -euo pipefail
set -x
. /etc/environment

USER_NAME=${USER_NAME:-kosh}
user_packages='docker docker-compose dive docker-buildx \
               qemu-base \
               pacman-contrib pacman-cleanup-hook downgrade\
               mc pigz polkit strace bc net-tools cpio etc-update ccache \
               ripgrep-all fzf bat-extras'

############## NEED TO ADD --disable-sandbox when flag will be in yay release ##################
yay_opts='--answerdiff None --answerclean None --noconfirm --needed'

if [ "$WSL_INSTALL" = "true" ]; then
    echo "Configuring wsl..."
    echo "[boot]
systemd=true
[user]
default=$USER_NAME
#[automount]
#enabled = true
#options = \"metadata\"
#mountFsTab = true
#[interop]
#appendWindowsPath = false
#autoMemoryReclaim=gradual
#networkingMode=mirrored
#dnsTunneling=true" > /etc/wsl.conf
    rm -f /etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
    rm -f /usr/lib/systemd/system/systemd-firstboot.service
    echo "" > /etc/fstab
    ## fix cgroup2 not mounted for docker
    echo "cgroup2 /sys/fs/cgroup cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate 0 0" > /etc/fstab
    ## fix mount x socket in wsl
    echo '[Unit]
Description=remount xsocket for wslg
After=network.target

[Service]
Type=simple
ExecStartPre=+/bin/bash -c "if [ -d /mnt/wslg/.X11-unix ]; then [ -d /tmp/.X11-unix ] && rm -rf /tmp/.X11-unix || true; fi"
ExecStart=/usr/sbin/ln -s /mnt/wslg/.X11-unix /tmp/
Restart=on-abort

[Install]
WantedBy=multi-user.target' >> /etc/systemd/system/wslg-tmp.service
    systemctl daemon-reload
    systemctl enable wslg-tmp.service
else
    ## changing grub config
    ## sed -i 's/GRUB_TIMEOUT_STYLE=menu/GRUB_TIMEOUT_STYLE=countdown/g' /etc/default/grub
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3"/g' /etc/default/grub
fi 

## PACMAN CONF
## enabling pacman from game
sed -i '/^\[options.*/a ILoveCandy' /etc/pacman.conf
## enabling parallel downloads in pacman
sed -i '/ParallelDownloads = 5/s/^#//g' /etc/pacman.conf
## enabling colors in pacman output
sed -i '/Color/s/^#//g' /etc/pacman.conf

## MAKEPKG CONF
## Optimizing build config
sed -i 's/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -z -q --threads=0 -)/g' /etc/makepkg.conf
## disable build debug package 
sed -i 's/OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge debug lto)/OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto)/g' /etc/makepkg.conf
## use max cpu cores for builds
sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(npoc)"/g' /etc/makepkg.conf


## installing yay
## dropping root user bacause makepkg and yay not working from root user
 su - $USER_NAME -c "git clone -q https://aur.archlinux.org/yay-bin && \
                         cd yay-bin && \
                         makepkg -si --noconfirm && \
                         cd .. && \
                         rm -rf yay-bin && \
                         yay -Y --gendb && \
                         yay -Syu --devel --noconfirm && \
                         yay -Y --devel --save && \
                         yay --editmenu --diffmenu=false --save"

## IMPORTANT NOTE ABOUT VULKAN ON WSL2!!! ##
## ArchWSL2 may not properly load the Intel WSL driver by default which makes it impossible to use the D3D12 driver on Intel graphics cards. 
## This is because the Intel WSL driver files link against libraries that do not exist in Archlinux. 
## You can manually fix this issue using ldd to see which libraries they are linked,
## eg: ldd /usr/lib/wsl/drivers/iigd_dch_d.inf_amd64_49b17bc90a910771/*.so, 
## and then try installing the libraries marked not found from the Archlinux package repository. 
## If the corresponding library file is not found in the package repository, it may be that the version suffix of the library file is different, 
## such as libedit.so.0.0.68 and libedit.so.2. In such a case, you can try to create a symlink.
## https://github.com/sileshn/ArchWSL2
## libedit is /usr/lib/libedit.so.0.0.72 (72 for now)
## libigdgmm.so.12 in intel-media-driver package

## IMPORTANT NOTE ABOUT D3D12 ON WSL2 IN ARCH LINUX !!!
## arch dev team build mesa without D3D12 support
## to use vulkan over d3d12 in arch you need to rebuild mesa or use mesa-wsl2-git package in aur

## installing packages 
su - "$USER_NAME" -c "yay -S $yay_opts $user_packages"
if [[ $user_packages == *docker* ]]; then
    ## админу локалхоста дозволено:)
    echo "adding user to docker group"    
    usermod -aG docker $USER_NAME
fi
## enabling ccache
if [[ $user_packages == *ccache* ]]; then
    echo "adding ccache config for makepkg"
    sed -i 's/BUILDENV=(!distcc color check !sign)/BUILDENV=(!distcc color ccache check !debug !sign)/g' /etc/makepkg.conf
fi 

## adding zsh
su - "$USER_NAME" -c "wget -qO - https://raw.githubusercontent.com/deathmond1987/zsh_with_programs/main/zsh_install.sh | bash"
if [[ $user_packages == *mc* ]]; then       
    ## changing default mc theme
    echo "adding mc config"
    ## fallback MC_SKIN=gotar skin
    MC_SKIN=modarcon16root-defbg
    echo "MC_SKIN=$MC_SKIN" >> /etc/environment
    echo "MC_SKIN=$MC_SKIN" >> /home/"$USER_NAME"/.zshrc
fi
## enabling hstr alias
echo "export HISTFILE=~/.zsh_history" >> /home/"$USER_NAME"/.zshrc

## change default zsh compilation dump to .config/zsh to avoid create compdump files in home dir
su - "$USER_NAME" -c "sed -i '1 i\## export ZDOTDIR=/home/$USER_NAME/.config/zsh' /home/$USER_NAME/.zshrc && mkdir -p /home/"$USER_NAME"/.config/zsh"



## fzf text search 
cat << 'EOF' >> /home/"$USER_NAME"/.zshrc
export BAT_THEME="Monokai Extended"
qsb() {
        RG_PREFIX="rg --files-with-matches"
        local file
                editor=${EDITOR:-micro}
        file="$(
                FZF_DEFAULT_COMMAND="$RG_PREFIX '$1'" \
                        fzf \
                        --preview="if [[ -n {} ]]; then if [[ -n {q} ]]; then batgrep --color=always --terminal-width=105 --context=3 {q} {}; else bat --color=always {}; fi; fi" \
                        --disabled --query "$1" \
                        --bind "change:reload:sleep 0.1; $RG_PREFIX {q}" \
                        --bind "f3:execute(bat --paging=always --pager=\"less -j4 -R -F +/{q}\" --color=always {} < /dev/tty > /dev/tty)" \
                        --bind "f4:execute("$editor" {})" \
                        --preview-window="70%:wrap"
        )" &&
        echo "$file"
}
EOF
       
## downloading tor fork for docker
cd /opt
git clone https://github.com/deathmond1987/tor_with_bridges.git
mv ./tor_with_bridges ./tor
cd -

## clone my gh repo
cd /home/"$USER_NAME"/
mkdir -p ./.git && cd ./.git
GH_USER=${GH_USER:=deathmond1987}
PROJECT_LIST=$(curl -s https://api.github.com/users/"$GH_USER"/repos\?page\=1\&per_page\=100 | grep -e 'clone_url' | cut -d \" -f 4 | sed '/WSA/d' | xargs -L1)
for project in ${PROJECT_LIST}; do
    project_name=$(echo "${project}" | cut -d'/' -f 5)
    echo "[ $project_name ] start..."
    if [ -d ./"${project_name//.git/}" ]; then
        cd ./"${project_name//.git/}"
        git pull
        cd - &>/dev/null
    else
        git clone -q "${project}"
    fi 
    echo "[ $project_name ] done."
done
cd ..
chown -R $USER_NAME:$USER_NAME ./.git 

## enabling units
systemctl enable docker.service
systemctl enable sshd.service
