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
		call glog#common#errmsg("No commit hash found")
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
	silent! 0put = glog#git#git_command(['git', '-C', s:Git['GitRoot'], 'show', sha.':'.(file_path)])
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
	silent! 0put = glog#git#git_command(['git', '-C', s:Git['GitRoot'], 'show', sha.'^:'.(file_path)])
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
	" 実行元のウィンドウに移動
	execute s:Git['ExeWinnr'] . 'wincmd w'

	execute 'enew'
	setlocal noswapfile
	execute 'setlocal filetype=' . expand(s:Git['ExeFilename'], ':e')
"	setlocal buftype=nofile bufhidden=wipe

	" gitコマンド実行して表示
	silent! 0put = glog#git#git_command(['git', '-C', s:Git['GitRoot'], 'diff', s:Git['RelativePath'].s:Git['ExeFilename']])
	normal! gg

	" バッファ名を設定
	execute 'file [diff] ' . s:Git['ExeFilename']
endfunction

"---------------------------------------------------------------
" git status
"---------------------------------------------------------------
function! gstatus#GitStatus(...) abort
	" 引数
	let all = get(a:000, 0, '') ==# '.' ? 1 : 0

	" リポジトリの最上位ディレクトリの取得
	let root = glog#git#get_git_root()
	if empty(root)
		call glog#common#errmsg("Out of git management")
		return
	else
		" リポジトリ最上位ディレクトリ
		let s:Git['GitRoot'] = root[0]
		" リポジトリ最上位ディレクトリから見た相対パス
		let s:Git['RelativePath'] = glog#git#get_relative()[0]
		" Glogを実行したウィンドウ番号
		let s:Git['ExeWinnr'] = winnr()
	endif

	" git status コマンドの実行
	let cmd = ['git', '-C', s:Git['GitRoot'], 'status', '-s']
	let cmd += all ? [] : ['-uno']
	let status = glog#git#git_command(cmd)

	" 既に__glog__ウィンドウがある場合：内容を消去。ない場合は、ウィンドウを作る
	if glog#common#switch_window("__glog__") != -1
		silent %d _
	else
		exe 'silent! botright 8 split __glog__'
		setlocal buftype=nofile bufhidden=wipe noswapfile
		setlocal filetype=gitlog
		setlocal nobuflisted
		setlocal nowrap
		setlocal winfixheight winfixwidth

		" キーマップを定義
		nnoremap <buffer> <silent> q :close<CR>
		nnoremap <buffer> <silent> <CR> :<C-u>call <SID>ShowDiff()<CR>
		nnoremap <buffer> <silent> d :<C-u>call <SID>ShowDiffSideBySide()<CR>
	endif

	" git status をバッファに展開
	call setline(1, status)
	normal! gg
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
