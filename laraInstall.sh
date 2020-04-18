#!bin/bash

if  test -d ~/.config/fish; then
    mkdir ~/.config/fish/scripts
    curl https://raw.githubusercontent.com/chumicat/lara/master/lara.sh --output ~/.config/fish/scripts/lara
    chmod a+rx ~/.config/fish/scripts/lara
    fish -c "
        function lara
            ~/.config/fish/scripts/lara \$argv
        end
        funcsave lara
    "
    echo -e "\e[32mInstall finish\e[0m"
else
    mkdir ~/opt
    sudo curl https://raw.githubusercontent.com/chumicat/lara/master/lara.sh --output ~/opt/lara
    sudo chmod a+rx ~/opt/lara
    grep -q 'export PATH="$HOME/opt:$PATH"' ~/.bashrc || echo 'export PATH="$HOME/opt:$PATH"' >> ~/.bashrc
    rm $0
    echo -e "\e[32mInstall finish\e[0m"
fi
rm $0



