# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block, everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
bindkey -v
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/acidghost/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall


source ~/antigen.zsh

antigen use oh-my-zsh

antigen bundle battery
antigen bundle colorize
antigen bundle colored-man-pages
antigen bundle docker
antigen bundle emoji
antigen bundle fancy-ctrl-z
antigen bundle git
antigen bundle gitignore
antigen bundle themes
antigen bundle tmux
antigen bundle vi-mode
antigen bundle virtualenv
antigen bundle web-search
antigen bundle z

antigen bundle chriskempson/base16-shell

antigen theme romkatv/powerlevel10k

antigen apply

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# dotfiles management
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

export EDITOR=vim
export ZSH_TMUX_FIXTERM=true

[[ -d ~/.local/bin ]] && export PATH="$PATH:$HOME/.local/bin"
[[ -d ~/.cargo/bin ]] && export PATH="$PATH:$HOME/.cargo/bin"
[[ -e ~/.path ]] && source ~/.path

# Aliases
alias ta='tmux attach'
alias tat='tmux attach -t'

for i in `seq 10`; do
    alias "tree$i"="tree -L $i"
    alias "dh$i"="du -h -d $i"
done

local xmobar_bin='xmobar-top'
alias xmobar_move_next="kill -USR1 \$(pidof $xmobar_bin)"
alias xmobar_move_current="kill -USR2 \$(pidof $xmobar_bin)"
unset xmobar_bin

for f in /sys/bus/hid/drivers/razerkbd/*; do
    if [[ -d "$f" ]] && [[ -f "$f/matrix_effect_static" ]]; then
        _RZR_DBUS_DIR="$f"

        rzr_brightness() {
            if [[ -z "$1" ]]; then
                cat "$_RZR_DBUS_DIR/matrix_brightness"
            else
                printf '%d' $1 > "$_RZR_DBUS_DIR/matrix_brightness"
            fi
        }

        alias rzr_off="rzr_brightness 0"
        alias rzr_default_fx="printf '\\x00\\xff\\x00' > $f/matrix_effect_static"
        alias rzr_alert_fx="rzr_brightness 255 && printf '\\xff\\x00\\x00' > $f/matrix_effect_breath"

        break
    fi
done
unset f

# Simple, handy commands. For bigger ones, use a separate file.

show_off() {
    clear && python3 -c "print('\n' * 6)" && neofetch $* && python3 -c "print('\n' * 6)"
}

vusec_show_off() {
    show_off --source ~/vusec.ascii --ascii_colors 0 1 2 3 4 5 6 7 8
}

gvb_start() {
    local pid_file="$HOME/.gvb-service.pid"
    if [[ -f "$pid_file" ]]; then
        echo 'GVB service is already running...'
        return -1
    fi
    nohup gvb-service > "$HOME/.log/gvb-service.log" > /dev/null 2>&1 &
    echo $! > "$pid_file"
}

gvb_stop() {
    local pid_file="$HOME/.gvb-service.pid"
    if [[ -f "$pid_file" ]]; then
        kill -9 `cat "$pid_file"`
        rm "$pid_file"
    fi
}

