# vim:ft=zsh ts=2 sw=2 sts=2
# clear's Theme base on:
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://github.com/Lokaltog/powerline-fonts).
# Make sure you have a recent version: the code points that Powerline
# uses changed in 2012, and older versions will display incorrectly,
# in confusing ways.
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](https://iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# If using with "light" variant of the Solarized color schema, set
# SOLARIZED_THEME variable to "light". If you don't specify, we'll assume
# you're using the "dark" variant.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

ZLE_RPROMPT_INDENT=0

CURRENT_BG='NONE'

case ${SOLARIZED_THEME:-dark} in
    light) CURRENT_FG='white';;
    *)     CURRENT_FG='black';;
esac

# Special Powerline characters

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  # NOTE: This segment separator character is correct.  In 2012, Powerline changed
  # the code points they use for their special characters. This is the new code point.
  # If this is not working for you, you probably have an old version of the
  # Powerline-patched fonts installed. Download and install the new version.
  # Do not submit PRs to change this unless you have reviewed the Powerline code point
  # history and have new information.
  # This is defined using a Unicode escape sequence so it is unambiguously readable, regardless of
  # what font the user is viewing this source code in. Do not replace the
  # escape sequence with a single literal character.
  # Do not change this! Do not make it '\u2b80'; that is the old, wrong code point.
  LSEGMENT_SEPARATOR=%1{$'\ue0b0'%}
  RSEGMENT_SEPARATOR=%1{$'\ue0b2'%}
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_lsegment() {
  local bg fg
  [[ -n $1 ]] && bg="%{%K{$1}%}" || bg="%{%k%}"
  [[ -n $2 ]] && fg="%{%F{$2}%}" || fg="%{%f%}"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n "$bg%{%F{$CURRENT_BG}%}$LSEGMENT_SEPARATOR$fg"
  else
    echo -n "$bg$fg"
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}
prompt_rsegment() {
  local bg fg
  [[ -n $1 ]] && bg="%{%K{$1}%}" || bg="%{%k%}"
  [[ -n $2 ]] && fg="%{%F{$2}%}" || fg="%{%f%}"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n "%{%F{$1}%}$RSEGMENT_SEPARATOR$fg$bg"
  else
    echo -n "$bg$fg"
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}
prompt_segment() {
  [[ $PROMPTLEFT -eq 0 ]] && prompt_lsegment $1 $2 $3 || prompt_rsegment $1 $2 $3
}

# End the left prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n "%{%k%F{$CURRENT_BG}%}$LSEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%b%}"
  CURRENT_BG=''
}

# Start the right prompt, closing any open segments
rprompt_start() {
  CURRENT_BG='invalid'
  echo -n "%f%b"
}

# End the right prompt, closing any open segments
rprompt_end() {
  echo -n "%{%f%b%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ "$USERNAME" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    if [[ $UID == 0 || $EUID == 0 ]]; then
      prompt_segment green red "%n"
    else
      prompt_segment green black "%n"
    fi
    prompt_segment green black "@"
    if [[ "$SSH_CONNECTION" != "" ]]; then
      prompt_segment green yellow "%m"
    else
      prompt_segment green black "%m"
    fi
  fi
}

prompt_level() {
  if [[ $SHLVL > 1 ]]; then
    prompt_segment white black $SHLVL
  fi
}

git_info() {
  # Exit if not inside a Git repository
  ! git rev-parse --is-inside-work-tree > /dev/null 2>&1 && return

  # Git branch/tag, or name-rev if on detached head
  local GIT_LOCATION=${$(git symbolic-ref -q HEAD || git name-rev --name-only --no-undefined --always HEAD)#(refs/heads/|tags/)}

  local AHEAD="%1{⇡%}NUM"
  local BEHIND="%1{⇣%}NUM"
  local MERGING="%1{%F{red}↯%f%}"
  local UNTRACKED="%1{%F{black}●%f%}"
  local MODIFIED="%1{%F{red}●%f%}"
  local STAGED="%1{%F{green}●%}%f"

  local DIVERGENCES
  local FLAGS

  local NUM_AHEAD="$(git log --oneline @{u}.. 2> /dev/null | wc -l | tr -d ' ')"
  if [ "$NUM_AHEAD" -gt 0 ]; then
    DIVERGENCES+="${AHEAD//NUM/$NUM_AHEAD}"
  fi

  local NUM_BEHIND="$(git log --oneline ..@{u} 2> /dev/null | wc -l | tr -d ' ')"
  if [ "$NUM_BEHIND" -gt 0 ]; then
    DIVERGENCES+="${BEHIND//NUM/$NUM_BEHIND}"
  fi

  local GIT_DIR="$(git rev-parse --git-dir 2> /dev/null)"
  if [ -n $GIT_DIR ] && test -r $GIT_DIR/MERGE_HEAD; then
    FLAGS+=$MERGING
  fi

  if [[ -n $(git ls-files --other --exclude-standard 2> /dev/null) ]]; then
    FLAGS+=$UNTRACKED
  fi

  if ! git diff --quiet 2> /dev/null; then
    FLAGS+=$MODIFIED
  fi

  if ! git diff --cached --quiet 2> /dev/null; then
    FLAGS+=$STAGED
  fi

  prompt_segment yellow black
  echo -n $GIT_LOCATION$DIVERGENCES$FLAGS
}


# Git: branch/detached head, dirty status
prompt_git() {
  (( $+commands[git] )) || return
  if [[ "$(git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]; then
    return
  fi
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\ue0a0'         # 
  }
  local ref dirty mode repo_path

  if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]; then
    repo_path=$(git rev-parse --git-dir 2>/dev/null)
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      prompt_segment yellow black
    else
      prompt_segment green $CURRENT_FG
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' check-for-staged-changes true
    zstyle ':vcs_info:*' stagedstr '+'
    zstyle ':vcs_info:*' unstagedstr '*'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info
    echo -n "${ref/refs\/heads\//$PL_BRANCH_CHAR}${vcs_info_msg_0_%%}${mode}"
  fi
}

prompt_bzr() {
  (( $+commands[bzr] )) || return

  # Test if bzr repository in directory hierarchy
  local dir="$PWD"
  while [[ ! -d "$dir/.bzr" ]]; do
    [[ "$dir" = "/" ]] && return
    dir="${dir:h}"
  done

  local bzr_status status_mod status_all revision
  if bzr_status=$(bzr status 2>&1); then
    status_mod=$(echo -n "$bzr_status" | head -n1 | grep "modified" | wc -m)
    status_all=$(echo -n "$bzr_status" | head -n1 | wc -m)
    revision=${$(bzr log -r-1 --log-format line | cut -d: -f1):gs/%/%%}
    if [[ $status_mod -gt 0 ]] ; then
      prompt_segment yellow black "bzr@$revision ✚"
    else
      if [[ $status_all -gt 0 ]] ; then
        prompt_segment yellow black "bzr@$revision"
      else
        prompt_segment green black "bzr@$revision"
      fi
    fi
  fi
}

prompt_hg() {
  (( $+commands[hg] )) || return
  local rev st branch
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        prompt_segment red white
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        # if any modification
        prompt_segment yellow black
        st='±'
      else
        # if working copy is clean
        prompt_segment green $CURRENT_FG
      fi
      echo -n ${$(hg prompt "☿ {rev}@{branch}"):gs/%/%%} $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if `hg st | grep -q "^\?"`; then
        prompt_segment red black
        st='±'
      elif `hg st | grep -q "^[MA]"`; then
        prompt_segment yellow black
        st='±'
      else
        prompt_segment green $CURRENT_FG
      fi
      echo -n "☿ ${rev:gs/%/%%}@${branch:gs/%/%%}" $st
    fi
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment blue grey '%~'
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  if [[ -n "$VIRTUAL_ENV" && -n "$VIRTUAL_ENV_DISABLE_PROMPT" ]]; then
    prompt_segment blue black "(${VIRTUAL_ENV:t:gs/%/%%})"
  fi
}

# Anaconda environment
prompt_conda() {
  if [[ -v CONDA_DEFAULT_ENV && $CONDA_DEFAULT_ENV != "base" ]]; then
    prompt_segment green white $CONDA_DEFAULT_ENV
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local -a symbols

  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

#AWS Profile:
# - display current AWS_PROFILE name
# - displays yellow on red if profile name contains 'production' or
#   ends in '-prod'
# - displays black on green otherwise
prompt_aws() {
  [[ -z "$AWS_PROFILE" || "$SHOW_AWS_PROMPT" = false ]] && return
  case "$AWS_PROFILE" in
    *-prod|*production*) prompt_segment red yellow  "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
    *) prompt_segment green black "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
  esac
}

preexec () {
   PREEXEC_TIME=$(date +%s%3N)
}

precmd() {
  PRECMD_TIME=$(date +%s%3N)
  if (( ${+PREEXEC_TIME} )); then
    ((CMD_ELAPSED = $PRECMD_TIME - $PREEXEC_TIME))
    unset PREEXEC_TIME
  fi
}

format_milliseconds()
{
  ((ms = $1 % 1000))
  ((s = $1 / 1000))
  if [[ $s -lt 10 ]]; then
    printf "%d.%03d\n" $s $ms
  elif [[ $s -lt 60 ]]; then
    ((ds = ($ms + 50) / 100))
    printf "%d.%01d\n" $s $ds
  else
    ((m = $s / 60))
    ((s = $s % 60))
    if [[ $m -lt 60 ]]; then
      printf "%d:%02d\n" $m $s
    else
      ((h = $m / 60))
      ((m = $m % 60))
      printf "%d:%02d:%02d\n" $h $m $s
    fi
  fi
}

prompt_elapsed() {
  if (( ${+CMD_ELAPSED} )); then
    prompt_segment blue black $(format_milliseconds $CMD_ELAPSED)
  fi
}

prompt_time() {
  CURRENT_DATE=$(date +"%Y-%m-%d")
  LAST_PROMPED_DATE=$(cat /dev/shm/last_prompted_date_$$ 2>/dev/null)
  if [[ $CURRENT_DATE != $LAST_PROMPED_DATE ]]; then
    prompt_segment magenta black '%D{%Y-%m-%d %H:%M:%S}'
    echo $CURRENT_DATE > /dev/shm/last_prompted_date_$$
  else
    prompt_segment magenta black '%D{%H:%M:%S}'
  fi
}

prompt_retval() {
  if [ $RETVAL -ge 129 ] && [ $RETVAL -le 192 ]
  then
    prompt_segment red black "$RETVAL($(kill -l $(($RETVAL - 128))))"
  elif [[ $RETVAL -ne 0 ]]
  then
    prompt_segment red black "$RETVAL"
  fi
}

prompt_processes() {
  JOBS=$(jobs -l | wc -l)
  [[ $JOBS -gt 0 ]] && prompt_segment cyan black "$JOBS"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  PROMPTLEFT=0
  prompt_virtualenv
  prompt_context
  prompt_dir
#  prompt_git
  prompt_conda
  git_info
  prompt_retval
  prompt_end
}

## Right prompt
build_rprompt() {
  RETVAL=$?
  PROMPTLEFT=1
  rprompt_start
  prompt_processes
  prompt_elapsed
  prompt_time
  prompt_level
  rprompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt)'
RPROMPT='%{%f%b%k%}$(build_rprompt)'

