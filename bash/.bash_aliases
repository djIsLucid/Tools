# ~/.bashrc aliases

## bash
alias ls='ls --color=auto -Isnap'
alias la='ls -a'
alias ll='ls -lh'
alias lah='ls -lah'
alias sl='ls'
alias l='ls'
alias cdgo='cd $GOPATH'
alias install='sudo apt install '
alias bash_colors='cat /home/dj/.bash_colors'
alias lsmyutils='ls -1 ~/.bin/'

## network
alias myip='curl http://ipecho.net/plain; echo'
alias nmap-special-ports='nmap -n -Pn -sT -T4 -p 22,23,25,80,443,4080,4443,5000,1337,1234,4444,8008,8010,8080,8081,10000,19000-19006 '
alias masscan-top-ports='masscan -p$(cat ~/Tools/wordlists/Ports/nmap-portlist.txt) '

# run massdns against a large file of subdomains to see if they resolve
function massdns-filter() {
        massdns -r $RESOLVERS -o S $1 | grep -e ' A ' |  cut -d 'A' -f 1 | rev | cut -d "." -f1 --complement | rev | sort | uniq
}

