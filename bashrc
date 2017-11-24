#export NODE_HOME=/usr/local/node-v6.9.4-linux-x64
export GRADLE_HOME=/usr/local/gradle-3.4.1
export SCALA_HOME=/usr/local/scala-2.12.3
PATH="${SCALA_HOME}/bin:${GRADLE_HOME}/bin:${PATH}"

export EDITOR=/usr/bin/vi

alias netup='iwlist wlo1 scan'
# xdg-open === Mac open
# xsel -b === clipboard get/put
alias bootclean="echo 'sudo apt-get purge \$(dpkg -l linux-{image,headers}-"[0-9]*" | awk '/ii/{print $2}' | grep -ve -4.4.0-6)' where current kernel version is uname -r"

alias battery='upower -i $(upower -e | grep battery) | grep -e "time to empty" -e percentage'
alias cp="cp -i"
alias rm="rm -i"
alias mv="mv -i"
alias ls="ls -F"
alias digit='dig +noall +answer'
set -o vi

# see https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
# trash-cli

