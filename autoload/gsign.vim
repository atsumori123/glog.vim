"===============================================================
" Original Work:
" Copylight (c) Marco Hinz
" Source: https://github.com/mhinz/vim-signify
"===============================================================

let s:sign_priority = exists('*sign_place') ? 'priority=10' : ''
let s:internal = {}	" Gsignのサイン
let s:external = {}	" 他のプラグインのサイン

"-------------------------------------------------------
" s:warning
"-------------------------------------------------------
function! s:warning(msg) abort
	echohl WarningMsg | echomsg a:msg | echohl None
endfunction

"-------------------------------------------------------
" s:escape
"-------------------------------------------------------
function! s:escape(path) abort
	if exists('+shellslash')
		let old_ssl = &shellslash
		if fnamemodify(&shell, ':t') == 'cmd.exe'
			set noshellslash
		else
			set shellslash
		endif
	endif

	let path = shellescape(a:path)

	if exists('old_ssl')
		let &shellslash = old_ssl
	endif

	return path
endfunction

"-------------------------------------------------------
" s:set_buflocal_autocmds
"-------------------------------------------------------
function! s:set_buflocal_autocmds(bufnr) abort
	augroup gsign
		execute printf('autocmd! * <buffer=%d>', a:bufnr)

"		execute printf('autocmd BufEnter     <buffer=%d> call gsign#start()', a:bufnr)
"		execute printf('autocmd WinEnter     <buffer=%d> call gsign#start()', a:bufnr)
		execute printf('autocmd BufWritePost <buffer=%d> call gsign#start()', a:bufnr)

		execute printf('autocmd CursorHold   <buffer=%d> call gsign#start()', a:bufnr)
"		execute printf('autocmd CursorHoldI  <buffer=%d> call sign#start()', a:bufnr)
"		execute printf('autocmd FocusGained  <buffer=%d> SignifyRefresh', a:bufnr)
"		execute printf('autocmd CmdwinEnter <buffer=%d> let g:signify_cmdwin_active = 1', a:bufnr)
"		execute printf('autocmd CmdwinLeave <buffer=%d> let g:signify_cmdwin_active = 0', a:bufnr)
"		execute printf('autocmd ShellCmdPost <buffer=%d> call gsign#start()', a:bufnr)

		" if exists('##VimResume')
		" 	execute printf('autocmd VimResume <buffer=%d> call gsign#start()', a:bufnr)
		" endif
	augroup END
endfunction

"-------------------------------------------------------
" s:get_current_signs
"-------------------------------------------------------
function! s:get_current_signs(sy) abort
	" このバッファのサインリストを取得する
	let signlist = sign_getplaced(a:sy.buffer)[0].signs

	for sign in signlist
		if sign.name =~# '^Gsign'
			" Handle ambiguous signs. Assume you have signs on line 3 and 4.
			" Removing line 3 would lead to the second sign to be shifted up
			" to line 3. Now there are still 2 signs, both one line 3.
			if has_key(s:internal, sign.lnum)
				execute 'sign unplace' s:internal[sign.lnum].id 'buffer='.a:sy.buffer
			endif
			let s:internal[sign.lnum] = { 'type': sign.name, 'id': sign.id }
		else
			let s:external[sign.lnum] = sign.id
		endif
	endfor
endfunction

"-------------------------------------------------------
" s:add_sign
"-------------------------------------------------------
function! s:add_sign(sy, line, type) abort
	" 同じ行にGsignのサインがすでに存在するか
	if has_key(s:internal, a:line)
		" 既存サインと新しいサインの種類が同じか
		if a:type == s:internal[a:line].type
			" サインが同じ種類の場合は既存サインを維持してそのIDを返す
			return s:internal[a:line].id
		else
			" 種類が異なる場合は既存サインのIDを再利用して更新する
			let id = s:internal[a:line].id
		endif
	endif

	" 利用する既存IDがなければ新しいIDを採番する
	if !exists('id')
		let id = a:sy.signid
		let a:sy.signid += 1
	endif

	" サインをバッファに配置する。
	execute printf('sign place %d line=%d name=%s %s buffer=%s',
				\ id,
				\ a:line,
				\ a:type,
				\ s:sign_priority,
				\ a:sy.buffer)

	return id
endfunction

"-------------------------------------------------------
" s:external_sign_present
"-------------------------------------------------------
function! s:external_sign_present(sy, line) abort
	" 指定行にGsign以外のサインがあるか確認し、外部サインとGsignサインの競合を避ける
	" プライオリティが利用可能な環境では複数サインを同じ行に配置できるため何もせず終了する
	if !empty(s:sign_priority)
		return 0
	endif

	" プライオリティが利用できない環境では外部サインを優先して
	" 同一行にあるGsignサインを配置しない
	if has_key(s:external, a:line)
		if has_key(s:internal, a:line)
			execute 'sign unplace' s:internal[a:line].id 'buffer='.a:sy.buffer
		endif
		return 1
	endif

	return 0
endfunction

"-------------------------------------------------------
" s:add_signs
"-------------------------------------------------------
function! s:add_signs(sy, start, count, type) abort
	let ids   = []
	let lnums = []

	" 指定行からカウント数分サインを配置する
	for lnum in range(a:start, a:start + a:count - 1, 1)
		" 外部サインがある場合はGsignサインを配置しない
		if s:external_sign_present(a:sy, lnum)
			continue
		endif

		" サインを配置
		let id = s:add_sign(a:sy, lnum, a:type)

		" 配置したサインのIDと行番号をリスト化
		call add(ids, id)
		call add(lnums, lnum)
	endfor

	return [ids, lnums]
endfunction

"-------------------------------------------------------
" s:parse_hunk
" Parse a hunk as '@@ -273,3 +267,14' into [old_line, old_count, new_line, new_count]
"-------------------------------------------------------
function! s:parse_hunk(diffline) abort
	" チャンクヘッダーの見方
	" @@ -1,3 +1,3 @@
	"	-1,3 : 変更前のファイル
	"		-   : 変更前のファイルを指す
	"		1,3 : 1行目から始まって、合計3行分の範囲を指す
	"	+1,3 : 変更後のファイル
	"		+   : 変更後のファイルを指す
	"		1,3 : 1行目から始まって、合計3行分の範囲を指す
	let tokens = matchlist(a:diffline, '^@@ -\v(\d+),?(\d*) \+(\d+),?(\d*)')
	return [
				\ str2nr(tokens[1]),
				\ empty(tokens[2]) ? 1 : str2nr(tokens[2]),
				\ str2nr(tokens[3]),
				\ empty(tokens[4]) ? 1 : str2nr(tokens[4])
				\ ]
endfunction

"-------------------------------------------------------
" s:process_diff
"-------------------------------------------------------
function! s:process_diff(sy, diff) abort
	let a:sy.hunks = []
	let signtable  = {}		" Gsignサインを配置した行リスト

	" このバッファのサインリストを取得する
	let s:internal = {}		" GsignサインのID辞書
	let s:external = {}		" 外部プラグインサインのID辞書
	call s:get_current_signs(a:sy)

	" チャンクヘッダー分(差分の数だけ)繰り返す
	for line in filter(a:diff, 'v:val =~ "^@@ "')
		" チャンクヘッダーから変更範囲を取得する
		let [ol, oc, nl, nc] = s:parse_hunk(line)

		" hunkは差分の @@ ... @@ で囲まれた「ひとまとまりの変更範囲」であり、
		" 複数行のhunkでは、各行にサインが置かれるため、ids も複数になる
		let lnums = []
		let ids   = []

		"-------------------------------
		" 純粋な追加: @@ -5,0 +6,2 @@
		"-------------------------------
		if oc == 0 && nc > 0
			let [ids, lnums] = s:add_signs(a:sy, nl, nc, 'GsignAdd')

		"-------------------------------
		" 純粋な削除: @@ -6,2 +5,0 @@
		"-------------------------------
		elseif oc > 0 && nc == 0
			" 削除位置に外部プラグインのサインがあるか確認し、
			" 存在する場合は処理を中断(continue)してサインを配置しない
			if s:external_sign_present(a:sy, nl) | continue | endif

			" ファイルの先頭行が削除された場合、削除された行が存在しないため、
			" 代わりに新ファイルの1行目にサインを置く
			let lnum = nl == 0 ? 1 : nl
			let [ids, lnums] = s:add_signs(a:sy, lnum, 1, 'GsignDelete')

		"-------------------------------
		" 純粋な変更
		"-------------------------------
		elseif oc > 0 && nc > 0 && oc == nc
			let [ids, lnums] = s:add_signs(a:sy, nl, nc, 'GsignChange')

		"-------------------------------
		" 編集＋追加
		"-------------------------------
		elseif oc > 0 && nc > 0 && oc < nc
			let [ids, lnums]  = s:add_signs(a:sy, nl, oc, 'GsignChange')
			let [ids, lnums] += s:add_signs(a:sy, (nl + oc), (nc - oc), 'GsignAdd')

		"-------------------------------------------------------------------
		" 一部の行を編集＋一部の行を削除(例えば5行あった部分が3行になった)
		"-------------------------------------------------------------------
		elseif oc > 0 && nc > 0 && oc > nc
			" 削除された行は存在しないため、直前の行にサインを置く
			" (先頭行よりも後ろ かつ 既にサインがないこと)
			if nl > 1 && !get(signtable, nl - 1, 0)
				let [ids, lnums]  = s:add_signs(a:sy, nl - 1, 1, 'GsignDelete')
			endif

			for offset in range(0, nc - 1)
				let line = nl + offset
				if s:external_sign_present(a:sy, line) | continue | endif
				let [ids, lnums] += s:add_signs(a:sy, line, 1, 'GsignChange')
			endfor
		endif

		" hunk
		if !empty(ids)
			call add(a:sy.hunks, {
						\ 'ids'  : ids,
						\ 'start': lnums[0],
						\ 'end'  : lnums[-1] })
		endif

		" サインを配置した行を辞書形式で記憶
		for lnum in lnums | let signtable[lnum] = 1 | endfor
	endfor

	" Remove obsoleted signs.
	for line in filter(keys(s:internal), '!has_key(signtable, v:val)')
		execute 'sign unplace' s:internal[line].id 'buffer='.a:sy.buffer
	endfor

	" クリア
	let s:internal = {}
	let s:external = {}
endfunction

"-------------------------------------------------------
" s:write_buffer
"-------------------------------------------------------
function! s:write_buffer(bufnr, file)
	" オリジナルのバッファデータ取得
	let bufcontents = getbufline(a:bufnr, 1, '$')

	" 1行目が存在しないか
	if line2byte(1) == -1
		call writefile([], a:file)
		return
	endif

	" DOS形式の場合、一時ファイルの改行をオリジナルと同じにする。line\n→line\r\nに変換する。(LFをCRLFに変換)
	if getbufvar(a:bufnr, '&fileformat') ==# 'dos'
		call map(bufcontents, 'v:val."\r"')
	endif

	" ファイルエンコーディングと文字エンコーディングが異なる場合はファイルエンコーディングに変換
	let fenc = getbufvar(a:bufnr, '&fileencoding')
	let enc  = getbufvar(a:bufnr, '&encoding')
	if fenc !=# enc
		call map(bufcontents, 'iconv(v:val, "'.enc.'", "'.fenc.'")')
	endif

	" BOM(Byte Of Mark)
	if getbufvar(a:bufnr, '&bomb')
		let bufcontents[0]='﻿'.bufcontents[0]
	endif

  	" 差分を取るための一時ファイルに書き込む
	call writefile(bufcontents, a:file)
endfunction

"-------------------------------------------------------
" s:get_job_gen
"-------------------------------------------------------
function! s:get_job_gen() abort
	" 次のジョブ世代番号(前回の世代+1)を取得
	return get(s:, 'job_gen', 0) + 1
endfunction

"-------------------------------------------------------
" s:get_diff
"-------------------------------------------------------
function! s:get_diff(bufnr) abort
	" 前回のジョブが起動中の場合は停止する
	call glog#job#stop_job(getbufvar(a:bufnr, 'sy_job'))

	let opts = {
				\ 'job_gen'   : s:get_job_gen(),
				\ 'stdoutbuf' : [''],
				\ 'bufnr'     : a:bufnr,
				\ }

	if getbufvar(a:bufnr, '&modified')
		" バッファデータの一時ファイルを作成
		let bufferfile = tempname()
		call s:write_buffer(a:bufnr, bufferfile)

		" commitバージョンの一時ファイルを作成
		let basefile = tempname()

		" コマンドを作成
		let cmd = 'git show HEAD:./' . getbufvar(a:bufnr, 'sy').info.file . '>' . fnameescape(basefile) .
					\ '&& diff -U0 ' . fnameescape(basefile) . ' ' . fnameescape(bufferfile)
		" optsにdifftoolと一時ファイルの情報も記憶
		let opts.difftool  = 'diff'
		let opts.tempfiles = [basefile, bufferfile]

	else
		" コマンドを作成
		let cmd = 'git diff --no-color --no-ext-diff -U0 -- ' . getbufvar(a:bufnr, 'sy').info.file
		" optsにdifftoolの情報も記憶
		let opts.difftool = 'git'
	endif

	" 今回のジョブ世代番号(前回の世代+1)を保存
	call setbufvar(a:bufnr, 'sy_job_gen', opts.job_gen)

	" 差分取得のジョブを開始
	let job = glog#job#start_job(
				\ cmd,
				\ opts,
				\ getbufvar(a:bufnr, 'sy').info.dir,
				\ has('nvim') ? 'gsign#nvim_job_stdout' : 'gsign#vim_job_stdout',
				\ has('nvim') ? 'gsign#nvim_exit' : 'gsign#vim_job_exit'
				\ )

	" 今回の新しいジョブIDを保存
	call setbufvar(a:bufnr, 'sy_job', job)
endfunction

"-------------------------------------------------------
" s:remove_all_signs
"-------------------------------------------------------
function! s:remove_all_signs(bufnr) abort
	let sy = getbufvar(a:bufnr, 'sy', {})

	for hunk in get(sy, 'hunks', [])
		for id in get(hunk, 'ids', [])
			execute 'sign unplace' id 'buffer='.a:bufnr
		endfor
	endfor

	let sy.hunks = []
endfunction

"-------------------------------------------------------
" s:handle_diff
"-------------------------------------------------------
function! s:handle_diff(out, exitval) abort
	" 一時ファイルの削除
	if has_key(a:out, 'tempfiles')
		for f in a:out.tempfiles | call delete(f) | endfor
	endif

	" バッファにb:syが無い(=Gsignが初期化されていないバッファ)は対象外
	let bufnr = a:out.bufnr
	let sy = getbufvar(bufnr, 'sy')
	if empty(sy)
		call s:warning('No b:sy found for ' . bufname(bufnr))
		return
	endif

	" 差分文字列の出力がバッファの文字コード違う場合は変換
	let fenc = getbufvar(bufnr, '&fenc')
	let enc  = getbufvar(bufnr, '&enc')
	if (fenc != enc) && has('iconv')
		call map(a:out.stdoutbuf, printf('iconv(v:val, "%s", "%s")', fenc, enc))
	endif

	" 差分有無をチェック(diffの場合は0が「差分なし」、1が「差分あり」を意味する)
	let found_diff = a:out.difftool == 'diff' ? a:exitval <= 1 : a:exitval == 0
	if found_diff
		if empty(a:out.stdoutbuf)
			" サインを消去
			call s:remove_all_signs(bufnr)
		else
			" hunkにsignを付けるか確認して配置
			call glog#syntax#gsign_line_highlight(get(g:, 'gsign_line_highlight', 0))
			call s:process_diff(sy, a:out.stdoutbuf)
		endif
	endif

	" 「今のジョブだけが最新のジョブである場合だけ、ジョブIDをリセットする」
	" もし古い非同期ジョブの結果が後から戻ってきても、新しいジョブの状態を壊さないようにする。
	" これは、複数回 diff を走らせたときに起きる「古い結果が新しい結果を上書きする」問題を防ぐための安全策。
	if get(a:out, 'job_gen', -1) == getbufvar(bufnr, 'sy_job_gen', -2)
		call setbufvar(bufnr, 'sy_job', 0)
	endif
endfunction

"-------------------------------------------------------
" gsign#nvim_job_stdout
"-------------------------------------------------------
function! gsign#nvim_job_stdout(_job_id, data, _event) dict abort
	let self.stdoutbuf[-1] .= a:data[0]
	call extend(self.stdoutbuf, a:data[1:])
endfunction

"-------------------------------------------------------
" gsign#nvim_exit
"-------------------------------------------------------
function! gsign#nvim_exit(_job_id, exitval, _event) dict abort
	" nvimは終了コールバックの引数に終了コードが直接渡されるため、vimの様な待機処理は不要
	return s:handle_diff(self, a:exitval)
endfunction

"-------------------------------------------------------
" gsign#vim_job_stdout
"-------------------------------------------------------
function! gsign#vim_job_stdout(_job_id, data) dict abort
	" a:dataはジョブが標準出力へ出した1行分の文字列
	" dict:この関数が辞書コンテキストで呼ばれることを示す。get_diff()で本館数登録時にopts辞書を渡して登録している
	" そのため、selfはopts辞書を参照する
	" 'stdoutbuf' ; [''] " で初期化されており、受け取った1行をstdoutbufに追加する
	let self.stdoutbuf += [a:data]
endfunction

"-------------------------------------------------------
" gsign#vim_job_exit
"-------------------------------------------------------
function! gsign#vim_job_exit(job, exitval) dict abort
	return s:handle_diff(self, a:exitval)
endfunction

"-------------------------------------------------------
" gsign#start
"-------------------------------------------------------
function! gsign#start(...) abort
	let bufnr = a:0 ? a:1 : bufnr('')
	let path = resolve(fnamemodify(bufname(bufnr), ':p'))

	if g:gsign_locked | return | endif

	if has('vim_starting') | return | endif

	if getbufvar(bufnr, '&diff') || !filereadable(path) | return | endif

	let sy = getbufvar(bufnr, 'sy')
	if empty(sy)
		let new_sy = {
					\ 'buffer':		bufnr,
					\ 'hunks':		[],
					\ 'signid':		0x100,
					\ 'info':		{
					\    'dir':  fnamemodify(path, ':p:h'),
					\    'file': s:escape(fnamemodify(path, ':t'))
					\ }}
		call setbufvar(bufnr, 'sy', new_sy)
		call s:set_buflocal_autocmds(bufnr)
		call s:get_diff(bufnr)
	else
		" 実行中のジョブが存在するか確認
		" nvimのjobstart()は数値IDを返すが、vimのjob_start()はジョブオフジェクトを返すため以下の判定にする必要がある
		let job = getbufvar(sy.buffer, 'sy_job', 0)
		if type(job) != type(0) || job > 0
		else
			call s:get_diff(sy.buffer)
		endif
	endif
endfunction

"-------------------------------------------------------
" gsign#stop
"-------------------------------------------------------
function! gsign#stop(...) abort
	let bufnr = a:0 ? a:1 : bufnr('')
	if empty(getbufvar(a:0 ? a:1 : bufnr, 'sy')) | return | endif
	call s:remove_all_signs(bufnr)
	execute printf('autocmd! gsign * <buffer=%d>', bufnr)
	call setbufvar(bufnr, 'sy', {})
endfunction

"-------------------------------------------------------
" gsign#toggle
"-------------------------------------------------------
function! gsign#toggle() abort
	call call(empty(getbufvar(bufnr(''), 'sy')) ? 'gsign#start' : 'gsign#stop', [])
endfunction

"-------------------------------------------------------
" gsign#toggle_hl
"-------------------------------------------------------
function! gsign#toggle_hl() abort
	call glog#syntax#gsign_line_highlight(!get(g:, 'gsign_line_highlight', 0))

	redraw!
	call gsign#start()
endfunction

"-------------------------------------------------------
" gsign#jump_hunk
"-------------------------------------------------------
function! gsign#jump_hunk(count, direction)
	let sy = getbufvar(bufnr(''), 'sy')
	if empty(sy) || empty(sy.hunks) | return | endif

	let lnum = line('.')
	if a:direction > 0
		let hunks = filter(copy(b:sy.hunks), 'v:val.start > lnum')
		let hunk  = get(hunks, a:count - 1, get(hunks, -1, {}))
	else
		let hunks = filter(copy(b:sy.hunks), 'v:val.start < lnum')
		let hunk  = get(hunks, 0 - a:count, get(hunks, 0, {}))
	endif

	if !empty(hunk)
		execute 'sign jump '. hunk.ids[0] .' buffer='. b:sy.buffer
	endif
endfunction

"-------------------------------------------------------
" gsign#enable
"-------------------------------------------------------
function! gsign#enable() abort
	for bufnr in range(1, bufnr("$"))
		call gsign#start(bufnr)
	endfor
	let g:gsign_disable = 0
endfunction

"-------------------------------------------------------
" gsign#enable
"-------------------------------------------------------
function! gsign#disable() abort
	for bufnr in range(1, bufnr(''))
		if !empty(getbufvar(bufnr, 'sy'))
			call gsign#stop(bufnr)
		endif
	endfor
	let g:gsign_disable = 1
endfunction
