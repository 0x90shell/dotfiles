#! /bin/bash
vimins="pacman -Sy --needed git base-devel vim-ale vim-nerdtree"
echo "running $vimins w/ sudo"
sleep 1
sudo -E bash -c "$vimins"
