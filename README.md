
This is a collection of Tyom’s dotfiles and settings.

![Shell screenshot](https://raw.githubusercontent.com/tyom/dotfiles/master/shell.png)
![Vim screenshot](https://raw.githubusercontent.com/tyom/dotfiles/master/vim.png)

Installation
============

Installation may take a few minutes as it will download and 
[install](./install) a number of packages.

Setup can be run mulitple times. It will update if necessary.

Admin password will be required during the setup process.

    $ git clone https://github.com/tyom/dotfiles.git ~/.dotfiles
    $ cd ~/.dotfiles
    $ make install

### Remotely

    sh -c "`curl -fsSL https://raw.githubusercontent.com/tyom/dotfiles/updates/install.sh`"

Customisation
==============

These dotfiles are meant to be read-only. Additional configuration shoul be addedt to local dotfiles:

### `~/.zsh.local`
    
### `~/.gitconfig.local`

e.g.

    [user]
        name =Tyom Semonov
        email = mailtyom.net

### iTerm2

To configure iTerm settings set "Load preferences from a custom folder or URL" to `iterm2` URL in this repo

    ~/.dotfiles/iterm2

### macOS

To set some macOS [default preferences](./macOS/set_defaults.sh) run

    `~/.dotfiles/macOS/set_defaults.sh`

Development
===========

To test dotfiles in sandbox use provided Docker image:

    make test
