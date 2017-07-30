" Vim indent file
" Language:         Shell Script
" Maintainer:       Clavelito <maromomo@hotmail.com>
" Last Change:      Fri, 14 Jul 2017 12:21:06 +0900
" Version:          4.42
"
" Description:
"                   let g:sh_indent_case_labels = 0
"                            case $a in
"                            label)
"
"                   let g:sh_indent_case_labels = 1
"                            case $a in
"                                label)
"                                                    (default: 1)
"
"                   let g:sh_indent_and_or_or = 0
"                            foo &&
"                            bar
"
"                   let g:sh_indent_and_or_or = 1
"                            foo &&
"                                bar
"                                                    (default: 1)


if exists("b:did_indent") || !exists("g:syntax_on")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetShIndent()
setlocal indentkeys=0},0{,0),0(,!^F,o,O
setlocal indentkeys+=0=then,0=do,0=else,0=elif,0=fi,0=esac,0=done,0=;;,0=;&

let b:undo_indent = 'setlocal indentexpr< indentkeys<'

if exists("*GetShIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let s:back_quote = 'shCommandSub'
let s:sh_comment = 'Comment'
let s:test_d_or_s_quote = 'TestDoubleQuote\|TestSingleQuote'
let s:d_or_s_quote = 'DoubleQuote\|SingleQuote\|DblQuote\|SnglQuote'
let s:sh_quote = 'shQuote'
let s:sh_here_doc = 'HereDoc'
let s:sh_here_doc_eof = 'HereDoc\d\d\|shRedir\d\d'

if !exists("g:sh_indent_case_labels")
  let g:sh_indent_case_labels = 1
endif
if !exists("g:sh_indent_and_or_or")
  let g:sh_indent_and_or_or = 1
endif

function GetShIndent()
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif

  if exists("b:sh_indent_tabstop")
    let &tabstop = b:sh_indent_tabstop
    unlet b:sh_indent_tabstop
  endif
  if exists("b:sh_indent_indentkeys")
    let &indentkeys = b:sh_indent_indentkeys
    unlet b:sh_indent_indentkeys
  endif

  let cline = getline(v:lnum)
  let line = getline(lnum)

  if cline =~ '^#'
    return 0
  endif

  for cid in reverse(synstack(lnum, strlen(line)))
    let cname = synIDattr(cid, 'name')
    if cname =~ s:sh_here_doc. '$'
      let lnum = s:SkipItemsLines(v:lnum, s:sh_here_doc.'\|'. s:sh_here_doc_eof)
      let ind = s:InsideHereDocIndent(lnum, cline)
      return ind
    elseif cname =~ s:test_d_or_s_quote
          \ && s:EndOfTestQuotes(line, lnum, s:test_d_or_s_quote)
      break
    elseif cname =~ s:d_or_s_quote
      return indent(v:lnum)
    endif
  endfor

  let [line, lnum] = s:SkipCommentLine(line, lnum, 0)
  let line = s:BlankOrContinue(line, lnum, v:lnum - 1)
  let ind = s:BackQuoteIndent(lnum, 0)
  for lid in synstack(lnum, 1)
    let lname = synIDattr(lid, 'name')
    if lname =~ s:sh_here_doc_eof
      let lnum = s:SkipItemsLines(lnum, s:sh_here_doc. '\|'. s:sh_here_doc_eof)
      let line = s:GetNextContinueLine(getline(lnum), lnum)
      break
    elseif lname =~ s:d_or_s_quote. '\|'. s:sh_quote
      let [line, lnum, ind] = s:GetQuoteHeadAndTail(line, lnum, ind)
      break
    elseif lname =~ s:back_quote && ind < 0
      let [line, lnum, ind] = s:GetBackQuoteHeadAndTail(line, lnum, ind)
      break
    endif
  endfor

  let ind = indent(lnum) + ind
  let [pline, pnum] = s:SkipCommentLine(line, lnum, 1)
  let pline = s:BlankOrContinue(pline, pnum, lnum - 1)
  let [pline, ind] = s:MorePrevLineIndent(pline, pnum, line, ind)
  let [line, ind] = s:InsideCaseLabelIndent(pline, line, ind)
  let ind = s:PrevLineIndent(line, lnum, pline, ind)
  let ind = s:CurrentLineIndent(line, lnum, cline, pline, ind)

  return ind
endfunction

function s:MorePrevLineIndent(pline, pnum, line, ind)
  let ind = a:ind
  let pline = a:pline
  let line = a:line
  if s:IsTailBackSlash(a:pline) && s:IsTailBackSlash(a:line)
    let pline = s:GetPrevContinueLine(a:pline, a:pnum)
    if s:IsOutSideCase(pline) && s:IsTailNoContinue(line)
      let line = s:HideTailNoContinue(line)
    endif
  elseif s:IsOutSideCase(a:pline) && s:IsTailNoContinue(line)
    let line = s:HideTailNoContinue(line)
  endif
  if !s:IsTailBackSlash(a:pline) && s:IsTailBackSlash(line)
        \ && s:IsOutSideCase(a:pline) && !g:sh_indent_and_or_or
        \ || !s:IsContinuLine(a:pline) && s:IsContinuLine(line)
        \ && s:IsOutSideCase(a:pline) && g:sh_indent_and_or_or
    let ind = ind + s:sw()
  elseif s:IsContinuLine(a:pline) && !s:IsContinuLine(line)
        \ || s:IsTailBackSlash(a:pline) && !s:IsTailBackSlash(line)
        \ && !g:sh_indent_and_or_or
    let [pline, ind] = s:GetContinueLineIndent(a:pline, a:pnum, 1)
    if s:IsInSideCase(pline) && a:pline !~# '^\s*esac\>'
          \ || s:IsTailNoContinue(a:pline)
      let ind = a:ind
    endif
  endif

  return [pline, ind]
endfunction

function s:InsideCaseLabelIndent(pline, line, ind)
  let ind = a:ind
  let line = s:HideAnyItemLine(a:line)
  if line =~ ')' && a:line !~# '^\s*case\>' && s:IsInSideCase(a:pline)
    let [line, ind] = s:CaseLabelLineIndent(line, ind)
  elseif a:line =~ ';[;&]\s*$' && a:line !~# '^\s*case\>\%(.\{-}\<esac\>\)\@!'
    let ind = s:CaseBreakIndent(ind)
  elseif s:IsTailBackSlash(a:line) && s:IsInSideCase(a:pline)
    let line = ""
  endif

  return [line, ind]
endfunction

function s:PrevLineIndent(line, lnum, pline, ind)
  let ind = a:ind
  if a:line =~# '^\s*\%(\h\w*\|\S\+\)\s*(\s*)\s*[{(]\s*$'
        \. '\|^\s*function\s\+\S\+\%(\s\+{\|\s*(\s*)\s*[{(]\)\s*$'
    let ind = ind + s:sw()
  else
    let line2 = getline(a:lnum)
    let line = s:HideAnyItemLine2(a:line)
    let ind = s:ParenBraceIndent(a:pline, line2, line, a:lnum, ind)
    let ind = s:CloseParenIndent(a:pline, line, ind)
    let ind = s:CloseBraceIndnnt(a:pline, line2, line, ind)
    if line =~# '[|`(]'
      for line in split(line, '[|`(]')
        let ind = s:PrevLineIndent2(line, ind)
      endfor
    else
      let ind = s:PrevLineIndent2(line, ind)
    endif
  endif

  return ind
endfunction

function s:PrevLineIndent2(line, ind)
  let ind = a:ind
  if a:line =~# '^\s*\%(if\|then\|else\|elif\)\>'
        \ && a:line !~# '[;&]\s*\<fi\>'
        \ || a:line =~# '^\s*\%(do\|while\|until\|for\|select\)\>'
        \ && a:line !~# '[;&]\s*\<done\>'
    let ind = ind + s:sw()
  elseif a:line =~# '^\s*case\>'
        \ && a:line !~# ';[;&]\s*\<esac\>' && g:sh_indent_case_labels
    let ind = ind + s:sw() / g:sh_indent_case_labels
  endif

  return ind
endfunction

function s:CurrentLineIndent(line, lnum, cline, pline, ind)
  let ind = a:ind
  if a:cline =~# '^\s*esac\>' && a:line !~ ';[;&]\s*$'
    let ind = s:CaseBreakIndent(ind)
  endif
  if a:cline =~# '^\s*\%(;;\|;&\|;;&\)\s*\%(#.*\)\=$'
    let ind = s:CaseBreakIndent(ind) + s:sw()
  elseif a:cline =~# '^\s*\%(then\|do\|else\|elif\|fi\|done\)\>[-=+.]\@!'
        \ || a:cline =~ '^\s*[})]' && !s:IsTailBackSlash(a:line)
    let ind = ind - s:sw()
  elseif a:cline =~# '^\s*[{(]\s*\%(#.*\)\=$'
        \ && s:IsTailAndOr(a:line) && s:IsOutSideCase(a:pline)
    let ind = s:GetContinueLineIndent(a:line, a:lnum)
  elseif a:cline =~# '^\s*esac\>' && g:sh_indent_case_labels
    let ind = ind - s:sw() / g:sh_indent_case_labels
  endif
  if ind != a:ind
        \ && a:cline =~# '^\s*\%(then\|do\|else\|elif\|fi\|done\|esac\|[{(]\)$'
    call s:OvrdIndentKeys(a:cline)
  endif

  return ind
endfunction

function s:CloseParenIndent(pline, nline, ind)
  let ind = a:ind
  if a:nline =~ ')' && a:nline !~# '^\s*case\>'
        \ && a:nline !~# ';[;&]\s*$' && s:IsOutSideCase(a:pline)
    let ind = s:CloseParenIndent2(a:nline, ind)
  endif

  return ind
endfunction

function s:CloseBraceIndnnt(pline, line, nline, ind)
  let ind = a:ind
  if a:nline =~# '[;&]\%(\s*\%(done\|fi\|esac\)\)\=\s*}\|^\s\+}'
        \ && a:nline !~# ';[;&]\s*$' && s:IsOutSideCase(a:pline)
    if a:line =~ '^\s*}'
      let ind = ind + s:sw()
    endif
    let ind = ind - s:sw() * (len(split(a:nline,
          \ '[;&]\%(\C\s*\%(done\|fi\|esac\)\)\=\s*}\|^\s\+}', 1)) - 1)
  endif

  return ind
endfunction

function s:ParenBraceIndent(pline, line2, line, lnum, ind)
  let ind = a:ind
  if a:line =~ '(\|\%(&&\||\)\s*{'
    let ind = ind + s:sw() * (len(split(a:line, '(\|\%(&&\||\)\s*{', 1)) - 1)
  endif
  if a:line2 =~ '^\s*{' && s:IsOutSideCase(a:pline)
    let line = s:HideCommentStr(getline(a:lnum - 1), a:lnum - 1)
    if !s:IsTailBackSlash(line) || s:IsTailNoContinue(line)
      let ind = ind + s:sw() * (len(split(a:line2, '^\s*{', 1)) - 1)
    endif
  elseif a:line =~ '^\s*{' && s:IsInSideCase(a:pline) && a:line !~# ';[;&]\s*$'
    let ind = ind + s:sw() * (len(split(a:line, '^\s*{', 1)) - 1)
  endif

  return ind
endfunction

function s:SkipCommentLine(line, lnum, prev)
  let line = a:line
  let lnum = a:lnum
  if a:prev && s:GetPrevNonBlank(lnum)
    let lnum = s:prev_lnum
    let line = getline(lnum)
  elseif a:prev
    let line = ""
    let lnum = 0
  endif
  while lnum && line =~ '^\s*#' && s:GetPrevNonBlank(lnum)
        \ && synIDattr(synID(lnum, match(line,'#')+1,1),"name") =~ s:sh_comment
    let lnum = s:prev_lnum
    let line = getline(lnum)
  endwhile
  unlet! s:prev_lnum
  let line = s:HideCommentStr(line, lnum)

  return [line, lnum]
endfunction

function s:GetContinueLineIndent(pline, pnum, ...)
  let [pline, line, lnum] = s:GetPrevContinueLine(a:pline, a:pnum, 1)
  let ind = s:BackQuoteIndent(lnum, 0)
  if s:MatchSynId(lnum, 1, s:d_or_s_quote. '\|'. s:sh_quote)
    let [line, lnum, ind] = s:GetQuoteHeadAndTail(line, lnum, ind)
  endif
  let ind = indent(lnum) + ind
  let [line, ind] = s:InsideCaseLabelIndent(pline, line, ind)
  let ind = s:PrevLineIndent(line, lnum, pline, ind)

  if a:0
    return [pline, ind]
  else
    return ind
  endif
endfunction

function s:GetPrevContinueLine(line, lnum, ...)
  let line = a:line
  let lnum = a:lnum
  let line = s:HideCommentStr(line, lnum)
  let last_line = ""
  let last_lnum = 0
  let ContinueCheck = g:sh_indent_and_or_or || s:IsTailAndOr(line)
        \ ? function('s:IsContinuLine') : function('s:IsTailBackSlash')
  while call(ContinueCheck, [line]) && s:GetPrevNonBlank(lnum)
    let blank = lnum - 1 == s:prev_lnum ? 0 : 1
    let last_line = substitute(line, '\\$', '', ''). last_line
    let last_lnum = lnum
    let lnum = s:prev_lnum
    let line = getline(lnum)
    let [line, lnum] = s:SkipCommentLine(line, lnum, 0)
    if s:IsTailBackSlash(line) && (blank || lnum != s:prev_lnum)
      break
    endif
  endwhile
  unlet! s:prev_lnum

  if a:0 && lnum == 1 && s:IsContinuLine(line)
    return ["", substitute(line, '\\$', '', ''). last_line, lnum]
  elseif a:0
    return [line, last_line, last_lnum]
  else
    return line
  endif
endfunction

function s:GetNextContinueLine(line, lnum)
  let line = a:line
  let lnum = a:lnum
  while s:IsContinuLine(line) && s:GetNextNonBlank(lnum)
    let lnum = s:next_lnum
    let line = getline(lnum)
  endwhile
  unlet! s:next_lnum

  return line
endfunction

function s:GetPrevNonBlank(lnum)
  let s:prev_lnum = prevnonblank(a:lnum - 1)

  return s:prev_lnum
endfunction

function s:GetNextNonBlank(lnum)
  let s:next_lnum = nextnonblank(a:lnum + 1)

  return s:next_lnum
endfunction

function s:CloseParenIndent2(line, ind)
  let ind = a:ind
  let lnum = v:lnum
  let pline = a:line
  let sum = len(split(pline, ')', 1)) - 1
  let items = s:d_or_s_quote. '\|'. s:sh_quote. '\|'. s:sh_here_doc_eof
  while sum && s:GetPrevNonBlank(lnum)
    if s:MatchSynId(s:prev_lnum, 1, items)
      let lnum = s:SkipItemsLines(s:prev_lnum, items. '\|'. s:sh_here_doc)
    else
      let lnum = s:prev_lnum
    endif
    let line = getline(lnum)
    if line =~# '^\s*#'
      continue
    endif
    let [pline, pnum] = s:SkipCommentLine(line, lnum, 1)
    let pline = s:GetPrevContinueLine(pline, pnum)
    let line = s:HideCommentStr(line, lnum)
    let line = s:HideAnyItemLine(line)
    let line = s:HideAnyItemLine2(line)
    if line =~ ')' && line !~# '^\s*case\>' && s:IsOutSideCase(pline)
          \ && lnum != s:GetPrevNonBlank(v:lnum)
      let sum += len(split(line, ')', 1)) - 1
    elseif line =~# '('
      let sum -= len(split(line, '(', 1)) - 1
    endif
  endwhile
  unlet! s:prev_lnum
  if !sum && lnum && exists("l:line")
    let [line, ind] = s:InsideCaseLabelIndent(pline, line, indent(lnum))
    let ind = s:PrevLineIndent2(line, ind)
  endif

  return ind
endfunction

function s:CaseBreakIndent(ind)
  let ind = a:ind
  let lnum = v:lnum
  let sum = 0
  let items = s:d_or_s_quote. '\|'. s:sh_quote. '\|'. s:sh_here_doc_eof
  while !sum && s:GetPrevNonBlank(lnum)
    if s:MatchSynId(s:prev_lnum, 1, items)
      let lnum = s:SkipItemsLines(s:prev_lnum, items. '\|'. s:sh_here_doc)
    else
      let lnum = s:prev_lnum
    endif
    let nind = indent(lnum)
    if nind < ind
      let line = getline(lnum)
      if line =~# '^\s*case\>'
        break
      elseif line =~ '^\s*#'
        continue
      elseif line =~ ')'
        let [pline, pnum] = s:SkipCommentLine(line, lnum, 1)
        let pline = s:GetPrevContinueLine(pline, pnum)
        if s:IsInSideCase(pline)
          let line = s:HideCommentStr(line, lnum)
          let line = s:HideAnyItemLine(line)
          let [line, sum] = s:CaseLabelLineIndent(line, sum)
        endif
      endif
      let ind = nind
    endif
  endwhile
  unlet! s:prev_lnum

  return ind
endfunction

function s:CaseLabelLineIndent(line, ind)
  let line = a:line
  let ind = a:ind
  let head = ""
  let sum = 1
  let i = matchend(line, '\s*(\=')
  let sphead = substitute(strpart(line, 0, i), '($', ' ', '')
  let slist = split(line, '\zs')
  let max = len(slist)
  while sum && i < max
    if slist[i] == '('
      let sum += 1
    elseif slist[i] == ')'
      let sum -= 1
    endif
    let head .= slist[i]
    let i += 1
  endwhile
  if sum == 0
    let line = strpart(line, strlen(head) + strlen(sphead))
    let llen = strdisplaywidth(head)
    while llen
      let line = " ". line
      let llen -= 1
    endwhile
    let line = sphead. line
    if line !~# '^\s*$' && line !~# ';[;&]\s*$'
      let ind = strdisplaywidth(strpart(line, 0, matchend(line, '\s*')))
    else
      let ind = ind + s:sw()
    endif
  endif
  if line =~ ';[;&]\s*$'
    let ind = ind - s:sw()
  endif

  return [line, ind]
endfunction

function s:GetItemLenSpaces(line, item)
  let pos = match(a:line, a:item)
  let line = strpart(a:line, pos)
  if line =~# '^\\'
    let line = strpart(line, 0, 2)
  else
    let line = strpart(line, 0, matchend(line, strpart(line, 0, 1), 1))
  endif
  let len = strdisplaywidth(line, pos)
  let line = ""
  while len
    let line .= " "
    let len -= 1
  endwhile

  return line
endfunction

function s:HideAnyItemLine(line)
  let line = a:line
  if line =~ '[|&`(){}]'
    while line =~# '\\.'
      let line = substitute(line, '\\.', s:GetItemLenSpaces(line, '\\'), '')
    endwhile
    while line =~# '\("\|\%o47\|`\).\{-}\1'
      let line = substitute(line,
            \ '\("\|\%o47\|`\).\{-}\1',
            \ s:GetItemLenSpaces(line, '"\|\%o47\|`') ,'')
    endwhile
  endif

  return line
endfunction

function s:HideAnyItemLine2(line)
  let line = a:line
  if line =~ '[()]'
    let len = 0
    while len != strlen(line)
      let len = strlen(line)
      let line = substitute(line, '[$=]\=([^()]*)', '', 'g')
    endwhile
  endif

  return line
endfunction

function s:GetTabAndSpaceSum(cline, cind, sstr, sind)
  if a:cline =~ '^\t'
    let tbind = matchend(a:cline, '\t*', 0)
  else
    let tbind = 0
  endif
  let spind = a:cind - tbind * &tabstop
  if a:sstr =~ '<<-' && a:sind
    let tbind = a:sind / &tabstop
  endif

  return [tbind, spind]
endfunction

function s:InsideHereDocIndent(snum, cline)
  let sstr = getline(a:snum)
  if !&expandtab && sstr =~ '<<-' && !strlen(a:cline)
    let ind = indent(a:snum)
  else
    let ind = indent(v:lnum)
  endif
  if !&expandtab && a:cline =~ '^\t'
    let sind = indent(a:snum)
    let [tbind, spind] = s:GetTabAndSpaceSum(a:cline, ind, sstr, sind)
    if spind >= &tabstop
      let b:sh_indent_tabstop = &tabstop
      let &tabstop = spind + 1
    endif
    let ind = tbind * &tabstop + spind
  elseif &expandtab && a:cline =~ '^\t' && sstr =~ '<<-'
    let tbind = matchend(a:cline, '\t*', 0)
    let ind = ind - tbind * &tabstop
  endif

  return ind
endfunction

function s:SkipItemsLines(lnum, item)
  let lnum = a:lnum
  while lnum
    if s:MatchSynId(lnum, 1, a:item) && s:GetPrevNonBlank(lnum)
      let lnum = s:prev_lnum
      unlet! s:prev_lnum
    else
      unlet! s:prev_lnum
      break
    endif
  endwhile

  return lnum
endfunction

function s:HideCommentStr(line, lnum)
  let line = a:line
  if a:lnum && line =~ '\\\@<!\%(\\\\\)*#'
        \ && line =~ '\%(\${\%(\h\w*\|\d\+\)#\=\|\${\=\)\@<!#'
    let sum = match(line, '#', 0)
    while sum > -1
      if synIDattr(synID(a:lnum, sum + 1, 1), "name") =~ s:sh_comment
        let line = strpart(line, 0, sum)
        break
      endif
      let sum = match(line, '#', sum + 1)
    endwhile
  endif

  return line
endfunction

function s:HideQuoteStr(line, lnum, rev)
  let line = a:line
  let sum = match(a:line, '\%o47\|"', 0)
  while sum > -1
    let n = 0
    for cid in reverse(synstack(a:lnum, sum + 1))
      let cname = synIDattr(cid, 'name')
      if !n && cname =~ s:sh_quote && a:rev
        let line = strpart(a:line, sum + 1)
        let n += 1
      elseif !n && cname =~ s:sh_quote
        let n += 1
      elseif n && cname =~ s:d_or_s_quote
        let line = strpart(a:line, 0, sum)
        break
      else
        break
      endif
    endfor
    if n && !a:rev
      break
    endif
    let sum = match(a:line, '\%o47\|"', sum + 1)
  endwhile

  return line
endfunction

function s:BackQuoteIndent(lnum, ind)
  let line = getline(a:lnum)
  let ind = a:ind
  if line !~# '\\\@<!\%(\\\\\)*`'
    return ind
  endif
  let lnum = s:SkipItemsLines(a:lnum, s:back_quote)
  let sum = 0
  let csum = 0
  let pnum = 0
  let save_cursor = getpos(".")
  call cursor(lnum, 1)
  while search('\\\@<!\%(\\\\\)*`', 'eW', a:lnum)
    let lnum = line(".")
    if s:MatchSynId(lnum, col("."), s:back_quote)
      let sum += 1
      if pnum != lnum
        let csum = 1
      else
        let csum += 1
      endif
      let pnum = lnum
    endif
  endwhile
  call setpos(".", save_cursor)
  if sum % 2 && csum % 2
    let ind += s:sw()
  elseif !(sum % 2) && csum % 2
    let ind -= s:sw()
  endif

  return ind
endfunction

function s:MatchSynId(lnum, colnum, item)
  let sum = 0
  for cid in synstack(a:lnum, a:colnum)
    if synIDattr(cid, 'name') =~ a:item
      let sum = 1
      break
    endif
  endfor

  return sum
endfunction

function s:GetQuoteHeadAndTail(line, lnum, ind)
  let line = s:HideQuoteStr(a:line, a:lnum, 1)
  let lnum = s:SkipItemsLines(a:lnum, s:d_or_s_quote. '\|'. s:sh_quote)
  let line = s:HideQuoteStr(getline(lnum), lnum, 0). line
  let ind = s:BackQuoteIndent(lnum, a:ind)

  return [line, lnum, ind]
endfunction

function s:GetBackQuoteHeadAndTail(line, lnum, ind)
  let tline = a:line
  let lnum = a:lnum
  let ind = a:ind
  let sum = match(tline, '\\\@<!\%(\\\\\)*\zs`')
  let lsum = 0
  while sum > -1 && s:MatchSynId(lnum, sum + 1, s:back_quote)
    let lsum = sum + 1
    let sum = match(tline, '\\\@<!\%(\\\\\)*\zs`', lsum)
  endwhile
  let tline = strpart(tline, lsum)
  while ind < 0 && s:GetPrevNonBlank(lnum)
    let lnum = s:prev_lnum
    let ind = s:BackQuoteIndent(lnum, ind)
  endwhile
  unlet! s:prev_lnum
  let line = getline(lnum)
  let sum = match(line, '\\\@<!\%(\\\\\)*\zs`')
  while sum > -1
    if synIDattr(synID(lnum, sum + 1, 1), "name") =~ s:back_quote
      let line = strpart(line, 0, sum)
      break
    endif
    let sum = match(line, '\\\@<!\%(\\\\\)*\zs`', sum + 1)
  endwhile

  return [line. tline, lnum, ind]
endfunction

function s:OvrdIndentKeys(line)
  let b:sh_indent_indentkeys = &indentkeys
  setlocal indentkeys+=a,b,c,d,<e>,f,g,h,i,j,k,l,m,n,<o>,p,q,r,s,t,u,v,w,x,y,z
  setlocal indentkeys+=A,B,C,D,E,F,G,H,I,J,K,L,M,N,<O>,P,Q,R,S,T,U,V,W,X,Y,Z
  setlocal indentkeys+=1,2,3,4,5,6,7,8,9,<0>,_,-,=,+,.
  if a:line =~# '^\s*do$'
    setlocal indentkeys-=n
    setlocal indentkeys+=<Space>,*<CR>
  elseif a:line =~# '^\s*[{(]$'
    setlocal indentkeys+={,(
  endif
endfunction

function s:BlankOrContinue(line, lnum, lnum2)
  if s:IsTailBackSlash(a:line) && a:lnum != a:lnum2
    return substitute(a:line, '\\$', '', '')
  else
    return a:line
  endif
endfunction

function s:HideTailNoContinue(line)
  return substitute(a:line, '\%(;\||\)\s*\\$', '', '')
endfunction

function s:IsTailAndOr(line)
  return a:line =~# '\%(&&\|||\)\s*\\\=$'
endfunction

function s:IsTailBackSlash(line)
  return a:line =~# '\\\@<!\%(\\\\\)*\\$' && a:line !~# '\%(&&\|||\)\s*\\$'
endfunction

function s:IsTailNoContinue(line)
  return a:line =~# ';\@<!;\s*\\$' || a:line =~# '|\@<!|\s*\\$'
endfunction

function s:IsContinuLine(line)
  return a:line =~# '\\\@<!\%(\\\\\)*\\$\|\%(&&\|||\)\s*$'
endfunction

function s:IsOutSideCase(line)
  return a:line !~# '\%(^\|[|&`()]\)\s*case\>\%(.*;[;&]\s*\<esac\>\)\@!'
        \ && a:line !~# ';[;&]\s*$'
endfunction

function s:IsInSideCase(line)
  return a:line =~# '\%(^\|[|&`()]\)\s*case\>\%(.*;[;&]\s*\<esac\>\)\@!'
        \ || a:line =~# ';[;&]\s*$'
endfunction

function s:EndOfTestQuotes(line, lnum, item)
  return a:line =~ '^\%("\|\%o47\)$'
        \ || a:line =~ '\\\@<!\%(\\\\\)*\%("\|\%o47\)$'
        \ && synIDattr(synID(a:lnum, strlen(a:line) - 1, 1), "name") =~ a:item
endfunction

function s:sw()
  return exists("*shiftwidth") ? shiftwidth() : &sw
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sts=2 sw=2 expandtab:
