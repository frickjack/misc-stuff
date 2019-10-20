if [[ -f ~/.aws/config ]]; then
    cat ~/.aws/config | grep '\[' | sed -E 's/\[(profile )?//g' | sed 's/]//g'
fi
