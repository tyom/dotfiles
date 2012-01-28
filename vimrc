" Reference: http://amix.dk/vim/vimrc.html

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
colorscheme molokai 

" Sets how many lines of history VIM has to remember
set history=700

" Load plugin manager
call pathogen#infect()
call pathogen#helptags()

" Enable filetype plugin
filetype plugin on
filetype indent on

" Set to auto read when a file is changed from the outside
set autoread

" When vimrc is edited, reload it
autocmd! bufwritepost vimrc source ~/.vimrc


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Text, tab and indent related
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set expandtab
set shiftwidth=4
set tabstop=4
set smarttab


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => VIM user interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set number      "Show line numbers

set wildmenu    "Turn on WiLd menu

set lbr
set tw=500      "max text width 500

" set ai "Auto indent
" set si "Smart indet
" set wrap "Wrap lines
 
" Use TextMate symbols for invisible characters
" In .vim/colors/yourtheme.vim use NonText and SpecialKey to set eol and tab colours
set listchars=tab:▸\ ,eol:¬
" Set :set list shortcut to /l
nmap <leader>l :set list!<CR>

set ruler       "Always show current position

set cmdheight=2 "The commandbar height

" Set backspace config
set backspace=eol,start,indent
" set whichwrap+=<,>,h,l

set ignorecase  "Ignore case when searching
set smartcase

set incsearch   "Make search act like search in modern browsers
set hlsearch    "Highlight search things

" set magic       "Set magic on, for regular expressions

set showmatch   "Show matching bracets when text indicator is over them
set mat=2       "How many tenths of a second to blink


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Colors and Fonts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
syntax enable "Enable syntax hl

set guifont=Inconsolata:h14


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Moving around, tabs and buffers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Map space to / (search) and c-space to ? (backgwards search)
map <space> /
map <c-space> ?
map <silent> <leader><cr> :noh<cr>
