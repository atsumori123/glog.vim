let s:save_cpo = &cpoptions
set cpoptions&vim

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

"---------------------------------------------------------------
" s:wrap_cmd
"---------------------------------------------------------------
function! s:wrap_cmd(cmd) abort
	if has('win32')
		if has('nvim')
			let cmd = &shell =~ '\v%(cmd|powershell|pwsh)' ? a:cmd : ['sh', '-c', a:cmd]
		else
			" ex: bash.exe -c (コマンド)
			" -c は「後ろに続く文字列をコマンドとして実行する」という意味
			if &shell =~ 'cmd'
				let cmd = join([&shell, &shellcmdflag, '(', a:cmd, ')'])
			elseif empty(&shellxquote)
				let cmd = join([&shell, &shellcmdflag, &shellquote, a:cmd, &shellquote])
			else
				let cmd = join([&shell, &shellcmdflag, &shellxquote, a:cmd, &shellxquote])
			endif
		endif
	else
		let cmd = ['sh', '-c', a:cmd]
	endif

	return cmd
endfunction

"---------------------------------------------------------------
" glog#job#start_job
"---------------------------------------------------------------
function! glog#job#start_job(cmd, opts, cwd, callback_stdout, callback_exit)
	if has('nvim')
		let job = jobstart(a:cmd, extend(a:opts, {
					\ 'cwd'      : a:cwd,
					\ 'on_stdout': function('s:callback_nvim_stdout'),
					\ 'on_exit'  : function('s:callback_nvim_exit'),
					\ }))
	else
		let opts = {
					\ 'cwd'    : a:cwd,
					\ 'in_io'  : 'null',
					\ 'out_cb' : function(a:callback_stdout, a:opts),
					\ 'exit_cb': function(a:callback_exit, a:opts),
					\ }
		let job = job_start(s:wrap_cmd(a:cmd), opts)
	endif

	return job
endfunction

"---------------------------------------------------------------
" glog#job#start_job_wait (ジョブの終了を待つ)
"---------------------------------------------------------------
function! glog#job#start_job_wait(cmd, cwd)
	let exit  = []
	let lines = []
	let opts = {
				\ 'cwd'     : a:cwd,
				\ 'out_cb'  : { j, str -> add(lines, str) },
				\ 'err_cb'  : { j, str -> add(lines, str) },
				\ 'exit_cb' : { j, code -> add(exit, code) }}
	let job = job_start(s:wrap_cmd(a:cmd), opts)

	" ジョブの終了を待つ
	call ch_close_in(job)
	while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
		sleep 1m
	endwhile

	return [lines, exit[0]]
endfunction

"-------------------------------------------------------
" glog#job#stop_job
"-------------------------------------------------------
function! glog#job#stop_job(job) abort
	if has('nvim')
		if a:job
			silent! call jobstop(a:job)
		endif
	else
		if type(a:job) != type(0)
			silent! call job_stop(a:job)
		endif
	endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
