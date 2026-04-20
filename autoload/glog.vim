let s:save_cpo = &cpoptions
set cpoptions&vim

let s:Git = {
	\ 'SpecifyFile' : 0,
	\ 'GitRoot' : '',
	\ 'RelativePath' : '',
	\ 'ExeFilename' : '',
	\ 'ExeWinnr' : -1
	\ }

let s:SUPPORT_BGJOB = exists('*ch_close_in') ? 1 : 0

"---------------------------------------------------------------
" エラー表示
"---------------------------------------------------------------
function! s:ErrorMessage(msg) abort
	echo "\r"
	echohl Error | echomsg a:msg | echohl None
	return
endfunction

"---------------------------------------------------------------
" バックグラウンド処理の実行
"---------------------------------------------------------------
function! s:RunBackgroundJob(cmd) abort
	let exit = []
	let lines = []
	let jopts = {
		\ 'out_cb': { j, str -> add(lines, str) },
		\ 'err_cb': { j, str -> add(lines, str) },
		\ 'exit_cb': { j, code -> add(exit, code) }}
	let job = job_start(a:cmd, jopts)
	call ch_close_in(job)
	while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
		sleep 1m
	endwhile

	return [lines, exit[0]]
endfunction

"---------------------------------------------------------------
" リポジトリ最上位ディレクトリの取得
"---------------------------------------------------------------
function! s:GitCmd(command)
	if s:SUPPORT_BGJOB
		let result = s:RunBackgroundJob(a:command)
		return result[1] == 0 ? result[0]: []
	else
		let result = systemlist(join(a:command, ' '))
		return v:shell_error == 0 ? result : []
	endif
endfunction

"---------------------------------------------------------------
" リポジトリ最上位ディレクトリの取得
"---------------------------------------------------------------
function! s:GetGitRoot() abort
	return s:GitCmd(['git', '-C', expand('%:h:p'), 'rev-parse', '--show-toplevel'])
endfunction

"---------------------------------------------------------------
" リポジトリ最上位ディレクトリから見た相対パスの取得
"---------------------------------------------------------------
function! s:GetRelative() abort
	return s:GitCmd(['git', '-C', expand('%:h:p'), 'rev-parse', '--show-prefix'])
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

	" gitコマンド実行して表示
	silent! 0put = s:GitCmd(['git', '-C', s:Git['GitRoot'], 'show', sha])
	normal! gg
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
" 左右対比差分の表示（親コミット vs 現在のコミット）
"---------------------------------------------------------------
function! s:ShowDiffSideBySide() abort
	let sha = s:GetSHAFromLine()
	if empty(sha)
		call s:ErrorMessage("No commit hash found")
		return
	endif

	" 実行元のウィンドウに移動
	execute s:Git['ExeWinnr'] . 'wincmd w'

	" 新しいタブで左右対比を開く
	tabnew

	" ===== 左ペイン：親コミット（1つ前のリビジョン） =====
	execute 'enew'
	setlocal noswapfile
	execute 'setlocal filetype=' . expand(s:Git['ExeFilename'], ':e')
	setlocal buftype=nofile bufhidden=wipe

	" 親コミットのファイル版を表示
	let file_path = s:Git['RelativePath'] . s:Git['ExeFilename']
	silent! 0put = s:GitCmd(['git', '-C', s:Git['GitRoot'], 'show', sha.':'.(file_path)])
	normal! gg
	" diff モード有効化
	diffthis
	" バッファ名を設定
	execute 'file [' . sha[0:6] . '^] ' . s:Git['ExeFilename']

	" ===== 右ペイン：現在のコミット =====
	" 垂直分割で右ペインを追加
	vnew
	execute 'enew'
	setlocal noswapfile
	execute 'setlocal filetype=' . expand(s:Git['ExeFilename'], ':e')
	setlocal buftype=nofile bufhidden=wipe

	" 現在のコミットのファイル版を表示
	silent! 0put = s:GitCmd(['git', '-C', s:Git['GitRoot'], 'show', sha.'^:'.(file_path)])
	normal! gg
	" diff モード有効化
	diffthis
	" バッファ名を設定
	execute 'file [' . sha[0:6] . '] ' . s:Git['ExeFilename']

	" フォーカスを左ペインに戻す
	wincmd h
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

	" 実行元のウィンドウに移動
	execute s:Git['ExeWinnr'] . 'wincmd w'

	execute 'enew'
	setlocal noswapfile
	execute 'setlocal filetype=' . expand(s:Git['ExeFilename'], ':e')
"	setlocal buftype=nofile bufhidden=wipe

	" gitコマンド実行して表示
	silent! 0put = s:GitCmd(['git', '-C', s:Git['GitRoot'], 'show', sha.':'.s:Git['RelativePath'].s:Git['ExeFilename']])
	normal! gg

	" バッファ名を設定
	execute 'file [' . sha[0:6] . '] ' . s:Git['ExeFilename']
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
		let s:Git['GitRoot'] = root[0]
		" リポジトリ最上位ディレクトリから見た相対パス
		let s:Git['RelativePath'] = s:GetRelative()[0]
		" Glogを実行したファイル名
		let s:Git['ExeFilename'] = expand('%:t')
		" Glogを実行したウィンドウ番号
		let s:Git['ExeWinnr'] = winnr()
	endif

	" git log コマンドの実行
	let cmd = ['git', '-C', s:Git['GitRoot'], 'log',
				\ s:SUPPORT_BGJOB ? '--pretty=format:%h %ad %s' : '--pretty=format:"%h %ad %s"',
				\ '--date=short']
	let cmd += s:Git['SpecifyFile'] ? ['--', s:Git['RelativePath'] . s:Git['ExeFilename']] : []
	let log = s:GitCmd(cmd)

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
		nnoremap <buffer> <silent> d :<C-u>call <SID>ShowDiffSideBySide()<CR>
	endif

	" git log をバッファに展開
	call setline(1, log)
	normal! gg
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
