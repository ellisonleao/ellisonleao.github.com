#!/bin/bash
set -e


function p() {
    printf "\033[0;32m${1}\033[0m\n"
}

if [[ -d "./public" ]]; then
    p "Removing old public folder content"
    rm -r ./public/*
fi

p "Regen public"

hugo -t terminal 
cd public
git add .
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
p "Deploying updates to GitHub"
git commit -m "$msg"
git push origin master
