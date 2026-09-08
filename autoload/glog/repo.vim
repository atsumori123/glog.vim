"===============================================================
" Original Work:
" Copylight (c) Marco Hinz
" Source: https://github.com/mhinz/vim-signify
"===============================================================

"-------------------------------------------------------
" s:callback_nvim_stdout
"-------------------------------------------------------
function! s:callback_nvim_stdout(_job_id, data, _event) dict abort
	let self.stdoutbuf[-1] .= a:data[0]
	call extend(self.stdoutbuf, a:data[1:])
endfunction

"-------------------------------------------------------
" s:callback_nvim_exit
"-------------------------------------------------------
function! s:callback_nvim_exit(_job_id, exitval, _event) dict abort
	" nvimは終了コールバックの引数に終了コードが直接渡されるため、vimの様な待機処理は不要
	return s:handle_diff(self, a:exitval)
endfunction

"-------------------------------------------------------
" s:callback_vim_stdout
"-------------------------------------------------------
function! s:callback_vim_stdout(_job_id, data) dict abort
	" a:dataはジョブが標準出力へ出した1行分の文字列
	" dict:この関数が辞書コンテキストで呼ばれることを示す。get_diff()で本館数登録時にoptions辞書を渡して登録している
	" そのため、selfはoptions辞書を参照する
	" 'stdoutbuf' ; [''] " で初期化されており、受け取った1行をstdoutbufに追加する
	let self.stdoutbuf += [a:data]
endfunction

"-------------------------------------------------------
" s:callback_vim_close (同期ジョブが終了したときのコールバック関数)
"-------------------------------------------------------
function! s:callback_vim_close(channel) dict abort
	" a:channelは閉じたチャネルで、そのチャネルに関連付けられたジョブを取得
	let job = ch_getjob(a:channel)
	" ジョブが完全に終了するまで待機(deadになればプロセスが終了)
	while 1
		if job_status(job) == 'dead'
			" 終了コードを取得(通常は0が成功。diffの場合は0が「差分なし」、1が「差分あり」を意味する)
			let exitval = job_info(job).exitval
			break
		endif
		sleep 10m
	endwhile
	" 差分解析
	return s:handle_diff(self, exitval)
endfunction

"-------------------------------------------------------
" glog#repo#start_job
"-------------------------------------------------------
function! glog#repo#start_job(cmd, options, cwd) abort
	if has('nvim')
		let job_id = jobstart(a:cmd, extend(a:options, {
					\ 'cwd':       a:cwd,
					\ 'on_stdout': function('s:callback_nvim_stdout'),
					\ 'on_exit':   function('s:callback_nvim_exit'),
					\ }))
	else
		let opts = {
					\ 'cwd':      a:cwd,
					\ 'in_io':    'null',
					\ 'out_cb':   function('s:callback_vim_stdout', a:options),
					\ 'close_cb': function('s:callback_vim_close', a:options),
					\ }
		let job_id = job_start(a:cmd, opts)
	endif

	return job_id
endfunction

"-------------------------------------------------------
" glog#repo#stop_job
"-------------------------------------------------------
function! glog#repo#stop_job(job_id) abort
	if has('nvim')
		if a:job_id
			silent! call jobstop(a:job_id)
		endif
	else
		if type(a:job_id) != type(0)
			silent! call job_stop(a:job_id)
		endif
	endif
endfunction

"-------------------------------------------------------
" s:handle_diff
"-------------------------------------------------------
function! s:handle_diff(options, exitval) abort
	" 一時ファイルの削除
	if has_key(a:options, 'tempfiles')
		for f in a:options.tempfiles
			call delete(f)
		endfor
	endif

	" バッファにb:syが無い(=Signifyが初期化されていないバッファ)は対象外
	let sy = getbufvar(a:options.bufnr, 'sy')
	if empty(sy)
		call sy#verbose(printf('No b:sy found for %s', bufname(a:options.bufnr)))
		return
	endif

	" 差分文字列の出力がバッファの文字コード違う場合は変換
	let fenc = getbufvar(a:options.bufnr, '&fenc')
	let enc  = getbufvar(a:options.bufnr, '&enc')
	if (fenc != enc) && has('iconv')
		call map(a:options.stdoutbuf, printf('iconv(v:val, "%s", "%s")', fenc, enc))
	endif

	" 差分の有無をチェック(diffの場合は0が「差分なし」、1が「差分あり」を意味する)
	let found_diff = a:options.difftool == 'diff' ? a:exitval <= 1 : a:exitval == 0
	if found_diff
		" 差分行にsignを付けるか計算して配置
		call sign#set_signs(sy, a:options.stdoutbuf)
	endif

	" 「今のジョブだけが最新のジョブである場合だけ、ジョブIDをリセットする」
	" もし古い非同期ジョブの結果が後から戻ってきても、新しいジョブの状態を壊さないようにする。
	" これは、複数回 diff を走らせたときに起きる「古い結果が新しい結果を上書きする」問題を防ぐための安全策。
	if get(a:options, 'job_gen', -1) == getbufvar(a:options.bufnr, 'sy_job_gen', -2)
		call setbufvar(a:options.bufnr, 'sy_job_id', 0)
	endif
endfunction

