#!/bin/bash
version=1.1.6
projectPath=$PWD
projectName=$(basename $PWD)
gitEmail=$(git config user.email)
gitName=$(git config user.name)
gitUrl=git@github.com:$gitName/$projectName.git
siteDomain=laravel.test

case "$1" in
    # # ===== LARA GENERAL COMMAND ===== #
    # lara list                     # List all command
    list) # list all command
        grep -E "^(    # )" $0 | sed -e 's/    # //'
        ;;
    # lara status                   # Check HEAD
    # lara version                  # Show script version
    version)
        echo "LARA $version"
        echo "Copyright (c) Chumicat"
        ;;
    # lara setenv)                  # Check and Set environment
    setenv)
        bashPath='~/.bashrc'
        fishPath='~/.config/fish/config.fish'
        brewPath='/usr/local/Homebrew/Library/Taps/chumicat/homebrew-lara'
        grep -q brewPath fishPath || ! test -d ~/.config/fish || echo "set PATH \$PATH $brewPath" >> $fishPath
        grep -q brewPath bashPath || echo "set PATH \$PATH $brewPath" >> $bashPath
        echo -e "\e[32mSet Environment Finish\e[0m";
        ;;
    # lara update|reinstall         # Update lara script
    update | reinstall)
        curl https://raw.githubusercontent.com/chumicat/lara/master/laraInstall.sh --output laraInstall.sh && bash laraInstall.sh
        lara version
        ;;
    # lara remove                   # Remove lara script
    remove)
        sudo rm -rf ~/opt/lara ~/.config/fish/functions/lara.fish ~/.config/fish/scripts/lara
        ;;

    # # ===== PROJECT CONTROL COMMAND ===== #
    # lara new <projName>           # New a laravel project
    # lara init <projName>          # Initial a laravelproject after clone
    # lara switch <projName>        # Switch HEAD to project
    # lara distribute <projName>    # Add "automatic initial script" to project

    # # ===== IN PROJECT COMMAND ===== #
    # lara up                       # Up HEAD project
    # lara down                     # down HEAD project
    # lara restart                  # restart HEAD project
    # lara downup                   # downup HEAD project



    switch) ＃ switch to specific laravel project
        ;;


    # # ===== HADN"T DEAL ===== #
    new | init) # alias
        bash $0 proj $1 $2
        ;;

    proj)
        git clone https://github.com/laradock/laradock.git
        test -r laradock/.env || cp laradock/env-example laradock/.env
        test -r laradock/nginx/sites/$siteDomain.conf || sed "s/server_name laravel.test/server_name $siteDomain/" laradock/nginx/sites/laravel.conf.example > laradock/nginx/sites/$siteDomain.conf
        grep -q $siteDomain /etc/hosts || sudo -- sh -c "echo '127.0.0.1       $siteDomain' >> /etc/hosts"
        bash "$0" up "$3"n

        cd laradock
        case "$2" in
            new) # create laradock + laravel project
                echo "Wait several minutes to generate the project"
                docker-compose exec --user=laradock workspace bash -c "composer create-project laravel/laravel --prefer-dist;"
                [[ "$3" == '-'*'g'* ]] && docker-compose exec --user=laradock workspace bash -c "bash $0 git -i"
                ;;

            init | initial) # initial laradock + laravel project which clone from remote
                echo "Wait several minutes to download the require"
                docker-compose exec --user=laradock workspace bash -c "
                    cd laravel;
                    composer install;
                    test -r .env || cp .env.example .env;
                    php artisan key:generate --ansi;
                    php artisan package:discover --ansi;
                "
                ;;
        esac
        cd ../
        sed -e "s/DB_HOST=127.0.0.1/DB_HOST=mysql/" \
            -e "s/DB_DATABASE=laravel/DB_DATABASE=default/" \
            -e "s/DB_USERNAME=root/DB_USERNAME=default/" \
            -e "s/DB_PASSWORD=secret/DB_PASSWORD=/" \
            -e "s/DB_PASSWORD=/DB_PASSWORD=secret/" \
            laravel/.env > tmp;
        mv tmp laravel/.env

        cd laradock
        docker-compose exec --user=laradock workspace bash -c "
            cd laravel;
            php artisan migrate:fresh --seed;
            php artisan migrate:status;
        "
        cd ../

        # -c case, down docker-compose
        if [[ "$3" == '-'*'c'* ]]; then 
            bash "$0" down
        else
            bash "$0" site
        fi
        ;;

    git) # git shortcut command
        case "$2" in
            -i | --init | initial)
                test -d .git || git init
                test -r .gitignore || cp laravel/.gitignore ./
                test -r .gitattributes || cp laravel/.gitattributes ./
                git check-ignore -q laradock || echo 'laradock' >> .gitignore
                git check-ignore -q .ssh || echo '/.ssh' >> .gitignore
                git add .
                git commit -m 'first commit'
                ;;

            -d | --remove | remove)
                echo -e "\e[4;31mWARNING! YOU ARE DELETING .GIT\e[0m"
                for i in {30..1}; do echo -e "Rest \e[31m$i\e[0m s to ^C"; sleep 1; done
                rm -rf .git .gitignore .gitattributes
                ;;

            -r | --remote | remote)
                if [ -z "$3" ]; then
                    git remote add origin $gitUrl
                else
                    git remote add origin "$3"
                fi
                git push -u origin master
                ;;

            -s | --save | save)
                git add .
                if [[ -z "$3" ]]; then
                    git commit -m 'autosave'
                else
                    git commit -m "$3"
                fi
                git pull
                git push
                ;;

            -a | --amend | amend)
                git add .
                if [[ -z "$3" ]]; then
                    git commit --amend --no-edit
                else
                    git commit --amend -m "$3"
                fi
                git push -f
        esac 
        ;;
    
    up) # docker-comose up
        # -d case, launch docker daemno before docker-comose
        if [[ "$2" == '-'*'d'* ]]; then
            test $(uname) == 'Darwin' && open -a docker
            for i in {30..1}; do echo "Rest $i s to go"; sleep 1; done
        fi

        cp -r ~/.ssh ./
        cd laradock
        docker-compose up -d nginx mysql redis workspace
        docker ps
        docker-compose exec --user=laradock workspace bash -c "git config --global user.email $gitEmail; git config --global user.name $gitName; mv .ssh ~;"
        docker-compose exec --user=root workspace bash -c "git config --global user.email $gitEmail; git config --global user.name $gitName; mv .ssh ~;"
        docker-compose exec --user=root workspace bash -c "apt update; apt install fish -y"
        cd ../
        
        if [[ "$2" == '-'*'e'* ]] && [[ ! "$2" == '-'*'n'* ]]; then # -e case, enter
            bash "$0" enter "$2"
        fi
        ;;

    down) # docker-comose down
        cd laradock
        docker-compose down 
        docker ps
        ;;

    restart) # docker-comose restart
        cd laradock
        docker-compose restart
        ;;

    downup)
        bash "$0" down "$2"
        bash "$0" up "$2"
        ;;

    enter) # enter laradock workspace
        cd laradock
        if [[ "$2" == '-'*'r'* ]] || [[ "$2" == '--root' ]] || [[ "$2" == 'root' ]]; then # -r case, root
            docker-compose exec --user=root workspace fish
        else
            docker-compose exec --user=laradock workspace fish
        fi
        ;;

    site)
        open http://$siteDomain/$2
        open http://$siteDomain/ntr
        open http://$siteDomain/api/documentation
        ;;
    
    lara)
        printf '\a'; sleep 1.2; printf '\a'; sleep 1.2; printf '\a'; printf "\a"; printf "\a"; sleep 2.4; printf '\a'; printf '\a'; printf '\a'; printf '\a'; sleep 3.0; printf '\a'; printf '\a';
        ;;
        
    *)
        echo NO RESULT
        ;;
esac
