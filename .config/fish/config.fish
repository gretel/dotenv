# osx-specific fish shell configuration https://gist.github.com/gretel/0bb5f77cdc54182c15dd
# $ brew update; brew install chruby chruby-fish direnv hub fasd fzf keychain pyenv thefuck

# my personal ssh keys on the chain
set ssh_keys $HOME/.ssh/svaha $HOME/.ssh/github $HOME/.ssh/stash

# https://github.com/yyuu/pyenv-virtualenv
set -x PYENV_SHELL fish
set -x PYENV_HOME $HOME/.pyenv

. (pyenv init - | psub)
. (pyenv virtualenv-init - | psub)

# chruby handles ruby
. /usr/local/share/chruby/chruby.fish
. /usr/local/share/chruby/auto.fish

# direnv last so chruby and pyenv will have stuff set
eval (direnv hook fish)

# automation does need no userland fooshizzle
if status --is-interactive

  # fzf for history fuzzines
  . /usr/local/Cellar/fzf/**/shell/key-bindings.fish

  # hub for 'git'
  eval (hub alias -s)

  # keychain for 'ssh' and 'gnupg'
  keychain --eval --quiet --quiet $ssh_keys >/dev/null
  . $HOME/.keychain/(hostname)-fish

  # thefuck for the mess we type
  eval (thefuck --alias | tr '\n' ';')

  # fasd autojumping to directories
  function -e fish_preexec _run_fasd
    fasd --proc (fasd --sanitize "$argv") > "/dev/null" 2>&1
  end

  function j
    cd (fasd -d -e 'printf %s' "$argv")
  end

  function fish_user_key_bindings
    # fzf
    fzf_key_bindings
    bind \ct -M insert '__fzf_ctrl_t'
    bind \cr -M insert '__fzf_ctrl_r'
    bind \ec -M insert '__fzf_alt_c'

    # TOOO add fasd bindings
  end

end
