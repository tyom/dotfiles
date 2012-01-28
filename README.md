This is a collection of my personal settings and aliases for bash and zsh shells.

![My terminal screenshot](https://raw.github.com/tyom/dotfiles/master/terminal-screenshot.png)

Usage
=====

Source dot files for the shell you use. To switch to zsh on your Mac go to **System Preferences** > **Users & Groups** and right click on your user name (may require unlocking first), then click **Advanced Options** and select your shell from dropdown menu. 

zsh
---

**.zshrc** file

    . ~/bin/dotfiles/zshrc


bash
----

**.bashrc** file

    . ~/bin/dotfiles/bashrc

**.bash_profile** file

    # Run .bashrc
    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi


vim
---

    ln -s ~/bin/dotfiles/vimrc .vimrc
    ln -s ~/bin/dotfiles/vim/ .vim

Install [vim-pathogen](https://github.com/tpope/vim-pathogen).
