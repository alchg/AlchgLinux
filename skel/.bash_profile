#
# ~/.bash_profile
#

export XDG_CURRENT_DESKTOP=unspecified
[[ -f ~/.bashrc ]] && . ~/.bashrc
[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec sway
