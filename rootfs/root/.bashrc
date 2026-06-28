# Root user profile for ChaldOS
# ~/.bashrc

# Source system profile
[[ -f /etc/profile ]] && . /etc/profile

# ChaldOS-specific aliases
alias rebuild='chaldos-info'
alias refresh='. ~/.bashrc'
alias cls='clear'
alias l='ls -CF'
alias ll='ls -la'
alias la='ls -A'
alias vi='vi -c "set background=dark"'

# Prompt
PS1='\[\e[1;31m\]chaldos\[\e[0m\]@\[\e[1;34m\]\h\[\e[0m\]:\[\e[0;33m\]\w\[\e[0m\]# '

# ChaldOS greeting
cat /etc/motd 2>/dev/null
