#!/usr/bin/env zsh

for dir in */ ; do
    git checkout -- "$dir"
    git clean -fd "$dir"
done