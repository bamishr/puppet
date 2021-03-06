#!/bin/bash
# ack.sh
export ACK_PAGER_COLOR="${PAGER:-less -R}"

which ack &>/dev/null || alias ack="ack-grep"

alias ackcat="ack --passthru $@"
alias thpppt="ack --thpppt"

# muscle memory alias. I used to have custom recusive grep script named rgrep.
alias rgrep='ack'

# apt.sh
alias dpkg-installed="dpkg -l|grep ^ii|awk '{printf \"%-20s %s\n\", \$2, \$3}'"
alias apt-search="apt-cache search"
alias apt-install="sudo apt-get install"

# cd.sh
alias ..='cd ..'

alias cdd='cd ~/.dotfiles'

# git-prompt.sh
# bash/zsh git prompt support
#
# Copyright (C) 2006,2007 Shawn O. Pearce <spearce@spearce.org>
# Distributed under the GNU General Public License, version 2.0.
#
# This script allows you to see the current branch in your prompt.
#
# To enable:
#
#    1) Copy this file to somewhere (e.g. ~/.git-prompt.sh).
#    2) Add the following line to your .bashrc/.zshrc:
#        source ~/.git-prompt.sh
#    3a) Change your PS1 to call __git_ps1 as
#        command-substitution:
#        Bash: PS1='[\u@\h \W$(__git_ps1 " (%s)")]\$ '
#        ZSH:  PS1='[%n@%m %c$(__git_ps1 " (%s)")]\$ '
#        the optional argument will be used as format string.
#    3b) Alternatively, if you are using bash, __git_ps1 can be
#        used for PROMPT_COMMAND with two parameters, <pre> and
#        <post>, which are strings you would put in $PS1 before
#        and after the status string generated by the git-prompt
#        machinery.  e.g.
#           PROMPT_COMMAND='__git_ps1 "\u@\h:\w" "\\\$ "'
#        will show username, at-sign, host, colon, cwd, then
#        various status string, followed by dollar and SP, as
#        your prompt.
#        Optionally, you can supply a third argument with a printf
#        format string to finetune the output of the branch status
#
# The argument to __git_ps1 will be displayed only if you are currently
# in a git repository.  The %s token will be the name of the current
# branch.
#
# In addition, if you set GIT_PS1_SHOWDIRTYSTATE to a nonempty value,
# unstaged (*) and staged (+) changes will be shown next to the branch
# name.  You can configure this per-repository with the
# bash.showDirtyState variable, which defaults to true once
# GIT_PS1_SHOWDIRTYSTATE is enabled.
#
# You can also see if currently something is stashed, by setting
# GIT_PS1_SHOWSTASHSTATE to a nonempty value. If something is stashed,
# then a '$' will be shown next to the branch name.
#
# If you would like to see if there're untracked files, then you can set
# GIT_PS1_SHOWUNTRACKEDFILES to a nonempty value. If there're untracked
# files, then a '%' will be shown next to the branch name.  You can
# configure this per-repository with the bash.showUntrackedFiles
# variable, which defaults to true once GIT_PS1_SHOWUNTRACKEDFILES is
# enabled.
#
# If you would like to see the difference between HEAD and its upstream,
# set GIT_PS1_SHOWUPSTREAM="auto".  A "<" indicates you are behind, ">"
# indicates you are ahead, "<>" indicates you have diverged and "="
# indicates that there is no difference. You can further control
# behaviour by setting GIT_PS1_SHOWUPSTREAM to a space-separated list
# of values:
#
#     verbose       show number of commits ahead/behind (+/-) upstream
#     legacy        don't use the '--count' option available in recent
#                   versions of git-rev-list
#     git           always compare HEAD to @{upstream}
#     svn           always compare HEAD to your SVN upstream
#
# By default, __git_ps1 will compare HEAD to your SVN upstream if it can
# find one, or @{upstream} otherwise.  Once you have set
# GIT_PS1_SHOWUPSTREAM, you can override it on a per-repository basis by
# setting the bash.showUpstream config variable.
#
# If you would like to see more information about the identity of
# commits checked out as a detached HEAD, set GIT_PS1_DESCRIBE_STYLE
# to one of these values:
#
#     contains      relative to newer annotated tag (v1.6.3.2~35)
#     branch        relative to newer tag or branch (master~4)
#     describe      relative to older annotated tag (v1.6.3.1-13-gdd42c2f)
#     default       exactly matching tag
#
# If you would like a colored hint about the current dirty state, set
# GIT_PS1_SHOWCOLORHINTS to a nonempty value. The colors are based on
# the colored output of "git status -sb".

# __gitdir accepts 0 or 1 arguments (i.e., location)
# returns location of .git repo
__gitdir ()
{
	# Note: this function is duplicated in git-completion.bash
	# When updating it, make sure you update the other one to match.
	if [ -z "${1-}" ]; then
		if [ -n "${__git_dir-}" ]; then
			echo "$__git_dir"
		elif [ -n "${GIT_DIR-}" ]; then
			test -d "${GIT_DIR-}" || return 1
			echo "$GIT_DIR"
		elif [ -d .git ]; then
			echo .git
		else
			git rev-parse --git-dir 2>/dev/null
		fi
	elif [ -d "$1/.git" ]; then
		echo "$1/.git"
	else
		echo "$1"
	fi
}

# stores the divergence from upstream in $p
# used by GIT_PS1_SHOWUPSTREAM
__git_ps1_show_upstream ()
{
	local key value
	local svn_remote svn_url_pattern count n
	local upstream=git legacy="" verbose=""

	svn_remote=()
	# get some config options from git-config
	local output="$(git config -z --get-regexp '^(svn-remote\..*\.url|bash\.showupstream)$' 2>/dev/null | tr '\0\n' '\n ')"
	while read -r key value; do
		case "$key" in
		bash.showupstream)
			GIT_PS1_SHOWUPSTREAM="$value"
			if [[ -z "${GIT_PS1_SHOWUPSTREAM}" ]]; then
				p=""
				return
			fi
			;;
		svn-remote.*.url)
			svn_remote[ $((${#svn_remote[@]} + 1)) ]="$value"
			svn_url_pattern+="\\|$value"
			upstream=svn+git # default upstream is SVN if available, else git
			;;
		esac
	done <<< "$output"

	# parse configuration values
	for option in ${GIT_PS1_SHOWUPSTREAM}; do
		case "$option" in
		git|svn) upstream="$option" ;;
		verbose) verbose=1 ;;
		legacy)  legacy=1  ;;
		esac
	done

	# Find our upstream
	case "$upstream" in
	git)    upstream="@{upstream}" ;;
	svn*)
		# get the upstream from the "git-svn-id: ..." in a commit message
		# (git-svn uses essentially the same procedure internally)
		local svn_upstream=($(git log --first-parent -1 \
					--grep="^git-svn-id: \(${svn_url_pattern#??}\)" 2>/dev/null))
		if [[ 0 -ne ${#svn_upstream[@]} ]]; then
			svn_upstream=${svn_upstream[ ${#svn_upstream[@]} - 2 ]}
			svn_upstream=${svn_upstream%@*}
			local n_stop="${#svn_remote[@]}"
			for ((n=1; n <= n_stop; n++)); do
				svn_upstream=${svn_upstream#${svn_remote[$n]}}
			done

			if [[ -z "$svn_upstream" ]]; then
				# default branch name for checkouts with no layout:
				upstream=${GIT_SVN_ID:-git-svn}
			else
				upstream=${svn_upstream#/}
			fi
		elif [[ "svn+git" = "$upstream" ]]; then
			upstream="@{upstream}"
		fi
		;;
	esac

	# Find how many commits we are ahead/behind our upstream
	if [[ -z "$legacy" ]]; then
		count="$(git rev-list --count --left-right \
				"$upstream"...HEAD 2>/dev/null)"
	else
		# produce equivalent output to --count for older versions of git
		local commits
		if commits="$(git rev-list --left-right "$upstream"...HEAD 2>/dev/null)"
		then
			local commit behind=0 ahead=0
			for commit in $commits
			do
				case "$commit" in
				"<"*) ((behind++)) ;;
				*)    ((ahead++))  ;;
				esac
			done
			count="$behind	$ahead"
		else
			count=""
		fi
	fi

	# calculate the result
	if [[ -z "$verbose" ]]; then
		case "$count" in
		"") # no upstream
			p="" ;;
		"0	0") # equal to upstream
			p="=" ;;
		"0	"*) # ahead of upstream
			p=">" ;;
		*"	0") # behind upstream
			p="<" ;;
		*)	    # diverged from upstream
			p="<>" ;;
		esac
	else
		case "$count" in
		"") # no upstream
			p="" ;;
		"0	0") # equal to upstream
			p=" u=" ;;
		"0	"*) # ahead of upstream
			p=" u+${count#0	}" ;;
		*"	0") # behind upstream
			p=" u-${count%	0}" ;;
		*)	    # diverged from upstream
			p=" u+${count#*	}-${count%	*}" ;;
		esac
	fi

}


# __git_ps1 accepts 0 or 1 arguments (i.e., format string)
# when called from PS1 using command substitution
# in this mode it prints text to add to bash PS1 prompt (includes branch name)
#
# __git_ps1 requires 2 or 3 arguments when called from PROMPT_COMMAND (pc)
# in that case it _sets_ PS1. The arguments are parts of a PS1 string.
# when two arguments are given, the first is prepended and the second appended
# to the state string when assigned to PS1.
# The optional third parameter will be used as printf format string to further
# customize the output of the git-status string.
# In this mode you can request colored hints using GIT_PS1_SHOWCOLORHINTS=true
__git_ps1 ()
{
	local pcmode=no
	local detached=no
	local ps1pc_start='\u@\h:\w '
	local ps1pc_end='\$ '
	local printf_format=' (%s)'

	case "$#" in
		2|3)	pcmode=yes
			ps1pc_start="$1"
			ps1pc_end="$2"
			printf_format="${3:-$printf_format}"
		;;
		0|1)	printf_format="${1:-$printf_format}"
		;;
		*)	return
		;;
	esac

	local g="$(__gitdir)"
	if [ -z "$g" ]; then
		if [ $pcmode = yes ]; then
			#In PC mode PS1 always needs to be set
			PS1="$ps1pc_start$ps1pc_end"
		fi
	else
		local r=""
		local b=""
		if [ -f "$g/rebase-merge/interactive" ]; then
			r="|REBASE-i"
			b="$(cat "$g/rebase-merge/head-name")"
		elif [ -d "$g/rebase-merge" ]; then
			r="|REBASE-m"
			b="$(cat "$g/rebase-merge/head-name")"
		else
			if [ -d "$g/rebase-apply" ]; then
				if [ -f "$g/rebase-apply/rebasing" ]; then
					r="|REBASE"
				elif [ -f "$g/rebase-apply/applying" ]; then
					r="|AM"
				else
					r="|AM/REBASE"
				fi
			elif [ -f "$g/MERGE_HEAD" ]; then
				r="|MERGING"
			elif [ -f "$g/CHERRY_PICK_HEAD" ]; then
				r="|CHERRY-PICKING"
			elif [ -f "$g/BISECT_LOG" ]; then
				r="|BISECTING"
			fi

			b="$(git symbolic-ref HEAD 2>/dev/null)" || {
				detached=yes
				b="$(
				case "${GIT_PS1_DESCRIBE_STYLE-}" in
				(contains)
					git describe --contains HEAD ;;
				(branch)
					git describe --contains --all HEAD ;;
				(describe)
					git describe HEAD ;;
				(* | default)
					git describe --tags --exact-match HEAD ;;
				esac 2>/dev/null)" ||

				b="$(cut -c1-7 "$g/HEAD" 2>/dev/null)..." ||
				b="unknown"
				b="($b)"
			}
		fi

		local w=""
		local i=""
		local s=""
		local u=""
		local c=""
		local p=""

		if [ "true" = "$(git rev-parse --is-inside-git-dir 2>/dev/null)" ]; then
			if [ "true" = "$(git rev-parse --is-bare-repository 2>/dev/null)" ]; then
				c="BARE:"
			else
				b="GIT_DIR!"
			fi
		elif [ "true" = "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]; then
			if [ -n "${GIT_PS1_SHOWDIRTYSTATE-}" ] &&
			   [ "$(git config --bool bash.showDirtyState)" != "false" ]
			then
				git diff --no-ext-diff --quiet --exit-code || w="*"
				if git rev-parse --quiet --verify HEAD >/dev/null; then
					git diff-index --cached --quiet HEAD -- || i="+"
				else
					i="#"
				fi
			fi
			if [ -n "${GIT_PS1_SHOWSTASHSTATE-}" ]; then
				git rev-parse --verify refs/stash >/dev/null 2>&1 && s="$"
			fi

			if [ -n "${GIT_PS1_SHOWUNTRACKEDFILES-}" ] &&
			   [ "$(git config --bool bash.showUntrackedFiles)" != "false" ] &&
			   [ -n "$(git ls-files --others --exclude-standard)" ]
			then
				u="%"
			fi

			if [ -n "${GIT_PS1_SHOWUPSTREAM-}" ]; then
				__git_ps1_show_upstream
			fi
		fi

		local f="$w$i$s$u"
		if [ $pcmode = yes ]; then
			local gitstring=
			if [ -n "${GIT_PS1_SHOWCOLORHINTS-}" ]; then
				local c_red='\e[31m'
				local c_green='\e[32m'
				local c_lblue='\e[1;34m'
				local c_clear='\e[0m'
				local bad_color=$c_red
				local ok_color=$c_green
				local branch_color="$c_clear"
				local flags_color="$c_lblue"
				local branchstring="$c${b##refs/heads/}"

				if [ $detached = no ]; then
					branch_color="$ok_color"
				else
					branch_color="$bad_color"
				fi

				# Setting gitstring directly with \[ and \] around colors
				# is necessary to prevent wrapping issues!
				gitstring="\[$branch_color\]$branchstring\[$c_clear\]"

				if [ -n "$w$i$s$u$r$p" ]; then
					gitstring="$gitstring "
				fi
				if [ "$w" = "*" ]; then
					gitstring="$gitstring\[$bad_color\]$w"
				fi
				if [ -n "$i" ]; then
					gitstring="$gitstring\[$ok_color\]$i"
				fi
				if [ -n "$s" ]; then
					gitstring="$gitstring\[$flags_color\]$s"
				fi
				if [ -n "$u" ]; then
					gitstring="$gitstring\[$bad_color\]$u"
				fi
				gitstring="$gitstring\[$c_clear\]$r$p"
			else
				gitstring="$c${b##refs/heads/}${f:+ $f}$r$p"
			fi
			gitstring=$(printf -- "$printf_format" "$gitstring")
			PS1="$ps1pc_start$gitstring$ps1pc_end"
		else
			# NO color option unless in PROMPT_COMMAND mode
			printf -- "$printf_format" "$c${b##refs/heads/}${f:+ $f}$r$p"
		fi
	fi
}

# git.sh
builtin hash git &>/dev/null && {
  alias g='git'
  alias gti='git'
  alias gexec='git exec'

  export GIT_EDITOR=${EDITOR}
  export GIT_MERGE_AUTOEDIT=no

  # from http://jeetworks.org/node/52
  gcd () {
    STATUS=$(git status 2>/dev/null)
    [[ -z $STATUS ]] && return
    cd "./$(git rev-parse --show-cdup)${1}"
  }
  _gcd () {
    STATUS=$(git status 2>/dev/null)
    [[ -z $STATUS ]] && return
    TARGET="./$(git rev-parse --show-cdup)"
    [[ -d $TARGET ]] && TARGET="${TARGET}/"

    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}$2"
    dirs=$(cd $TARGET; compgen -o dirnames $2)
    opts=$(for i in $dirs; do if [[ $i != ".git" ]]; then echo $i/; fi; done)
    if [[ ${cur} == * ]] ; then
      COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
      return 0
    fi
  }
  complete -o nospace -F _gcd gcd
}

# grep.sh
if $(grep --help 2>/dev/null | grep -q -- --color) ; then
  #colorize grep matches with a nice yellow
  # the LANG=C makes grep deal with multibyte chars better
  alias grep='GREP_COLOR="1;33;40" LANG=C grep --color=auto'
  alias fgrep='GREP_COLOR="1;33;40" LANG=C fgrep --color=auto'

else
  # the LANG=C makes grep deal with multibyte chars better
  alias grep='LANG=C grep'
  alias fgrep='LANG=C fgrep'
fi

# less.sh
# -F auto quit if it fits on screen
# -i search case-insensitive
# -Q no bells!
# -R ansi color support
# -w flash the first new line that scrools in
# -X don't clear screen on quit
export LESS='-FiQRwX'

# don't track history
export LESSHISTFILE='-'

# make less more friendly for non-text input files, see lesspipe(1)
builtin hash lesspipe &>/dev/null && eval "$(lesspipe)"

export PAGER='less'

# -s collapse multiple bank lines
export MANPAGER='less -s'

# Less Colors for Man Pages
export LESS_TERMCAP_mb=$'\E[0;32m' # begin blinking
export LESS_TERMCAP_md=$'\E[0;32m' # begin bold
export LESS_TERMCAP_me=$'\E[0m'    # end mode
export LESS_TERMCAP_se=$'\E[0m'    # end standout-mode
export LESS_TERMCAP_so=$'\E[4m'    # begin standout-mode - info box
export LESS_TERMCAP_ue=$'\E[0m'    # end underline
export LESS_TERMCAP_us=$'\E[0;33m' # begin underline

# ls.sh
# load precompiled color constants
source_file "${BASH_CONF}/ls_colors"
export CLICOLOR=1

alias ls='command ls -bFGh'
$(ls --help 2>&1 | grep -- --color= &>/dev/null) && {
  alias ls='command ls -bCF --color=auto'
}

alias ll='ls -l'
alias lsa='ls -a'
alias lld='ll -d'
alias l.='ls -d .*'

# misc.sh
alias df='df -h'
alias du='du -h'
alias du1='du -h --max-depth=1'

alias bc='bc -l -q'
alias hd='od -Ax -tx1z -v'                    # hexdump
alias cal='cal -3'                            # show 3 months of calendars

alias whence='type -a'                        # where, of a sort

alias screen='screen -R -D'

alias psu='ps U $USER'

alias stardate='date "+%y%m.%d/%H%M"'

# mysql.sh
export MYSQL_PS1="(\u@\h) [\d]> "

# openssl.sh
alias viewcert='openssl x509 -noout -text -in'
alias stelnet='openssl s_client -connect'

# phpenv.sh
[[ -d "${HOME}/.phpenv" ]] &&
add_root_dir "${HOME}/.phpenv"

builtin hash phpenv &>/dev/null && eval "$(phpenv init -)"

# python.sh
[[ -f "${HOME}/bin/python_startup.py" ]] &&
export PYTHONSTARTUP="${HOME}/bin/python_startup.py"

# rbenv.sh
[[ -d "${HOME}/.rbenv" ]] &&
add_root_dir "${HOME}/.rbenv"

builtin hash rbenv &>/dev/null && eval "$(rbenv init -)"

# ssh.sh
alias ssh-rmkey="ssh-keygen -R"

# make ssh_auth_sock consistent for screen/tmux
STICKY_SOCK="$HOME/.ssh/sockets/ssh_auth_sock"
[[ -n "${SSH_AUTH_SOCK}" && "${SSH_AUTH_SOCK}" != "${STICKY_SOCK}" ]] && {
  unlink "${STICKY_SOCK}" 2>/dev/null
  ln -s "${SSH_AUTH_SOCK}" "${STICKY_SOCK}"
  export SSH_AUTH_SOCK="${STICKY_SOCK}"
}
unset STICKY_SOCK

# tmux.sh
builtin hash tmux &>/dev/null && {
  alias t=tmux
  attach () {
    if [[ "$*" ]]; then
      ssh "$*" -t 'tmux attach || tmux new'
    else
      tmux attach || tmux new
    fi
  }
  complete -F _known_hosts attach
}

# vim.sh
if builtin hash vim &>/dev/null ; then
  # don't talk to x server
  alias vim='vim -X'

  # use my vimrc from other accounts
  [[ "${BASH_CONF}" != "${HOME}/.bash" ]] &&
  alias vim="vim -X -u ${BASH_CONF}/../.vimrc -i ~/.viminfo"

else
  # muscle memory is hard to break
  alias vim='vi'
fi

alias e='vim'
alias bim='vim'
alias gim='vim'

# virtualenv.sh
# compatible with virtualenvwrapper created envs
: ${VENV_DIR=${WORKON_HOME:=${HOME}/.virtualenvs}}

venv () {
  local vdir=${VENV_DIR:=${HOME}/.venv}
  local cmd=${1}
  shift

  [[ -d $vdir ]] || mkdir -p "${vdir}"

  case "$cmd" in
    create)
      local name=${1:?env NAME required}
      shift
      if [[ -d "${vdir}/${name}" ]]; then
        printf "${name} already exists. Continue? (y/N) "
        read -e VERIFY
        if [ "y" = "${VERIFY}" -o "Y" = "${VERIFY}" ]; then
          venv destroy "${name}" &&
          venv create "${name}"
          return $?
        else
          echo "Aborting." 1>&2
          return 64
        fi
      fi
      virtualenv --prompt='$(__venv_prompt)' \
        --distribute "$@" "${vdir}/${name}"
      venv use ${name}
      ;;

    destroy)
      local name=${1:?env NAME required}
      shift
      if [[ "${vdir}/${name}" = "${VIRTUAL_ENV}" ]]; then
        printf "${name} is active. Continue? (y/N) "
        read -e VERIFY
        if [ "y" = "${VERIFY}" -o "Y" = "${VERIFY}" ]; then
          deactivate
        else
          echo "Aborting." 1>&2
          return 65
        fi
      fi
      rm -r "${vdir}/${name}"
      ;;

    use|activate)
      local name=${1:?env NAME required}
      shift
      source "${vdir}/${name}/bin/activate"
      ;;

    current)
      echo "${VIRTUAL_ENV:=No virtualenv active.}"
      ;;

    deactivate)
      if builtin type deactivate &>/dev/null; then
        deactivate
      else
        echo "No virtualenv active." 1>&2
      fi
      ;;

    ls)
      for n in ${vdir}/*; do
        [[ -d $n ]] && echo ${n#${vdir}/}
      done
      ;;

    *)
      echo "venv [create <name>]"
      echo "     [destroy <name>]"
      echo "     [use <name>]"
      echo "     [current]"
      echo "     [deactivate]"
      echo "     [ls]"
      ;;
  esac
}

__venv_prompt () {
  echo -e "\[\033[1;30m\][venv:$(basename "$VIRTUAL_ENV")]\[\033[0m\] "
}

__venv_completion () {
  local cur prev opts
  local venvs="$(venv ls)"
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="create destroy use current deactivate ls"

  case "${prev}" in
    destroy)
      COMPREPLY=( $(compgen -W "${venvs}" -- ${cur}) )
      ;;
    use)
      COMPREPLY=( $(compgen -W "${venvs}" -- ${cur}) )
      ;;
    *)
      COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
      ;;
  esac
}
complete -F __venv_completion venv
