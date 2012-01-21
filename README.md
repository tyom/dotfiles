This is a collection of my personal settings and aliases fro bash and zsh shells.

Usage
=====

Source dot files for the shell you use. To switch to zsh on your Mac go to **System Preferences** > **Users & Groups** and right click on your user name (may require unlocking first), then click **Advanced Options** and select your shell from dropdown menu. 

bash
----

**.bashrc** file

    . ~/bin/dotfiles/bashrc

**.bash_profile** file

    # Run .bashrc
    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi

zsh
---

**.zshrc** file

    . ~/bin/dotfiles/zshrc