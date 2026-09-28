#!/usr/bin/env bash
#
# shell-segments.sh — Split a Bash tool command into simple commands for hooks
#
# Usage: source this file, then
#
#   shell_segments "$COMMAND"
#   i=0
#   while [ "$i" -lt "$SH_NSEG" ]; do
#     if sh_git_segment "$i" && [ "$SH_GIT_SUB" = "push" ]; then
#       …inspect "${SH_GIT_ARGS[@]}"…
#     fi
#     i=$((i + 1))
#   done
#
# Why: a regex over the whole command string blocks text that only mentions a
# command (echo 'git commit -m "x"' >> notes.txt; gh pr create --base main after
# a git push) and misses forms it didn't foresee (git -C dir commit). This lexer
# follows the shell's rules closely enough for policy checks:
#
#   - A segment is one simple command. Segments split at ; & && || | |& and
#     newlines, at ( and ), and at the edges of $( ) and ` `, whose contents are
#     segments of their own.
#   - Words lose their quotes and escapes ('…', "…", $'…', \x). Variables and
#     globs are not expanded.
#   - Redirections are not words. A heredoc body or a here-string becomes the
#     segment's stdin.
#   - $(cat <<EOF … EOF) becomes its heredoc text, the way the shell expands it —
#     the form Claude Code writes commit messages in. Any other $( ) stays as
#     its literal text.
#   - Comments are skipped. The script given to bash/sh -c, and eval's
#     arguments, are lexed as further segments.
#
# Pure bash (3.2+): no subprocess, no python3 or jq.
#
# Results (globals):
#   SH_NSEG            number of segments
#   SH_WORDS[]         the words of every segment, back to back
#   SH_SEG_START[i]    index in SH_WORDS of segment i's first word
#   SH_SEG_LEN[i]      number of words in segment i
#   SH_SEG_STDIN[i]    heredoc / here-string text fed to segment i (unset if none)

_SH_ASSIGN_RE='^[A-Za-z_][A-Za-z0-9_]*\+?='
_SH_NL=$'\n'
_SH_TAB=$'\t'

shell_segments() {  # COMMAND
  SH_NSEG=0
  SH_WORDS=()
  SH_SEG_START=()
  SH_SEG_LEN=()
  SH_SEG_STDIN=()
  # Byte-wise: ${s:i:1} is O(1) in the C locale, O(i) in a multibyte one.
  _SH_LC_SET=${LC_ALL+1}
  _SH_LC_OLD=${LC_ALL-}
  LC_ALL=C
  _sh_lex_string "$1"
  # A script handed to a shell or to eval runs too: lex it as more segments.
  local i=0 k n script
  while [ "$i" -lt "$SH_NSEG" ]; do
    sh_seg_command "$i"
    n=${#SH_W[@]}
    script=""
    case "${SH_W[0]-}" in
      bash|sh|zsh|dash|ksh|*/bash|*/sh|*/zsh|*/dash|*/ksh)
        k=1
        while [ "$k" -lt "$n" ]; do
          case "${SH_W[$k]}" in
            -o|+o|-O|+O) k=$((k + 1)) ;;
            --*) ;;
            -*c*) script=${SH_W[$((k + 1))]-}; break ;;
            -*|+*) ;;
            *) break ;;
          esac
          k=$((k + 1))
        done
        ;;
      eval)
        if [ "$n" -gt 1 ]; then script="${SH_W[*]:1}"; fi
        ;;
    esac
    if [ -n "$script" ]; then
      _sh_lex_string "$script"
    fi
    i=$((i + 1))
  done
  if [ -n "$_SH_LC_SET" ]; then LC_ALL=$_SH_LC_OLD; else unset LC_ALL; fi
  return 0
}

# sh_seg_words IDX — SH_W = the words of segment IDX
sh_seg_words() {
  SH_W=()
  local start=${SH_SEG_START[$1]-0} len=${SH_SEG_LEN[$1]-0}
  if [ "$len" -gt 0 ]; then
    SH_W=("${SH_WORDS[@]:start:len}")
  fi
  return 0
}

# sh_seg_command IDX — SH_W = the words of segment IDX from its command word on:
# leading VAR=value assignments, keywords (if, then, do, !, {, …) and wrappers
# (sudo, env, command, exec, nohup, nice, time) with their options are dropped.
sh_seg_command() {
  sh_seg_words "$1"
  local k=0 n=${#SH_W[@]} wrapped=false
  while [ "$k" -lt "$n" ]; do
    case "${SH_W[$k]}" in
      '!'|'{'|then|do|else|elif|if|while|until) ;;
      time|command|builtin|exec|nohup|sudo|env|nice) wrapped=true ;;
      -*)
        if [ "$wrapped" = false ]; then break; fi
        ;;
      *)
        if ! [[ "${SH_W[$k]}" =~ $_SH_ASSIGN_RE ]]; then break; fi
        ;;
    esac
    k=$((k + 1))
  done
  if [ "$k" -ge "$n" ]; then
    SH_W=()
  elif [ "$k" -gt 0 ]; then
    SH_W=("${SH_W[@]:k}")
  fi
  return 0
}

# sh_git_segment IDX — when segment IDX runs git, sets SH_GIT_SUB (the
# subcommand), SH_GIT_ARGS (the words after it) and SH_GIT_CWD (the directory
# given with -C, "" if none), skipping git's own options (-c k=v, -C dir,
# --git-dir …). Returns 1 when the segment doesn't run a git subcommand.
sh_git_segment() {
  sh_seg_command "$1"
  SH_GIT_SUB=""
  SH_GIT_ARGS=()
  SH_GIT_CWD=""
  case "${SH_W[0]-}" in
    git|*/git) ;;
    *) return 1 ;;
  esac
  local k=1 n=${#SH_W[@]} w
  while [ "$k" -lt "$n" ]; do
    w=${SH_W[$k]}
    case "$w" in
      -C)
        k=$((k + 1))
        w=${SH_W[$k]-}
        case "$w" in
          /*|'') SH_GIT_CWD=$w ;;
          *) SH_GIT_CWD=${SH_GIT_CWD:+$SH_GIT_CWD/}$w ;;
        esac
        ;;
      -c|--git-dir|--work-tree|--namespace|--config-env|--super-prefix) k=$((k + 1)) ;;
      -*) ;;
      *) break ;;
    esac
    k=$((k + 1))
  done
  if [ "$k" -ge "$n" ]; then
    return 1
  fi
  SH_GIT_SUB=${SH_W[$k]}
  if [ $((k + 1)) -lt "$n" ]; then
    SH_GIT_ARGS=("${SH_W[@]:$((k + 1))}")
  fi
  return 0
}

# sh_git_commit_parse — read SH_GIT_ARGS as `git commit` arguments. Sets
#   SH_COMMIT_MSG / SH_COMMIT_HAS_MSG=1     the first -m / --message value
#   SH_COMMIT_FILE / SH_COMMIT_HAS_FILE=1   the -F / --file value
#   SH_COMMIT_ALL=1                         -a / --all
#   SH_COMMIT_NOVERIFY=1                    -n / --no-verify
#   SH_COMMIT_PATHS[]                       pathspecs
# Short options cluster (-am "msg", -m"msg", -aF file); -m, -F, -c, -C and -t
# take a value, so `-mn` is the message "n", not -n.
sh_git_commit_parse() {
  SH_COMMIT_MSG=""
  SH_COMMIT_HAS_MSG=0
  SH_COMMIT_FILE=""
  SH_COMMIT_HAS_FILE=0
  SH_COMMIT_ALL=0
  SH_COMMIT_NOVERIFY=0
  SH_COMMIT_PATHS=()
  local k=0 n=${#SH_GIT_ARGS[@]} w opts opt val
  while [ "$k" -lt "$n" ]; do
    w=${SH_GIT_ARGS[$k]}
    k=$((k + 1))
    case "$w" in
      --)
        while [ "$k" -lt "$n" ]; do
          SH_COMMIT_PATHS+=("${SH_GIT_ARGS[$k]}")
          k=$((k + 1))
        done
        ;;
      --message=*) _sh_commit_msg "${w#--message=}" ;;
      --message) _sh_commit_msg "${SH_GIT_ARGS[$k]-}"; k=$((k + 1)) ;;
      --file=*) _sh_commit_file "${w#--file=}" ;;
      --file) _sh_commit_file "${SH_GIT_ARGS[$k]-}"; k=$((k + 1)) ;;
      --all) SH_COMMIT_ALL=1 ;;
      --no-verify) SH_COMMIT_NOVERIFY=1 ;;
      --verify) SH_COMMIT_NOVERIFY=0 ;;
      --author|--date|--template|--reuse-message|--reedit-message|--fixup|--squash|--cleanup|--trailer|--pathspec-from-file) k=$((k + 1)) ;;
      --*) ;;
      -?*)
        opts=${w#-}
        while [ -n "$opts" ]; do
          opt=${opts:0:1}
          opts=${opts:1}
          case "$opt" in
            m|F|c|C|t)
              if [ -n "$opts" ]; then
                val=$opts
              else
                val=${SH_GIT_ARGS[$k]-}
                k=$((k + 1))
              fi
              if [ "$opt" = "m" ]; then _sh_commit_msg "$val"; fi
              if [ "$opt" = "F" ]; then _sh_commit_file "$val"; fi
              opts=""
              ;;
            S|u) opts="" ;;  # optional value, only ever attached
            a) SH_COMMIT_ALL=1 ;;
            n) SH_COMMIT_NOVERIFY=1 ;;
          esac
        done
        ;;
      *) SH_COMMIT_PATHS+=("$w") ;;
    esac
  done
  return 0
}

_sh_commit_msg() {
  if [ "$SH_COMMIT_HAS_MSG" = 0 ]; then
    SH_COMMIT_MSG=$1
    SH_COMMIT_HAS_MSG=1
  fi
  return 0
}

_sh_commit_file() {
  SH_COMMIT_FILE=$1
  SH_COMMIT_HAS_FILE=1
  return 0
}

# --- lexer ------------------------------------------------------------------
# The input is split into lines (each keeps its newline), and _sh_lex reads the
# current line _SH_S from position _SH_I: ${s:i:1} measures the whole string on
# every call, so one long string would make the lexer quadratic. The helpers
# below read and write _sh_lex's locals (seg, cur, have, redir, words, hd_*)
# through bash's dynamic scope.

_sh_lex_string() {  # STRING — lex STRING as a script of its own
  local _SH_S="" _SH_I=0 _SH_N=0 _SH_LN=0 rest=$1 line
  local -a _SH_LINES=()
  while [ -n "$rest" ]; do
    line=${rest%%"$_SH_NL"*}
    _SH_LINES+=("$line$_SH_NL")
    if [ "$line" = "$rest" ]; then
      break
    fi
    rest=${rest:${#line}+1}
  done
  _sh_lex 0
}

# Load the next line; returns 1 at the end of the input.
_sh_next_line() {
  if [ "$_SH_LN" -ge "${#_SH_LINES[@]}" ]; then
    return 1
  fi
  _SH_S=${_SH_LINES[$_SH_LN]}
  _SH_LN=$((_SH_LN + 1))
  _SH_I=0
  _SH_N=${#_SH_S}
  return 0
}

_sh_lex() {  # SUBST — with SUBST=1, return at the ) that closes a $(
  local subst=$1 depth=0 c n
  local seg=-1 cur="" have=0 redir="" hd_next_strip=0
  local -a words=() hd_delim=() hd_strip=() hd_seg=()
  while [ "$_SH_I" -lt "$_SH_N" ] || _sh_next_line; do
    c=${_SH_S:_SH_I:1}
    case "$c" in
      ' '|$'\t')
        _sh_word_end
        _SH_I=$((_SH_I + 1))
        ;;
      $'\n')
        _sh_seg_end
        _SH_I=$((_SH_I + 1))
        _sh_heredocs
        ;;
      ';')
        _sh_seg_end
        _SH_I=$((_SH_I + 1))
        ;;
      '&')
        n=${_SH_S:_SH_I+1:1}
        if [ "$n" = ">" ]; then
          # &> and &>> redirect stdout and stderr
          _sh_word_end
          redir=file
          if [ "${_SH_S:_SH_I+2:1}" = ">" ]; then _SH_I=$((_SH_I + 3)); else _SH_I=$((_SH_I + 2)); fi
        else
          _sh_seg_end
          if [ "$n" = "&" ]; then _SH_I=$((_SH_I + 2)); else _SH_I=$((_SH_I + 1)); fi
        fi
        ;;
      '|')
        _sh_seg_end
        n=${_SH_S:_SH_I+1:1}
        if [ "$n" = "|" ] || [ "$n" = "&" ]; then _SH_I=$((_SH_I + 2)); else _SH_I=$((_SH_I + 1)); fi
        ;;
      '(')
        _sh_seg_end
        depth=$((depth + 1))
        _SH_I=$((_SH_I + 1))
        ;;
      ')')
        _sh_seg_end
        if [ "$depth" -gt 0 ]; then
          depth=$((depth - 1))
        elif [ "$subst" = 1 ]; then
          return 0  # _SH_I stays on the ); _sh_subst steps past it
        fi
        _SH_I=$((_SH_I + 1))
        ;;
      '<'|'>')
        _sh_redir
        ;;
      '\')
        n=${_SH_S:_SH_I+1:1}
        if [ "$n" != $'\n' ]; then  # \<newline> joins lines
          cur+=$n
          have=1
        fi
        _SH_I=$((_SH_I + 2))
        ;;
      "'")
        _sh_squote
        ;;
      '"')
        _sh_dquote
        ;;
      '`')
        _sh_backtick
        ;;
      '$')
        n=${_SH_S:_SH_I+1:1}
        if [ "$n" = "(" ]; then
          _sh_subst
        elif [ "$n" = "'" ]; then
          _sh_ansi_c
        else
          cur+=$c
          have=1
          _SH_I=$((_SH_I + 1))
        fi
        ;;
      '#')
        if [ "$have" = 0 ]; then
          _sh_comment
        else
          cur+=$c
          _SH_I=$((_SH_I + 1))
        fi
        ;;
      *)
        cur+=$c
        have=1
        _SH_I=$((_SH_I + 1))
        ;;
    esac
  done
  _sh_seg_end
  return 0
}

_sh_seg_open() {
  if [ "$seg" = -1 ]; then
    seg=$SH_NSEG
    SH_NSEG=$((SH_NSEG + 1))
    SH_SEG_START[$seg]=0
    SH_SEG_LEN[$seg]=0
  fi
  return 0
}

_sh_word_end() {
  if [ "$have" = 0 ]; then
    return 0
  fi
  case "$redir" in
    file) ;;  # a redirection target, not an argument
    heredoc)
      _sh_seg_open
      hd_delim+=("$cur")
      hd_strip+=("$hd_next_strip")
      hd_seg+=("$seg")
      ;;
    herestr)
      _sh_seg_open
      SH_SEG_STDIN[$seg]="${SH_SEG_STDIN[$seg]-}$cur"$'\n'
      ;;
    *)
      _sh_seg_open
      words+=("$cur")
      ;;
  esac
  redir=""
  cur=""
  have=0
  return 0
}

_sh_seg_end() {
  _sh_word_end
  redir=""
  if [ "$seg" != -1 ]; then
    SH_SEG_START[$seg]=${#SH_WORDS[@]}
    SH_SEG_LEN[$seg]=${#words[@]}
    if [ "${#words[@]}" -gt 0 ]; then
      SH_WORDS+=("${words[@]}")
    fi
    words=()
    seg=-1
  fi
  return 0
}

# After a newline: read the bodies of the heredocs opened on that line.
_sh_heredocs() {
  local k=0 line body
  while [ "$k" -lt "${#hd_delim[@]}" ]; do
    body=""
    while _sh_next_line; do
      line=${_SH_S%"$_SH_NL"}
      _SH_I=$_SH_N
      if [ "${hd_strip[$k]}" = 1 ]; then
        line=${line#"${line%%[!"$_SH_TAB"]*}"}  # <<- strips leading tabs
      fi
      if [ "$line" = "${hd_delim[$k]}" ]; then
        break
      fi
      body+=$line$'\n'
    done
    SH_SEG_STDIN[${hd_seg[$k]}]="${SH_SEG_STDIN[${hd_seg[$k]}]-}$body"
    k=$((k + 1))
  done
  hd_delim=()
  hd_strip=()
  hd_seg=()
  return 0
}

_sh_redir() {
  # An all-digit word right before the operator is its fd (2>, 1>&2).
  if [ "$have" = 1 ] && [ -n "$cur" ] && [ -z "${cur//[0-9]/}" ]; then
    cur=""
    have=0
  fi
  _sh_word_end
  case "${_SH_S:_SH_I:3}" in
    '<<<'*) redir=herestr; _SH_I=$((_SH_I + 3)) ;;
    '<<-'*) redir=heredoc; hd_next_strip=1; _SH_I=$((_SH_I + 3)) ;;
    '<<'*) redir=heredoc; hd_next_strip=0; _SH_I=$((_SH_I + 2)) ;;
    '<('*|'>('*) _SH_I=$((_SH_I + 1)) ;;  # process substitution: ( is lexed as a subshell
    '>>'*|'>|'*|'<>'*|'>&'*|'<&'*) redir=file; _SH_I=$((_SH_I + 2)) ;;
    *) redir=file; _SH_I=$((_SH_I + 1)) ;;
  esac
  return 0
}

_sh_squote() {
  local rest
  _SH_I=$((_SH_I + 1))
  have=1
  while :; do
    rest=${_SH_S:_SH_I}
    if [[ "$rest" == *"'"* ]]; then
      rest=${rest%%\'*}
      cur+=$rest
      _SH_I=$((_SH_I + ${#rest} + 1))
      return 0
    fi
    cur+=$rest  # the quote runs on into the next line
    _SH_I=$_SH_N
    if ! _sh_next_line; then
      return 0
    fi
  done
}

_sh_ansi_c() {  # $'…'
  local c n
  _SH_I=$((_SH_I + 2))
  have=1
  while [ "$_SH_I" -lt "$_SH_N" ] || _sh_next_line; do
    c=${_SH_S:_SH_I:1}
    if [ "$c" = "'" ]; then
      _SH_I=$((_SH_I + 1))
      return 0
    fi
    if [ "$c" = '\' ]; then
      n=${_SH_S:_SH_I+1:1}
      case "$n" in
        n) cur+=$'\n' ;;
        t) cur+=$'\t' ;;
        *) cur+=$n ;;
      esac
      _SH_I=$((_SH_I + 2))
    else
      cur+=$c
      _SH_I=$((_SH_I + 1))
    fi
  done
  return 0
}

_sh_dquote() {
  local c n
  _SH_I=$((_SH_I + 1))
  have=1
  while [ "$_SH_I" -lt "$_SH_N" ] || _sh_next_line; do
    c=${_SH_S:_SH_I:1}
    case "$c" in
      '"')
        _SH_I=$((_SH_I + 1))
        return 0
        ;;
      '\')
        n=${_SH_S:_SH_I+1:1}
        case "$n" in
          '"'|'\'|'$'|'`') cur+=$n ;;
          $'\n') ;;
          *) cur+=$c$n ;;
        esac
        _SH_I=$((_SH_I + 2))
        ;;
      '$')
        if [ "${_SH_S:_SH_I+1:1}" = "(" ]; then
          _sh_subst
        else
          cur+=$c
          _SH_I=$((_SH_I + 1))
        fi
        ;;
      '`')
        _sh_backtick
        ;;
      *)
        cur+=$c
        _SH_I=$((_SH_I + 1))
        ;;
    esac
  done
  return 0
}

# $( … ): its commands are segments; in the word it is the heredoc text when it
# is exactly `cat <<EOF … EOF`, else its literal text ($(...) when it spans lines).
_sh_subst() {
  local start=$_SH_I line=$_SH_LN first=$SH_NSEG text='$(...)'
  _SH_I=$((_SH_I + 2))
  _sh_lex 1
  _SH_I=$((_SH_I + 1))
  if [ "$_SH_LN" = "$line" ]; then
    text=${_SH_S:start:_SH_I-start}
  fi
  if [ "$SH_NSEG" -eq $((first + 1)) ] && [ "${SH_SEG_LEN[$first]}" = 1 ] \
    && [ "${SH_WORDS[${SH_SEG_START[$first]}]}" = "cat" ] && [ -n "${SH_SEG_STDIN[$first]+x}" ]; then
    text=${SH_SEG_STDIN[$first]}
    while [ "${text%"$_SH_NL"}" != "$text" ]; do
      text=${text%"$_SH_NL"}  # $( ) drops trailing newlines
    done
  fi
  cur+=$text
  have=1
  return 0
}

_sh_backtick() {
  local rest inner=""
  _SH_I=$((_SH_I + 1))
  while :; do
    rest=${_SH_S:_SH_I}
    if [[ "$rest" == *'`'* ]]; then
      rest=${rest%%\`*}
      inner+=$rest
      _SH_I=$((_SH_I + ${#rest} + 1))
      break
    fi
    inner+=$rest
    _SH_I=$_SH_N
    if ! _sh_next_line; then
      break
    fi
  done
  cur+="\`$inner\`"
  have=1
  _sh_lex_string "$inner"
}

_sh_comment() {  # # at a word start runs to the end of the line
  local rest=${_SH_S:_SH_I} line
  line=${rest%%"$_SH_NL"*}
  _SH_I=$((_SH_I + ${#line}))
  return 0
}
