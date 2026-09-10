"===============================================================
" Original Work:
" Copylight (c) Marco Hinz
" Source: https://github.com/mhinz/vim-signify
"===============================================================

" Variables
let s:sign_add               = get(g:, 'signify_sign_add',               '+')
let s:sign_delete_first_line = get(g:, 'signify_sign_delete_first_line', '^')
let s:sign_change            = get(g:, 'signify_sign_change',            '!')
let s:sign_change_delete     = get(g:, 'signify_sign_change_delete',     '!-')

"-------------------------------------------------------
" sy#numhl
"-------------------------------------------------------
" テスト用サインを定義し、行番号のハイライトグループとしてNumberを指定
try
	sign define SyTest numhl=Number
	let s:use_numhl = 1
	sign undefine SyTest
catch
	let s:use_numhl = 0
endtry

function! glog#highlight#numhl() abort
	if !s:use_numhl
		return ''
	endif

	return 'numhl='
endfunction

" #setup {{{1
function! glog#highlight#setup() abort
	highlight default link SignifyLineAdd             DiffAdd
	highlight default link SignifyLineDelete          DiffDelete
	highlight default link SignifyLineDeleteFirstLine SignifyLineDelete
	highlight default link SignifyLineChange          DiffChange
	highlight default link SignifyLineChangeDelete    SignifyLineChange

	highlight default link SignifySignAdd             DiffAdd
	highlight default link SignifySignDelete          DiffDelete
	highlight default link SignifySignDeleteFirstLine SignifySignDelete
	highlight default link SignifySignChange          DiffChange
	highlight default link SignifySignChangeDelete    SignifySignChange
endfunction

" #line_enable
function! glog#highlight#line_enable() abort
	execute 'sign define SignifyAdd text='. s:sign_add ' texthl=SignifySignAdd linehl=SignifyLineAdd '. glog#highlight#numhl()
	execute 'sign define SignifyChange text='. s:sign_change ' texthl=SignifySignChange linehl=SignifyLineChange '. glog#highlight#numhl()
	execute 'sign define SignifyChangeDelete text='. s:sign_change_delete ' texthl=SignifySignChangeDelete linehl=SignifyLineChangeDelete '. glog#highlight#numhl()
	execute 'sign define SignifyRemoveFirstLine text='. s:sign_delete_first_line ' texthl=SignifySignDeleteFirstLine linehl=SignifyLineDeleteFirstLine '. glog#highlight#numhl()
	let g:signify_line_highlight = 1
endfunction

" #line_disable
function! glog#highlight#line_disable() abort
	execute 'sign define SignifyAdd text='. s:sign_add ' texthl=SignifySignAdd linehl= '. glog#highlight#numhl()
	execute 'sign define SignifyChange text='. s:sign_change ' texthl=SignifySignChange linehl= '. glog#highlight#numhl()
	execute 'sign define SignifyChangeDelete text='. s:sign_change_delete ' texthl=SignifySignChangeDelete linehl= '. glog#highlight#numhl()
	execute 'sign define SignifyRemoveFirstLine text='. s:sign_delete_first_line ' texthl=SignifySignDeleteFirstLine linehl= '. glog#highlight#numhl()
	let g:signify_line_highlight = 0
endfunction

" #line_toggle
function! glog#highlight#line_toggle() abort
	if get(g:, 'signify_line_highlight')
		call glog#highlight#line_disable()
	else
		call glog#highlight#line_enable()
	endif

	redraw!
	call gsign#start()
endfunction

call glog#highlight#setup()
