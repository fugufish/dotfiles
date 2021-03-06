call plug#begin()
Plug 'tpope/vim-rails'
Plug 'tpope/vim-bundler'
Plug 'tpope/vim-fugitive'
Plug 'vim-ruby/vim-ruby'
Plug 'tpope/vim-commentary'
Plug 'vim-airline/vim-airline'
Plug 'rbgrouleff/bclose.vim'
Plug 'jeetsukumaran/vim-buffergator'
Plug 'tpope/vim-dispatch'
Plug 'ngmy/vim-rubocop'
Plug 'tpope/vim-surround'
Plug 'dense-analysis/ale'
Plug 'altercation/vim-colors-solarized', { 'dir': '~/.config/nvim/colors/solarized' }
Plug 'lifepillar/vim-solarized8', { 'dir': '~/.config/nvim/colors/solarized8' }
Plug 'sonph/onehalf', { 'dir': '~/.config/nvim/colors/onehalf' }
Plug 'vim-airline/vim-airline-themes'
Plug 'preservim/nerdtree'
Plug 'scrooloose/nerdtree'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'cakebaker/scss-syntax.vim'
Plug 'mustache/vim-mustache-handlebars'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'kevinoid/vim-jsonc'
Plug 'tpope/vim-rake'
Plug 'pangloss/vim-javascript'
Plug 'mrk21/yaml-vim'
Plug 'noprompt/vim-yardoc'
Plug 'benmills/vimux'
Plug 'vim-test/vim-test'
Plug 'svermeulen/vim-subversive'
Plug 'leafgarland/typescript-vim'
Plug 'Shougo/vimproc.vim'
Plug 'valloric/MatchTagAlways'
call plug#end()

 " Cursor in terminal
  " https://vim.fandom.com/wiki/Configuring_the_cursor
  " 1 or 0 -> blinking block
  " 2 solid block
  " 3 -> blinking underscore
  " 4 solid underscore
  " Recent versions of xterm (282 or above) also support
  " 5 -> blinking vertical bar
  " 6 -> solid vertical bar
    
" normal mode
let &t_EI .= "\<Esc>[0 q"
" insert mode
let &t_SI .= "\<Esc>[6 q"

let g:airline_theme='deus'

" important!!
set number
set smarttab
set cindent
"set listchars=eol:$,nbsp:_,tab:>-,trail:~,extends:>,precedes:<,space:.
"set list

set <a-f>=\ef

nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

nmap s <plug>(SubversiveSubstitute)
nmap ss <plug>(SubversiveSubstituteLine)
nmap S <plug>(SubversiveSubstituteToEndOfLine)

nmap <leader>r <plug>(SubversiveSubstituteRange)
xmap <leader>r <plug>(SubversiveSubstituteRange)
nmap <leader>rr <plug>(SubversiveSubstituteWordRange)


"set termguicolors
" let g:solarized_use16=1
set background=dark
syntax enable
colorscheme solarized8

let mapleader = " "

let g:ale_linters = {
			\ "ruby": [
			\	"rubocop"
			\]
			\}

let g:ale_fixers = {
                     \ "ruby": ["rubocop"],
                     \ "css": ["prettier"],
                     \ "erb": ["prettier"],
                     \ "scss": ["prettier"],
                     \ "javascript": ["prettier"],
                     \ "typescript": ["prettier"],
                     \ "handlebars": ["prettier"]
                \ }
let g:ale_fix_on_save = 1
nmap <esc>f :Files<CR>

autocmd FileType ruby setlocal omnifunc=LanguageClient#complete

set sw=2
set tabstop=2
set expandtab

" RSpec.vim mappings
map <Leader>t :call RunCurrentSpecFile()<CR>
map <Leader>s :call RunNearestSpec()<CR>
map <Leader>l :call RunLastSpec()<CR>
map <Leader>a :call RunAllSpecs()<CR>
map <Leader><tab> :Commentary<Cr>
map <Leader>f :w<CR>:RuboCop -a<CR>q
map <esc>[ :tabp<CR>
map <esc>] :tabn<CR>
map <esc>c :CtrlPClearCache<cr>

:nnoremap <leader><leader> :NERDTree<CR>
:nnoremap <leader>q :NERDTreeClose<CR>:CtrlPClearCache<CR>
let g:ale_sign_column_always = 1

autocmd FileType javascript setlocal shiftwidth=2 tabstop=2
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab indentkeys-=0# indentkeys-=<:> foldmethod=indent nofoldenable
autocmd FileType html setlocal shiftwidth=2 tabstop=2
autocmd FileType sass setlocal ts=2 sts=2 sw=2 expandtab indentkeys-=0# indentkeys-=<:> foldmethod=indent nofoldenable



fun! SetupCommandAlias(from, to)
  exec 'cnoreabbrev <expr> '.a:from
        \ .' ((getcmdtype() is# ":" && getcmdline() is# "'.a:from.'")'
        \ .'? ("'.a:to.'") : ("'.a:from.'"))'
endfun
call SetupCommandAlias("W","w")

let test#strategy = "vimux"
nmap <silent> t<C-n> :TestNearest<CR>
nmap <silent> t<C-f> :TestFile<CR>
nmap <silent> t<C-a> :TestSuite<CR>
nmap <silent> t<C-l> :TestLast<CR>
nmap <silent> t<C-g> :TestVisit<CR>

map <Leader>h :nohl<CR>

let g:mta_filetypes = {
    \ 'html' : 1,
    \ 'xhtml' : 1,
    \ 'xml' : 1,
    \ 'html.handlebars' : 1,
    \}
