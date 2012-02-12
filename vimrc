" Starting point: http://amix.dk/vim/vimrc.html

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

" Auto hide unsaved buffers without showing warning when :bn :bp
set hidden

" When vimrc is edited, reload it
autocmd! bufwritepost vimrc source ~/.vimrc

" Show NERD Tree on Vim start
" autocmd VimEnter * NERDTree

if has("gui_running")
" Disable toolbar in MacVim
  set guioptions=egmrt
" Tab navigation shortcuts
  map <D-S-]> gt
  map <D-S-[> gT
  map <D-1> 1gt
  map <D-2> 2gt
  map <D-3> 3gt
  map <D-4> 4gt
  map <D-5> 5gt
  map <D-6> 6gt
  map <D-7> 7gt
  map <D-8> 8gt
  map <D-9> 9gt
  map <D-0> :tablast<CR>
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Text, tab and indent related (whitespaces)
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set expandtab
set shiftwidth=4
set tabstop=4
set softtabstop=4
set smarttab

" Set tab preferences per file type
if has("autocmd")
  filetype on
  " The fussy ones
  autocmd FileType make setlocal ts=8 sts=8 sw=8 noexpandtab
  autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
  " Personal prefs
  autocmd FileType ruby,vim setlocal ts=2 sts=2 sw=2 expandtab
  " Treat RSS as XML
  autocmd BufNewFile,BufRead *.rss setfiletype xml
  autocmd BufNewFile,BufRead *.conf setfiletype config
  
  " Delete trailing whitespaces when saving files
  autocmd BufWritePre *.py,*.js,*.html,*.rb :call <SID>StripTrailingWhitespaces()
endif

" Strip trailing whitespaces function (vimcasts.org)
function! <SID>StripTrailingWhitespaces()
    " Preparation: save last search, and cursor position.
    let _s=@/
    let l = line(".")
    let c = col(".")
    " Do the business:
    %s/\s\+$//e
    " Clean up: restore previous search history, and cursor position
    let @/=_s
    call cursor(l, c)
endfunction

" Emulate Textmate indentation (Cmd-[])
nmap <D-[> <<
nmap <D-]> >>
vmap <D-[> <gv
vmap <D-]> >gv

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
" Set :set list shortcut to \l (show invisibles)
nmap <leader>l :set list!<CR>

set pastetoggle=<F5>

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
" Map 'remove search highlight' to <leader>-Enter (leader - \)
map <silent> <leader><cr> :noh<cr>
" Map NERD Tree to ESC-Enter
nmap <silent><esc><cr> :NERDTreeToggle<cr>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Diffs 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:DiffWithSaved()
    let filetype=&ft
    diffthis
    vnew | r # | normal! 1Gdd
    diffthis
    exe "setlocal bt=nofile bh=wipe nobl noswf ro ft=" . filetype
endfunction
com! DiffSaved call s:DiffWithSaved()

function! s:DiffWithSVNCheckedOut()
  let filetype=&ft
  diffthis
  vnew | exe "%!svn cat " . expand("#:p:h")
  diffthis
  exe "setlocal bt=nofile bh=wipe nobl noswf ro ft=" . filetype
endfunction
com! DiffSVN call s:DiffWithSVNCheckedOut()



" Window navigation
map <C-h> <C-w>h
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-l> <C-w>l



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Tabularize 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Mappings
let mapleader=','
if exists(":Tabularize")
  nmap <Leader>a= :Tabularize /=<CR>
  vmap <Leader>a= :Tabularize /=<CR>
  nmap <Leader>a: :Tabularize /:\zs<CR>
  vmap <Leader>a: :Tabularize /:\zs<CR>
endif
