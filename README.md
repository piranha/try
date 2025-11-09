# try - fresh dirs on a whim

I saw tobi's [try](https://github.com/tobi/try) the other day and was impressed
by an idea: you often do one-off stuff that is not surely will end up permanent
enough, so why not automate creation and search?

But his try.rb implemented interface from scratch in Ruby. And I love fzf that I
decided to rewrite the logic in shell (yeah I know brilliant right? /s). So here we go.

## Installation

Get the script, put it *anywhere*, `chmod +x` it, and `./try` it. It'll tell you
how to make it permanent.

NOTE: there is no good way around that pesky `eval` since shell scripts are
executed in subshells and so cannot change directory of your login
shell. ¯\\_(ツ)_/¯

## Features

- Selection using `fzf` - so fuzzy matching etc
- Access time aware sorting
- worktrees: run `try . [new-name]` or `try worktree [new-name]` and it'll create a new worktree for this repo
