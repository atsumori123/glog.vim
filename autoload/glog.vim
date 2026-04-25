let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" glog初期化
"---------------------------------------------------------------
function! s:glog_init(speify_file) abort
	let git_root = glog#git#get_git_root()
	if empty(git_root[0]) | return 0 | endif

	let s:glog = {}
	let s:glog['GitRoot'] = git_root[0]
	let s:glog['ExeFile'] = glog#git#get_relative()[0] . expand('%:t')
	let s:glog['ExeWinnr'] = winnr()
	let s:glog['SpecifyFile'] = a:speify_file
	return 1
endfunction

"---------------------------------------------------------------
" 情報取得
"---------------------------------------------------------------
function! s:get(key) abort
	return s:glog[a:key]
endfunction

"---------------------------------------------------------------
" エラー表示
"---------------------------------------------------------------
function! s:errmsg(msg) abort
	echo "\r"
	echohl Error | echomsg a:msg | echohl None
endfunction

"---------------------------------------------------------------
" ハッシュ値の抽出 (git log用)
"---------------------------------------------------------------
function! s:get_sha_frome_line() abort
	return matchstr(getline('.'), '^\x\+')
endfunction

"---------------------------------------------------------------
" ファイル名の抽出 (git status用)
"---------------------------------------------------------------
function! s:get_filepath_from_line() abort
	return matchstr(getline('.'), '\v\S+/\S+')
endfunction

"---------------------------------------------------------------
" 指定ウィンドウに移動
"---------------------------------------------------------------
function! s:switch_window(window_name) abort
	let winnr = bufwinnr(a:window_name)
	if winnr != -1
		if winnr() != winnr
			execute winnr.'wincmd w'
		endif
	endif

	return winnr
endfunction

"---------------------------------------------------------------
" ウィンドウ作成
"---------------------------------------------------------------
function! s:open_window(win_name, edit, data) abort
	" 既に__glog__ウィンドウがある場合は内容を消去。ない場合はウィンドウを作る
	if s:switch_window(a:win_name) != -1
		silent %d _
	else
		execute 'silent! ' . a:edit . ' ' . a:win_name
		setlocal buftype=nofile bufhidden=wipe noswapfile
		setlocal nobuflisted
		setlocal nowrap
		setlocal winfixheight winfixwidth
	endif

	silent! 0put = a:data
	normal! gg
endfunction

"---------------------------------------------------------------
" 左右diff用ウィンドウ作成
"---------------------------------------------------------------
function! s:open_sidebyside(file, data) abort
	execute 'enew'
	setlocal noswapfile
	execute 'setlocal filetype=' . fnamemodify(a:file, ':e')
	setlocal buftype=nofile bufhidden=wipe

	silent! 0put = a:data
	normal! gg
endfunction

"---------------------------------------------------------------
" 差分の表示
"---------------------------------------------------------------
function! s:show_diff(git_cmd) abort
	let sha = a:git_cmd ==# 'diff' ? s:get_sha_frome_line() : ''
	let filename = a:git_cmd ==# 'diff' ? '' : s:get_filepath_from_line()

	" gitコマンドを実行
	if empty(sha)
		let cmd = ['git', '-C', s:get('GitRoot'), 'diff', filename]
	else
		let cmd = ['git', '-C', s:get('GitRoot'), 'show', sha]
		let cmd += !empty(filename) ? ['--', filename] : []
	endif
	let result = glog#git#git_cmd(cmd)
	if empty(result)
		call s:errmsg("No difference")
		return
	endif

	" 出力用ウィンドウ作成
	call s:open_window('__gdiff__', 'new', result)
	setlocal filetype=gdiff

	" キーマップを定義
	nnoremap <buffer> <silent> q :<C-u>call <SID>close_diff()<CR>
endfunction

"---------------------------------------------------------------
" 差分表示を閉じる
"---------------------------------------------------------------
function! s:close_diff() abort
	close

	let winnr = bufwinnr('__glog__')
	if winnr != -1
		if winnr() != winnr
			execute winnr.'wincmd w'
		endif
	endif
endfunction

"---------------------------------------------------------------
" 左右対比差分の表示（親コミット vs 現在のコミット）
"---------------------------------------------------------------
function! s:show_diff_side_by_side() abort
	let sha = s:get_sha_frome_line()
	let filename = s:get('ExeFile')

	" 実行元のウィンドウに移動
	execute s:get('ExeWinnr') . 'wincmd w'

	" 新しいタブで左右対比を開く
	tabnew

	" ===== 左ペイン：親コミット（1つ前のリビジョン） =====
	let result = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', sha . '^:' . filename])
	call s:open_sidebyside(s:get('ExeFile'), result)
	diffthis
	execute 'file [' . sha[0:6] . '] ' . fnamemodify(filename, ':t')

	" 画面を左右に分割
	bel vnew

	" ===== 右ペイン：現在のコミット =====
	let result = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', sha . ':' . filename])
	call s:open_sidebyside(s:get('ExeFile'), result)
	diffthis
	execute 'file [' . sha[0:6] . '^] ' . fnamemodify(filename, ':t')

	" フォーカスを左ペインに戻す
	wincmd h
endfunction

"---------------------------------------------------------------
" 左右対比差分の表示（HEAD vs ワーキングディレクトリ）
"---------------------------------------------------------------
function! s:show_diff_side_by_side_head() abort
	let filename = s:get_filepath_from_line()
	if empty(filename) || !filereadable(filename)
		call s:errmsg("No file selected")
		return
	endif

	" 実行元のウィンドウに移動
	execute s:get('ExeWinnr') . 'wincmd w'

	" 新しいタブで左右対比を開く
	tabnew

	" ===== 左ペイン：HEAD のバージョン =====
	let result = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', 'HEAD:' . filename])
	call s:open_sidebyside(filename, result)
	diffthis
	execute 'file [HEAD] ' . fnamemodify(filename, ':t')

	" 画面を左右に分割
	bel vnew

	" ===== 右ペイン：ワーキングディレクトリのバージョン =====
	let working_content = readfile(s:get('GitRoot') . '/' . filename)
	call s:open_sidebyside(filename, working_content)
	diffthis
	execute 'file [WORKING] ' . fnamemodify(filename, ':t')

	" フォーカスを左ペインに戻す
	wincmd h
endfunction

"---------------------------------------------------------------
" 指定リビジョンを表示
"---------------------------------------------------------------
function! s:show_revision()
	let sha = s:get_sha_frome_line()
	if empty(sha)
		call s:errmsg("No commit hash found")
		return
	endif

	" 実行元のウィンドウに移動
	execute s:get('ExeWinnr') . 'wincmd w'

	execute 'enew'
	setlocal noswapfile
	execute 'setlocal filetype=' . fnamemodify(s:get('ExeFile'), ':e')
"	setlocal buftype=nofile bufhidden=wipe

	" gitコマンド実行して表示
	silent! 0put = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'show', sha.':'.s:get('ExeFile')])
	normal! gg

	" バッファ名を設定
	execute 'file [' . sha[0:6] . '] ' . fnamemodify(s:get('ExeFile'), ':t')
endfunction

"---------------------------------------------------------------
" git log
"---------------------------------------------------------------
function! glog#log(...) abort
	" glog初期化
	if s:glog_init(get(a:000, 0, '') ==# '.' ? 1 : 0) == 0
		call s:errmsg("Out of git management")
		return
	endif

	" git log コマンド実行
	let cmd = ['git', '-C', s:get('GitRoot'), 'log',
				\ glog#git#is_bgjob() ? '--pretty=format:%h %ad %s' : '--pretty=format:"%h %ad %s"',
				\ '--date=short']
	let cmd += s:get('SpecifyFile') ? ['--', s:get('ExeFile')] : []
	let result = glog#git#git_cmd(cmd)
	if empty(result)
		call s:errmsg("No commit history")
		return
	endif

	" 出力用ウィンドウ作成
	call s:open_window('__glog__', 'botright 8 split', result)
	setlocal filetype=glog

	" キーマップを定義
	nnoremap <buffer> <silent> q :close<CR>
	nnoremap <buffer> <silent> p :<C-u>call <SID>show_revision()<CR>
	nnoremap <buffer> <silent> <CR> :<C-u>call <SID>show_diff('diff')<CR>
	nnoremap <buffer> <silent> d :<C-u>call <SID>show_diff_side_by_side()<CR>
endfunction

"---------------------------------------------------------------
" git status
"---------------------------------------------------------------
function! glog#status() abort
	" glog初期化
	if s:glog_init('') == 0
		call s:errmsg("Out of git management")
		return
	endif

	" gitコマンド実行
	let result = glog#git#git_cmd(['git', '-C', s:get('GitRoot'), 'status', '-s', '-uno'])
	if empty(result)
		call s:errmsg("No changes")
		return
	endif

	" 出力用ウィンドウ作成
	call s:open_window('__glog__', 'botright 8 split', result)
	setlocal filetype=gstatus

	" キーマップを定義
	nnoremap <buffer> <silent> q :close<CR>
	nnoremap <buffer> <silent> p <nop>
	nnoremap <buffer> <silent> <CR> :<C-u>call <SID>show_diff('status')<CR>
	nnoremap <buffer> <silent> d :<C-u>call <SID>show_diff_side_by_side_head()<CR>
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
