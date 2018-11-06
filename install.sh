#!/usr/bin/env bash

# Config
OS=$(lsb_release -d -s)
WM=$(ls /usr/share/xsessions/)
SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
XFCE=true
THEME=true
WHISKER=$HOME/.config/xfce4/panel/whiskermenu-8.rc

# Ensure this is run without sudo
if [[ $UID = 0 ]]; then
    echo "Please do not run this script with sudo:"
    echo "$0 $*"
    exit 1
fi

# Check Manjaro version
if [[ $OS != '"Manjaro Linux"' ]]; then
    echo "This doesn't appear to be a Manjaro Linux Installation...exiting."
    exit 1;
fi

# Check window manager
if [[ $WM != "xfce.desktop" ]]; then
    echo "This install doesn't appear to be using the XFCE Window Manager...this will skip some visual customizations. Continue [y/n]?"
    read CHOICE
    if [[ $CHOICE == y* ]]; then
        XFCE=false
    else
        exit 1;
    fi
fi

# Add visual customizations?
echo "* Would you like to install a dark theme and custom icons with some basic Tribe branding [y/n]?"
read CHOICE
if [[ $CHOICE == n* ]]; then
    THEME=false
fi

# Are you ready?
echo "* Ready to begin installation (this will take a while) [y/n]?"
read CHOICE
if [[ $CHOICE != y* ]]; then
    echo "Exiting..."
    exit 1
fi

# Enable AUR
echo "* Enabling AUR..."
sudo cp -f $SCRIPTDIR/conf/etc/pamac.conf /etc/pamac.conf

# Update pacman mirrors and system
echo "* Choosing the fastest mirrors for your location and updating the system..."
sudo pacman-mirrors --fasttrack && sudo pacman -Syyu

# Import gpg keys for some AUR packages
gpg --recv-keys --keyserver hkp://pgp.mit.edu A2C794A986419D8A

# Install software
echo "* Installing packages..."
xargs sudo pacman -S --needed --noconfirm < $SCRIPTDIR/conf/pacman/pkglist.txt

# Install software from AUR using yay
xargs yay -S --noconfirm --mflags "--nocheck" < $SCRIPTDIR/conf/pacman/aur.txt

# Install NVM
echo "* Installing NVM v0.33.11..."
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash

# Install themes and icons
if [[ $THEME = true ]]; then
    echo "* Installing Arc theme..."
    xargs sudo pacman -S --needed --noconfirm < $SCRIPTDIR/conf/pacman/pkglist-theme.txt
    echo "* Installing Pop! Icons..."
    git clone https://github.com/pop-os/icon-theme.git $SCRIPTDIR/make/icon-theme
    cd $SCRIPTDIR/make/icon-theme
    sudo make install
    sudo make post-install
    cd $SCRIPTDIR

    # Configure theme for XFCE
    if [[ $XFCE = true ]]; then
        echo "* Enabling Arc Dark theme..."
        xfconf-query -c xsettings -p /Net/ThemeName -s "Arc-Dark"
        xfconf-query -c xfwm4 -p /general/theme -s "Arc-Dark"

        echo "* Enabling Pop! Icons..."
        xfconf-query -c xsettings -p /Net/IconThemeName -s "Pop"

        echo "* Setting Fonts..."
        xfconf-query -c xsettings -p /Gtk/FontName -s "Droid Sans 11"
        xfconf-query -c xfwm4 -p /general/title_font -s "Bitstream Vera Sans 12"

        echo "* Setting start menu icon...."
        sudo cp -f $SCRIPTDIR/images/tribe-logo.svg /usr/share/icons/tribe-logo.svg
        sudo chown root.root /usr/share/icons/tribe-logo.svg
        bash $SCRIPTDIR/bin/confix -s'=' -f $WHISKER "button-icon=/usr/share/icons/tribe-logo.svg"
        bash $SCRIPTDIR/bin/confix -s'=' -f $WHISKER "show-button-icon=true"

        echo "* Setting start menu favorites..."
        bash $SCRIPTDIR/bin/confix -s'=' -f $WHISKER "favorites=exo-terminal-emulator.desktop,exo-file-manager.desktop,pamac-manager.desktop,jetbrains-phpstorm.desktop,telegramdesktop.desktop,galculator.desktop,google-chrome.desktop,slack.desktop"

    fi
fi

# Configure DNS
echo "* Configuring DNS for Square One..."
sudo cp -f $SCRIPTDIR/conf/etc/resolv.conf.head /etc/resolv.conf.head
sudo chown root.root /etc/resolv.conf.head
echo "* Copying NetworkManager.conf"
sudo cp -f $SCRIPTDIR/conf/etc/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf
sudo resolvconf -u

# Making project folders
echo "* Creating project folders in $HOME/projects..."
mkdir $HOME/projects
mkdir $HOME/projects/tribe
mkdir $HOME/projects/personal
mkdir $HOME/projects/codeable

# Configure PHP
echo "* Copying php.ini to /etc/php..."
sudo cp -f $SCRIPTDIR/conf/php/php.ini /etc/php/php.ini

# Install EB cli
echo "* Installing Amazon EB cli"
pip install awsebcli --upgrade --user
echo 'export PATH="~/.local/bin:$PATH"' >> $HOME/.bashrc

# Set screenshot shortcut
if [[ $XFCE = true ]]; then
    echo "* Setting screenshot hotkey CTRL+SHIFT+PRTSC to allow selecting an area to copy to clipboard..."
    xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Primary><Shift>Print" -s "xfce4-screenshooter -rc"
fi

# Wallpaper and terminal colors
echo "* Setting wallpaper and terminal colors..."
sudo cp -f $SCRIPTDIR/images/girlwallpaper.jpg /usr/share/backgrounds/girlwallpaper.jpg
wal -q -i /usr/share/backgrounds/girlwallpaper.jpg
echo "(cat ~/.cache/wal/sequences &)" >> $HOME/.bashrc

# Setup snaps
echo "* Setting up snapd..."
sudo systemctl enable --now snapd.socket
if [[ ! -d /snap ]]; then
    sudo ln -s /var/lib/snapd/snap /snap
fi

# Fix Docker
echo "* Fixing docker permissions..."
sudo usermod -a -G docker $USER
echo "* Enable docker on boot..."
sudo systemctl enable docker

# Copy extra scripts
echo "* Copying start-sq1.sh and stopcontainers.sh to /usr/local/bin..."
sudo cp -f $SCRIPTDIR/bin/start-sq1.sh /usr/local/bin/start-sq1.sh
sudo cp -f $SCRIPTDIR/bin/stopcontainers.sh /usr/local/bin/stopcontainers.sh
sudo chown root.root /usr/local/bin/*
sudo chmod +x /usr/local/bin/*

# Notes and Reboot
echo "**************************************************************************************************************************"
echo "If you have touchpad problems, you might want to consider downgrading the kernel. See the README for more information."
echo "I personally backup my .ssh/config folders, id_rsa, id_rsa.pub, known_hosts, VPN configs and github keys which I would manually restore at this point."
echo "After reboot, clone square-one to $HOME/projects/tribe."
echo "**************************************************************************************************************************"
echo "* Reboot now to complete the installation [y/n]?"
read CHOICE
if [[ $CHOICE == y* ]]; then
    sudo reboot
else
    echo "* Done! Make sure you reboot otherwise docker won't work properly."
fi
