set nocompatible   " Disable vi compatibilty
set encoding=utf-8 " Use UTF-8
syntax enable      " Turn on syntax highlighting
set showmatch      " Show matching brackets
set ignorecase     " Do case insensitive matching
set number         " Show numbers
set relativenumber " Show relative numbers
set undolevels=999 " Lots of these
set hlsearch       " Highlight Search
set tabstop=4      " Tab size
set shiftwidth=4   " Indentation size
set softtabstop=4  " Tabs/Spaces interop
set expandtab      " Expands tab to spaces
set nomodeline     " Disable as a security precaution
set mouse=a        " Enable mouse mode
set termguicolors  " Enable true colors
set autoindent     " Enable autoindent
set complete-=i    " Better completion
set laststatus=2   " Always show status line
set ruler          " Show cursor position
set scrolloff=3    " Scroll offset
set sidescrolloff=5
set autoread       " Reload files on change
set history=1000   " More history
set list           " Highlight non whitespace characters
set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<
set noshowmode     " Hide mode in bottom line given lightline

" Specify a directory for plugins
" - For Neovim: stdpath('data') . '/plugged'
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')

" Make sure you use single quotes
Plug 'itchyny/lightline.vim'
Plug 'autozimu/LanguageClient-neovim', {
    \ 'branch': 'next',
    \ 'do': 'bash install.sh',
    \ }

" Themes
Plug 'flrnprz/plastic.vim'
Plug 'Rigellute/rigel'

call plug#end()

if !has('gui_running')
    set t_Co=256
endif

set background=dark
colorscheme rigel

" Save your swp files to a less annoying place than the current directory.
" If you have .vim-swap in the current directory, it'll use that.
" Otherwise it saves it to ~/.vim/swap, ~/tmp or .
if isdirectory($HOME . '/.vim/swap') == 0
    call mkdir($HOME.'/.vim/swap', 'p')
endif
set directory=./.vim-swap//
set directory+=~/.vim/swap//
set directory+=~/tmp//
set directory+=.

" Lightline configuration
let g:lightline = {
    \ 'colorscheme': 'rigel',
    \ }

" Language client configuration
set hidden      " Required for operations modifying multiple buffers like rename.
let g:LanguageClient_serverCommands = {
    \ 'python': ['~/.local/bin/pyls'],
    \ }
