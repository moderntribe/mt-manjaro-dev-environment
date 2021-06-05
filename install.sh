#!/usr/bin/env bash

# Config
OS=$(lsb_release -d -s)
WM=$(ls /usr/share/xsessions/)
SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
XFCE=true
THEME=true
WHISKER=$HOME/.config/xfce4/panel/whiskermenu-8.rc
SYSTEMD_SWAP_CONFIG=/etc/systemd/swap.conf

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
    echo "This install doesn't appear to be using the XFCE Window Manager...this will skip some visual customizations but still install core software. Continue [y/n]?"
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
# php-codesniffer
gpg --recv-keys 31C7E470E2138192

# Install software
echo "* Installing packages..."
xargs sudo pacman -S --needed --noconfirm < $SCRIPTDIR/conf/pacman/pkglist.txt

# Install software from AUR using yay
xargs yay -S --noconfirm --mflags "--nocheck" < $SCRIPTDIR/conf/pacman/aur.txt

# Install NVM
NVM_VERSION="v0.38.0"
echo "* Installing NVM $NVM_VERSION"
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash

# Install EB cli
echo "* Installing Amazon EB cli"
pip install awsebcli --upgrade --user
if ! command grep -qc '~/.local/bin' $HOME/.bashrc; then
    echo 'export PATH="~/.local/bin:$PATH"' >> $HOME/.bashrc
fi

# Install themes and icons
if [[ $THEME = true ]]; then
    echo "* Installing Arc theme..."
    xargs sudo pacman -S --needed --noconfirm < $SCRIPTDIR/conf/pacman/pkglist-theme.txt

    # Configure theme for XFCE
    if [[ $XFCE = true ]]; then
        echo "* Enabling Arc Dark theme..."
        xfconf-query -c xsettings -p /Net/ThemeName -s "Arc-Dark"
        xfconf-query -c xfwm4 -p /general/theme -s "Arc-Dark"

        echo "* Enabling Papirus Dark Maia Icons"
        xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark-Maia"

        echo "* Setting Fonts..."
        xfconf-query -c xsettings -p /Gtk/FontName -s "Lucida Grande Regular 11"
        xfconf-query -c xfwm4 -p /general/title_font -s "Lucida Grande Regular 11"

        echo "* Setting start menu icon...."
        sudo cp -f $SCRIPTDIR/images/tribe-logo.svg /usr/share/icons/tribe-logo.svg
        sudo chown root.root /usr/share/icons/tribe-logo.svg
        bash $SCRIPTDIR/bin/confix -s'=' -f $WHISKER "button-icon=/usr/share/icons/tribe-logo.svg"
        bash $SCRIPTDIR/bin/confix -s'=' -f $WHISKER "show-button-icon=true"

        echo "* Setting start menu favorites..."
        bash $SCRIPTDIR/bin/confix -s'=' -f $WHISKER "favorites=exo-terminal-emulator.desktop,exo-file-manager.desktop,pamac-manager.desktop,jetbrains-phpstorm.desktop,telegramdesktop.desktop,galculator.desktop,slack.desktop"

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

if [[ $XFCE = true ]]; then
    # Set screenshot shortcut
    echo "* Setting screenshot hotkey CTRL+SHIFT+PRTSC to allow selecting an area to copy to clipboard..."
    xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Primary><Shift>Print" -s "xfce4-screenshooter -rc"

    # Set wallpaper
    echo "* Setting wallpaper..."
    sudo cp -f $SCRIPTDIR/images/tribe-wallpaper.png /usr/share/backgrounds/tribe-wallpaper.png
    wal -q -s -t -i /usr/share/backgrounds/tribe-wallpaper.png

    # Set drop down terminal shortcut
    echo "* Setting drop down terminal hotkey to CTRL+G..."
    xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Primary>g" -s "xfce4-terminal --drop-down"

    # Disable sluggish xcape whisker menu shortcut
    echo "* Disabling xcape and manually binding Super L key to whisker menu..."
    killall -9 xcape
    rm -rf "$HOME/.config/autostart/xcape.desktop"
    xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/Super_L" -s "xfce4-popup-whiskermenu"
fi

# Nord terminal theme
echo "* Setting terminal theme"
git clone https://github.com/arcticicestudio/nord-xfce-terminal
bash ./nord-xfce-terminal/install.sh

# Systemd-swap to help with memory problems
echo "* Setting up systemd-swap..."
sudo bash $SCRIPTDIR/bin/confix -s'=' -f $SYSTEMD_SWAP_CONFIG "swapfc_enabled=1"
sudo systemctl start systemd-swap
sudo systemctl enable systemd-swap

# Fix Docker
echo "* Fixing docker permissions..."
sudo usermod -a -G docker $USER
echo "* Enable docker on boot..."
sudo systemctl enable docker

# Install SquareOne Global Docker
echo "* Installing SquareOne Global Docker CLI tool..."
bash -c "$(curl -fsSL https://raw.githubusercontent.com/moderntribe/square1-global-docker/master/install/install.sh)"

# Enable user namespaces so Brave works properly
echo "* Enabling user namespaces so Brave Browser works properly..."
echo kernel.unprivileged_userns_clone = 1 | sudo tee /etc/sysctl.d/00-local-userns.conf

# Fix Brave/Nvidia gpu crashing after computer wakes up
# Hopefully no longer needed with most recent versions.
# BRAVE_CONFIG=$HOME/.config/brave-flags.conf
# echo "* Copying custom Brave Browser config to ${BRAVE_CONFIG}"
# cp $SCRIPTDIR/conf/user/.config/brave-flags.conf $BRAVE_CONFIG

# Fish shell
echo "* Installing and configuring fish shell..."

# Install Oh My Fish
curl -L https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > install_omf
chmod +x install_omf
fish -c "./install_omf --noninteractive --yes"

# Install agnoster fish theme
fish -c "omf install agnoster"

# Install fish nvm support
fish -c "omf install https://github.com/fabioantunes/fish-nvm"
fish -c "omf install https://github.com/edc/bass"

# Set Nord colors for fish
cp $SCRIPTDIR/conf/fish/fish_variables ~/.config/fish/fish_variables

# Add composer global bin directory to paths
fish -c "set -U fish_user_paths $HOME/.config/composer/vendor/bin"

# Tell XFCE terminal to use fish as the default shell
cp -f $SCRIPTDIR/conf/xfce4/terminalrc ~/.config/xfce4/terminal/terminalrc

# Notes and Reboot
echo "**************************************************************************************************************************"
echo "If you have touchpad problems, you might want to consider downgrading the kernel. See the README for more information."
echo "I personally backup my .ssh/config folders, id_rsa, id_rsa.pub, known_hosts, VPN configs and github keys which I would manually restore at this point."
echo "**************************************************************************************************************************"
echo "* Reboot now to complete the installation [y/n]?"
read CHOICE
if [[ $CHOICE == y* ]]; then
    sudo reboot
else
    echo "* Done! Make sure you reboot otherwise docker won't work properly."
fi
