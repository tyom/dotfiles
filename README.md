This is a collection of my personal settings and aliases for zsh.

![Terminal screenshot](https://raw.github.com/tyom/dotfiles/screenshot/terminal.png)

Installation
============

Source dot files. To switch to zsh on your Mac go to **System Preferences** > **Users & Groups** and right click on your user name (may require unlocking first), then click **Advanced Options** and select your shell from drop-down menu.

On Ubuntu run `apt-get install zsh`, followed by `chsh -s /bin/zsh`.

Restart your shell.

You should consider replacing your standard Terminal with the excellent [iTerm2](http://www.iterm2.com/) and enable `xterm-256color` in *Preferences > Profiles > Terminal (Report Terminal Type)* to give nice colours to your prompt.

    git clone https://github.com/tyom/dotfiles ~/.dotfiles


zsh
---

Type the following in the terminal

    echo ". ~/.dotfiles/zshrc" > .zshrc

vim
---

    ln -s ~/.dotfiles/vimrc ~/.vimrc && ln -s ~/.dotfiles/vim/ ~/.vim

    git submodule update --init --recursive

For Command-T plugin to work we need Vim with Ruby support.
`brew install macvim` will do the trick. I creted an alias for it `v`.

git
---
Include `gitconfig` from .dotfiles to extend your existing `.gitconfig`

In `~/.gitconfig` add:

    [include]
      path = ~/.dotfiles/gitconfig


RVM (Ruby)
----------

You need Ruby 1.9+ to get git scripts for prompt to work. In your shell:

    $ curl -L https://get.rvm.io | bash -s stable --ruby

Move the line RVM added from your `.profile` to your `~/.zshrc` file

    $ rvm requirements
    $ rvm install 1.9.2
    $ rvm --default use 1.9.2

You should now be all set.

---

Usage
=====

Helpers
-------

### `gbr`

This Git helper outputs the summary of branches in repo ordered by their freshness. It outputs 6 columns:

1. Date of time of last commit
2. Author of last commit
3. Branch name
4. Branch status (checks whether the branch is merged with the currently check out branch)
5. Commit ID
6. Commit message

**Examples**  
Running `gbr` on master branch will show all *local* branches and their merge status against 'master' branch (currently checked out).
Running `gbr -r` will do the same but for *remote* branches, and `gbr -a` for all. It's `git branch` under the hood.

### `define`

Look up the dictionary on OSX from terminal.

### `colortest`

XTERM 256 colour test. Useful when customising your terminal colours.

### `z`

Jumps to most used directories based on 'frecency'. Installed as as submodule from [original repo](https://github.com/rupa/z).


Aliases
-------

    l           -> 		ls  	   		    column view
    l.  	    -> 		ls -a   		    include hidden files
    ll  	    -> 		ls -l   		    long format
    ll. 	    -> 		ls -la  		    long format, include hidden files
    lls 	    ->		ls -lSh 		    long format, sort by size

    cdd         ->     	cd -  	   		    change to last directory
    
    e <name>    ->      subl <name>         open <name> (file/directory) in Sublime Text
    e.          ->      subl .              open current directory in ST
    
    s           ->      git st --short                      git status
    d           ->      git diff --color-words              git diff with word highlights
    gl          ->      git log -p                          git log as patch
    glc         ->      git log "$concise_logging_format"   git log concise
    glg         ->      glc --graph                         git log concise with graph
    gai         ->      git add -p                          git add patch (interactive adding)
    gcf <id>    ->      git commit --fixup                  git commit fixup <id>
    gau         ->      git add -u                          git add update (eg. update deleted/renamed files)
    gri <br>    ->      git rebase -i                       git rebase interactive <branch>
    gra         ->      git rebase --abort                  git abort rebase in progress
    gria        ->      git rebase -i --autosquash          git rebase interactive with autosquash
    
    server      ->      python -m SimpleHTTPServer          run simple python web server in current dir on port 8000
    
    top_commands ->                                         print top 10 commands from history
    top-20-size  ->                                         print top 20 biggest directories within current directory
    top-size     ->                                         show the list of directories in current directory ordered by size
    
    


---

ZHS Variables
=============

General
-------
    %n - username
    %m - hostname (truncated to the first period)
    %M - hostname
    %l - the current tty
    %? - the return code of the last-run application
    %# - the prompt based on user privileges (# for root and % for the rest)
    %h or %! - current history event number
    %L - the current value of $SHLVL

Time
----
    %t or %@ - 12-hour am/pm format
    %T - system time (HH:MM)
    %* - system time (HH:MM:SS)

Date
----
    %w - date in day-dd format
    %W - date in mm/dd/yy format
    %D - date in yy-mm-dd format
    %{string} - date formatted using the strftime function (http://linux.die.net/man/3/strftime)

Directories
-----------
    %~ - current working directory ($HOME represented as ~)
    %d or %/ - current working directory
    %c or %. - trailing component of $PWD (for n trailing components put an integer n after %)
    %C - like %c or %. but $HOME is represented as ~)

Misc
----
    %h or %! - current history event number
    %L - the current value of $SHLVL

Formatting
----------
    %U[...]%u - begin and end underlined print
    %B[...]%b - begin and end bold print
    %{[...]%} - Begin and enter area that will not be printed. Useful for setting colors.

Visual effects 
--------------
(wrap in %{...%} to make sure they are not printed e.g. %{%F{red}%}%~{%f%}

    %B{...}%b - start/stop boldface mode
    %E        - clear the end of line
    %U{...}%u - start/stop underline mode
    %S{...}%s - start/stop standout mode
    %F{...}%f - start/stop foreground colour (keyword or colour code e.g. %F{red}%f or %F{196}%f
    %K{...}%k - start/stop background colour
    %{...%}   - literal escape sequence (doesn't change cursor position), can be nested

[More info] on ZSH Prompt Expansion http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html

Run `colortest -w -s` to get the list of supported colours.

![](https://ga-beacon.appspot.com/UA-332655-4/dotfiles/readme?pixel)
