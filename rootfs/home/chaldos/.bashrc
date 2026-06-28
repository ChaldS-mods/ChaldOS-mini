# ChaldOS default user profile
# ~/.bashrc

# Source system profile
[[ -f /etc/profile ]] && . /etc/profile

# User aliases
alias cls='clear'
alias l='ls -CF'
alias ll='ls -la'
alias la='ls -A'

# User prompt
PS1='\[\e[0;32m\]chaldos\[\e[0m\]@\[\e[1;34m\]\h\[\e[0m\]:\[\e[0;33m\]\w\[\e[0m\]$ '

export EDITOR=vi
export BROWSER=w3m
