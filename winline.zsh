#!/usr/bin/env zsh

prompt_preexec() {
	typeset -Fg SECONDS
	ZSH_START_TIME=${ZSH_START_TIME:-$SECONDS}

	HISTCMD_LOCAL=$((++HISTCMD_LOCAL))

	case $TTY in
		/dev/ttyS[0-9]*) return ;;
	esac
}

prompt_precmd() {
	if [ "$ZSH_START_TIME" ]; then
		local DELTA=$((SECONDS - ZSH_START_TIME))
		local DAYS=$((~~(DELTA / 86400)))
		local HOURS=$((~~((DELTA - DAYS * 86400) / 3600)))
		local MINUTES=$((~~((DELTA - DAYS * 86400 - HOURS * 3600) / 60)))
		local SECS=$((DELTA - DAYS * 86400 - HOURS * 3600 - MINUTES * 60))
		local ELAPSED

		[ "$DAYS" -ne 0 ] && ELAPSED="${DAYS}d"
		[ "$HOURS" -ne 0 ] && ELAPSED="${ELAPSED}${HOURS}h"
		[ "$MINUTES" -ne 0 ] && ELAPSED="${ELAPSED}${MINUTES}m"

		if [ -z "$ELAPSED" ]; then
			SECS="$(print -f "%.2f" $SECS)s"
		elif [ "$DAYS" -ne 0 ]; then
			SECS=""
		else
			SECS="$((~~SECS))s"
		fi

		ELAPSED="${ELAPSED}${SECS}"

		export RPS1="%F{cyan}%{$(printf '\033[3m')%}${ELAPSED}%f%{$(printf '\033[0m')%} "
		export RPS3="%F{blue}%~%f"

		unset ZSH_START_TIME
	else
		export RPS3="%F{blue}%~%f"
	fi
}

prompt_chpwd() {
	zle && zle -I
	RPS2=
	zle && [[ $CONTEXT == start ]] && prompt_async
	true
}

prompt_async_precmd() {
	local fd=
	exec {fd}< <( prompt_git_info )
	zle -Fw "$fd" prompt_async_callback
	true
}

prompt_git_info() {
	local REPLY=
	{
		local is_modified=false has_unstaged=false has_untracked=false

		if [ -d ".git" ]; then
			[ -n "$(git diff 2>/dev/null)" ] && is_modified=true
			[ -n "$(git diff --cached 2>/dev/null)" ] && has_staged=true
			[ -n "$(git ls-files --exclude-standard --others 2>/dev/null)" ] && 
				has_untracked=true

			REPLY="[$(git branch --show-current 2>/dev/null)"

			[ "$has_staged" = true ] && REPLY="$REPLY%F{green}●%f"
			[ "$is_modified" = true ] && REPLY="$REPLY%F{red}●%f"
			[ "$has_untracked" = true ] && REPLY="$REPLY%F{blue}●%f"

			REPLY="$REPLY] "
		fi
	} always {
		print -r -- "$RPS1$REPLY$RPS3"
	}
}

prompt_async_callback() {
	local fd=$1 REPLY
	{
		zle -F "$fd"
		read -ru $fd
		[[ $RPROMPT == $REPLY ]] && return
		RPROMPT=$REPLY
		zle && [[ $CONTEXT == start ]] &&
		zle .reset-prompt
	} always {
		exec {fd}<&-
	}
}
zle -N prompt_async_callback

prompt_init() {
	setopt PROMPT_SUBST
	setopt EXTENDED_GLOB

	autoload -Uz add-zsh-hook

	local LVL
	if [ -n "$TMUX" ]; then
		LVL=$((SHLVL-1))
	else
		LVL=$SHLVL
	fi

	local SUFFIX
	if [ "$(id -u)" -eq 0 ]; then
		SUFFIX="%F{yellow}%n%f$(printf '%%F{yellow}❯%.0s%%f' {1..$LVL})"
	else
		SUFFIX=$(printf '%%F{red}❯%.0s%%f' {1..$LVL})
	fi

	export PS1="%F{blue}%B%1~%b%F{yellow}%B%(1j.*.)%(?..!)%b%f %B${SUFFIX}%b "

	add-zsh-hook chpwd prompt_chpwd
	add-zsh-hook preexec prompt_preexec
	add-zsh-hook precmd prompt_precmd
	add-zsh-hook precmd prompt_async_precmd
}

prompt_init
