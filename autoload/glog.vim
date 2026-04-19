let s:save_cpo = &cpoptions
set cpoptions&vim

let s:Git = {
	\ 'SpecifyFile' : 0,
	\ 'GitRoot' : '',
	\ 'RelativePath' : '',
	\ 'ExeFilename' : '',
	\ 'ExeWinnr' : -1
	\ }

"---------------------------------------------------------------
" エラー表示
"---------------------------------------------------------------
function! s:ErrorMessage(msg) abort
	echo "\r"
	echohl Error | echomsg a:msg | echohl None
	return
endfunction

"---------------------------------------------------------------
" リポジトリ最上位ディレクトリの取得
"---------------------------------------------------------------
function! s:GetGitRoot() abort
	let root = system('git -C ' . shellescape(expand('%:h:p')) . ' rev-parse --show-toplevel')
	return v:shell_error != 0 ? '' : substitute(root, '\n$', '', '')
endfunction

"---------------------------------------------------------------
" リポジトリ最上位ディレクトリから見た相対パスの取得
"---------------------------------------------------------------
function! s:GetRelative() abort
	let relative = system('git -C ' . shellescape(expand('%:h:p')) . ' rev-parse --show-prefix')
	return v:shell_error != 0 ? '' : substitute(relative, '\n$', '', '')
endfunction

"---------------------------------------------------------------
" ハッシュ値の抽出
"---------------------------------------------------------------
function! s:GetSHAFromLine() abort
	let line = getline('.')
	return matchstr(line, '^\x\+')
endfunction

"---------------------------------------------------------------
" 指定ウィンドウに移動
"---------------------------------------------------------------
function! s:SwitchWindow(window_name) abort
	let winnr = bufwinnr(a:window_name)
	if winnr != -1
		if winnr() != winnr
			exe winnr.'wincmd w'
		endif
	endif

	return winnr
endfunction

"---------------------------------------------------------------
" 差分の表示
"---------------------------------------------------------------
function! s:ShowDiff() abort
	let sha = s:GetSHAFromLine()
	if empty(sha)
		call s:ErrorMessage("No commit hash found")
		return
	endif

	" gitコマンド実行
	let cmd = 'silent! read !git -C ' . s:Git['GitRoot'] . ' show ' . sha

	" 既に__Glog__ウィンドウがある場合：内容を消去。ない場合は、ウィンドウを作る
	if s:SwitchWindow('__Gdiff__') != -1
		silent %d _
	else
		execute 'new __Gdiff__'
		setlocal buftype=nofile bufhidden=wipe noswapfile
		setlocal filetype=gitdiff
		setlocal nobuflisted

		" キーマップを定義
		nnoremap <buffer> <silent> q :<C-u>call <SID>CloseDiff()<CR>
	endif

	" 表示
	execute cmd
	normal! gg
	delete _
endfunction

"---------------------------------------------------------------
" 差分表示を閉じる
"---------------------------------------------------------------
function! s:CloseDiff() abort
	close

	let winnr = bufwinnr('__Glog__')
	if winnr != -1
		if winnr() != winnr
			exe winnr.'wincmd w'
		endif
	endif
endfunction

"---------------------------------------------------------------
" 指定リビジョンを表示
"---------------------------------------------------------------
function! s:ShowRevision()
	let sha = s:GetSHAFromLine()
	if empty(sha)
		call s:ErrorMessage("No commit hash found")
		return
	endif

	let cmd = 'silent! read !git -C ' . s:Git['GitRoot'] . ' show ' . sha . ":" . s:Git['RelativePath'] . s:Git['ExeFilename']

	" 実行元のウィンドウに移動して実行
	execute s:Git['ExeWinnr'] . 'wincmd w'

	execute 'enew'
	setlocal noswapfile
	execute 'setlocal filetype=' . expand(s:Git['ExeFilename'], ':e')

	execute cmd
	normal! gg
	delete _
endfunction

"---------------------------------------------------------------
" git log
"---------------------------------------------------------------
function! glog#GitLog(...) abort
	" 引数
	let s:Git['SpecifyFile'] = get(a:000, 0, '') ==# '.' ? 1 : 0

	" リポジトリの最上位ディレクトリの取得
	let root = s:GetGitRoot()
	if empty(root)
		call s:ErrorMessage("Out of git management")
		return
	else
		" リポジトリ最上位ディレクトリ
		let s:Git['GitRoot'] = root
		" リポジトリ最上位ディレクトリから見た相対パス
		let s:Git['RelativePath'] = s:GetRelative()
		" Glogを実行したファイル名
		let s:Git['ExeFilename'] = expand('%:t')
		" Glogを実行したウィンドウ番号
		let s:Git['ExeWinnr'] = winnr()
	endif

	" git log コマンドの実行
	let cmd = 'git -C ' . s:Git['GitRoot'] . ' log --pretty=format:"%h %ad %s" --date=short'
	let cmd .= s:Git['SpecifyFile'] ? " -- " . s:Git['RelativePath'] . s:Git['ExeFilename'] : ''
	let log = systemlist(cmd)

	" 実行元のウィンドウ番号, ディレクトリ、ファイル名を記憶
	let s:target_winnr = winnr()

	" 既に__Glog__ウィンドウがある場合：内容を消去。ない場合は、ウィンドウを作る
	if s:SwitchWindow("__glog__") != -1
		silent %d _
	else
		exe 'silent! botright 8 split __Glog__'
		setlocal buftype=nofile bufhidden=wipe noswapfile
		setlocal filetype=gitlog
		setlocal nobuflisted
		setlocal nowrap
		setlocal winfixheight winfixwidth

		" キーマップを定義
		nnoremap <buffer> <silent> q :close<CR>
		nnoremap <buffer> <silent> p :<C-u>call <SID>ShowRevision()<CR>
		nnoremap <buffer> <silent> <CR> :<C-u>call <SID>ShowDiff()<CR>
	endif

	" git log をバッファに展開
	call setline(1, log)
	normal! gg
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
