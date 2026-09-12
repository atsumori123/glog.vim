let s:save_cpo = &cpoptions
set cpoptions&vim

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
					\ 'on_stdout': function(a:callback_stdout),
					\ 'on_exit'  : function(a:callback_exit),
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
	if has('nvim')
		let opts = {
					\ 'cwd'      : a:cwd,
					\ 'on_stdout': { j, data, event -> extend(lines,
					\ 		empty(data) ? [] : (empty(data[-1]) ? data[0:-2] : data)) },
					\ 'on_stderr': { j, data, event -> extend(lines,
					\ 		empty(data) ? [] : (empty(data[-1]) ? data[0:-2] : data)) }}
		let job = jobstart(s:wrap_cmd(a:cmd), opts)
		let exit = jobwait([job])
	else
		let opts = {
					\ 'cwd'     : a:cwd,
					\ 'in_io'   : 'null',
					\ 'out_cb'  : { j, str -> add(lines, str) },
					\ 'err_cb'  : { j, str -> add(lines, str) },
					\ 'exit_cb' : { j, code -> add(exit, code) }}
		let job = job_start(s:wrap_cmd(a:cmd), opts)

		" ジョブの終了を待つ
		call ch_close_in(job)
		while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
			sleep 1m
		endwhile
	endif

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

"-------------------------------------------------------
" glog#job#stop_job
"-------------------------------------------------------
function! glog#job#exe_job(cmd, cwd) abort
	let save_cwd = getcwd()
	execute 'lcd ' . a:cwd
	try
		let result = systemlist(a:cmd, ' ')
	finally
		execute 'lcd ' . fnameescape(save_cwd)
	endtry
	return [result, v:shell_error]
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
