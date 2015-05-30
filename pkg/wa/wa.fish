# SYNOPSIS
#   Wahoo CLI
#
# GLOBALS
#   WAHOO_VERSION   Version
#   WAHOO_CONFIG    Wahoo configuration
#
# OVERVIEW
#   Provides options to list, download and remove packages, update
#   the framework, create / submit a new package, etc.

set -l WAHOO_MISSING_ARG   1
set -l WAHOO_UNKNOWN_OPT   2
set -l WAHOO_INVALID_ARG   3
set -l WAHOO_UNKNOWN_ERR   4

set -g WAHOO_VERSION "0.1.0"
set -g WAHOO_CONFIG  "$HOME/.config/wahoo"

function wa -d "Wahoo"
  function em    ;  set_color cyan    ; end
  function dim   ;  set_color gray    ; end
  function off   ;  set_color normal  ; end
  function err   ;  set_color red     ; end
  function line  ;  set_color -u      ; end
  function bold  ;  set_color -o      ; end

  if test (count $argv) -eq 0
    WAHOO::cli::help
    return 0
  end

  switch $argv[1]
    case "v" "ver" "version"
      WAHOO::cli::version

    case "h" "help"
      WAHOO::cli::help

    case "l" "li" "lis" "lst" "list"
      WAHOO::util::list_installed | column

    case "g" "ge" "get" "install"
      if test (count $argv) -eq 1
        WAHOO::util::list_available | column
      else
        WAHOO::cli::get $argv[2..-1]
      end

    case "u" "use"
      if test (count $argv) -eq 1
        set -l theme (cat $WAHOO_CONFIG/theme)
        set -l regex "[[:<:]]($theme)[[:>:]]"
        test (uname) != "Darwin"; and set regex "\b($theme)\b"

        WAHOO::util::list_themes \
        | column | sed -E "s/$regex/"(line)(bold)(em)"\1"(off)"/"
        set_color normal

      else if test (count $argv) -eq 2
        WAHOO::cli::use $argv[2]
      else
        echo (bold)(line)(err)"Invalid number of arguments"(off) 1^&2
        echo "Usage: $_ "(em)"$argv[1]"(off)" [<theme name>]" 1^&2
        return $WAHOO_INVALID_ARG
      end

    case "r" "rm" "remove" "uninstall"
      if test (count $argv) -ne 2
        echo (bold)(line)(err)"Invalid number of arguments"(off) 1^&2
        echo "Usage: $_ "(em)"$argv[1]"(off)" <[package|theme] name>" 1^&2
        return $WAHOO_INVALID_ARG
      end
      WAHOO::cli::remove $argv[2..-1]

    case "p" "up" "upd" "update"
      pushd $WAHOO_PATH
      echo (bold)"Updating Wahoo..."(off)
      if WAHOO::cli::update
        echo (em)"Wahoo is up to date."(off)
      else
        echo (line)"Wahoo failed to update."(off)
        echo "Please open a new issue here → "(line)"git.io/wahoo-issues"(off)
      end
      popd
      reload

    case "s" "su" "sub" "submit"
      if test (count $argv) -ne 2
        echo (bold)(line)(err)"Argument missing"(off) 1^&2
        echo "Usage: $_ "(em)"$argv[1]"(off)" <package/theme name>" 1^&2
        return $WAHOO_MISSING_ARG
      end
      WAHOO::cli::submit $argv[2]

    case "n" "nw" "new"
      if test (count $argv) -ne 3
        echo (bold)(line)(err)"Argument missing"(off) 1^&2
        echo "Usage: $_ "(em)"$argv[1]"(off)" "\
          (bold)"pkg|theme"(off)" <name>" 1^&2
        return $WAHOO_MISSING_ARG
      end
      WAHOO::cli::new $argv[2..-1]

    case "destroy"
      WAHOO::cli::destroy; and reload # So long!

    case "*"
      echo (bold)(line)(err)"$argv[1] option not recognized"(off) 1^&2
      return $WAHOO_UNKNOWN_OPT
  end
end

function WAHOO::cli::version
  echo "Wahoo $WAHOO_VERSION"
end

function WAHOO::cli::help
  echo \n"\
  "(bold)"Usage"(off)"
    wa "(line)(dim)"action"(off)" [package]

  "(bold)"Actions"(off)"
       "(bold)(line)(dim)"l"(off)"ist  List local packages.
        "(bold)(line)(dim)"g"(off)"et  Install one or more packages.
        "(bold)(line)(dim)"u"(off)"se  List / Apply themes.
     "(bold)(line)(dim)"r"(off)"emove  Remove a theme or package.
     u"(bold)(line)(dim)"p"(off)"date  Update Wahoo.
        "(bold)(line)(dim)"n"(off)"ew  Create a new package from a template.
     "(bold)(line)(dim)"s"(off)"ubmit  Submit a package to the registry.
       "(bold)(line)(dim)"h"(off)"elp  Display this help.
    "(bold)(line)(dim)"v"(off)"ersion  Display version.
    "(dim)(bold)(line)"destroy"(off)"  Display version.

  For more information visit → "(bold)(line)"git.io/wahoo-doc"(off)\n
end

function WAHOO::cli::use
  if not test -e $WAHOO_CUSTOM/themes/$argv[1]
    if not test -e $WAHOO_PATH/themes/$argv[1]
      set -l theme $WAHOO_PATH/db/$argv[1].theme
      if test -e $theme
        echo (bold)"Downloading $theme..."(off)
        git clone (cat $theme) \
          $WAHOO_PATH/themes/$argv[1] >/dev/null ^&1
          and echo (em)"$theme theme downloaded."(off)
          or return $WAHOO_UNKNOWN_ERR
      else
        echo (bold)(line)(err)"$argv[1] is not a valid theme"(off) 1^&2
        return $WAHOO_INVALID_ARG
      end
    end
  end
  WAHOO::util::apply_theme $argv[1]
end


function WAHOO::cli::update
  set -l repo "upstream"
  test -z (git config --get remote.upstream.url)
    and set -l repo "origin"

  if WAHOO::git::repo_is_clean
    git pull $repo master >/dev/null ^&1
  else
    git stash >/dev/null ^&1
    if git pull --rebase $repo master >/dev/null ^&1
      git stash apply >/dev/null ^&1
    else
      WAHOO::util::sync_head # Like a boss
    end
  end
end

function WAHOO::cli::get
  for search in $argv
    if test -e $WAHOO_PATH/db/$search.theme
      set target themes/$search
    else if test -e $WAHOO_PATH/db/$search.pkg
      set target pkg/$search
    else
      echo (bold)(line)(err)"$search is not a valid package/theme"(off) 1^&2
      continue
    end
    if test -e $WAHOO_PATH/$target
      echo (bold)"Updating $search..."(off)
      pushd $WAHOO_PATH/$target
      WAHOO::util::sync_head >/dev/null ^&1
      popd
      echo (em)"$search up to date."(off)
    else
      echo (bold)"Installing $search..."(off)
      git clone (cat $WAHOO_PATH/db/$search.*) \
        $WAHOO_PATH/$target >/dev/null ^&1
        and echo (em)"$search succesfully installed."(off)
    end
  end
  reload
end

function WAHOO::cli::remove
  for pkg in $argv
    if not WAHOO::util::validate_package $pkg
      if test $pkg = "wa"
        echo (bold)(line)(err)"You can't remove wa!"(off) 1^&2
      else
        echo (bold)(line)(err)"$pkg is not a valid package/theme name"(off) 1^&2
      end
      return $WAHOO_INVALID_ARG
    end

    if test -d $WAHOO_PATH/pkg/$pkg
      emit uninstall_$pkg
      rm -rf $WAHOO_PATH/pkg/$pkg
    else if test -d $WAHOO_PATH/themes/$pkg
      rm -rf $WAHOO_PATH/themes/$pkg
    end

    if test $status -eq 0
      echo (em)"$pkg succesfully removed."(off)
    else
      echo (bold)(line)(err)"$pkg could not be found"(off) 1^&2
    end
  end
  reload
end

function WAHOO::cli::submit
  set -l name $argv[1]
  set -l ext ""
  switch $name
    case \*.pkg
      set ext .pkg
    case \*.theme
      case ext .theme
    case "*"
      echo (bold)(line)(err)"Missing extension .pkg or .theme"(off) 1^&2
      return $WAHOO_INVALID_ARG
  end
  set name (basename $name $ext)

  set -l url (git config --get remote.origin.url)
  if test -z "$url"
    echo (bold)(line)(err)"$name remote URL not found"(off) 1^&2
    echo "Try: git remote add <URL> or see Docs > Submitting" 1^&2
    return $WAHOO_INVALID_ARG
  end

  switch "$url"
    case \*bucaran/wahoo\*
      echo (bold)(line)(err)"$url is not a valid package directory"(off) 1^&2
      return $WAHOO_INVALID_ARG
  end

  set -l user (git config github.user)
  if test -z "$user"
    echo (bold)(line)(err)"GitHub user configuration not available"(off) 1^&2
    echo "Try: git config github.user "(line)"username"(off) 1^&2
    return $WAHOO_INVALID_ARG
  end

  if not WAHOO::util::validate_package $name
    echo (bold)(line)(err)"$pkg is not a valid package/theme name"(off) 1^&2
    return $WAHOO_INVALID_ARG
  end

  if test -e $WAHOO_PATH/db/$name$ext
    echo (bold)(line)(err)"$name already exists in the registry"(off) 1^&2
    echo "See: "(line)(cat $WAHOO_PATH/db/$name$ext)(off)" for more info." 1^&2
    return $WAHOO_INVALID_ARG
  end

  pushd $WAHOO_PATH

  if not git remote show remote >/dev/null ^&1
    WAHOO::util::fork_github_repo "$user" "bucaran/wahoo"
    git remote rm origin >/dev/null ^&1
    git remote add origin   "https://github.com"/$user/wahoo    >/dev/null ^&1
    git remote add upstream "https://github.com"/bucaran/wahoo  >/dev/null ^&1
  end

  git checkout -b add-$name

  echo "$url" > $WAHOO_PATH/db/$name$ext
  echo (em)"$name added to the registry."(off)

  git add -A >/dev/null ^&1
  git commit -m "Adding $name to registry." >/dev/null ^&1
  git pull --rebase upstream >/dev/null ^&1
  git push origin add-$name

  popd
  open "https://github.com"/$user/wahoo
end

function WAHOO::cli::new -a option name
  switch $option
    case "p" "pkg" "pack" "packg" "package"
      set pkg "pkg"
    case "t" "th" "thm" "theme"
      set pkg "themes"
    case "*"
      echo (bold)(line)(err)"$option is not a valid option."(off) 1^&2
      return $WAHOO_INVALID_ARG
  end

  if not WAHOO::util::validate_package "$name"
    echo (bold)(line)(err)"$name is not a valid package/theme name"(off) 1^&2
    return $WAHOO_INVALID_ARG
  end

  if set -l dir (WAHOO::util::mkdir "$pkg/$name")
    cd $dir
    if test $pkg = "pkg"
      echo "function $name"\n"end"\n > "$dir/$name.fish"
    else
      cp "$WAHOO_PATH/themes/default/fish_prompt.fish" "$dir/fish_prompt.fish"
    end
    echo "# $name"\n > "$dir/README.md"
    echo (em)"Directory changed to "(line)"$dir"(off)
  else
    WAHOO::util::die $WAHOO_UNKNOWN_ERR \
      (bold)(line)(err)"\$WAHOO_CUSTOM and \$WAHOO_PATH undefined."(off)
  end
end

function WAHOO::util::validate_package
  set -l pkg $argv[1]
  for default in wahoo wa
    if test (echo "$pkg" | tr "[:upper:]" "[:lower:]") = $default
      return 1
    end
  end
  switch $pkg
    case {a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}\*
      switch $pkg
        case "*/*" "* *" "*&*" "*\"*" "*!*" "*&*" "*%*" "*#*"
          return 1
      end
    case "*"
      return 1
  end
end

function WAHOO::cli::destroy -d "Remove Wahoo"
  echo (bold)(set_color 555)"Removing Wahoo..."(off)
  for pkg in $WAHOO_PATH/pkg/*
    test $pkg != "wa"; and echo WAHOO::cli::remove (basename $pkg)
  end

  if test -e "$HOME/.config/fish/config.copy"
    mv "$HOME/.config/fish/config".{copy,fish}
  end

  if test (basename "$WAHOO_CONFIG") = "wahoo"
    rm -rf "$WAHOO_CONFIG"
  end

  if test "$WAHOO_PATH" != "$HOME"
    rm -rf "$WAHOO_PATH"
  end
end

function WAHOO::util::list_installed
  for item in (basename {$WAHOO_PATH,$WAHOO_CUSTOM}/pkg/*)
    if not test $item = wa
      echo $item
    end
  end
end
function WAHOO::util::list_available
  for item in (basename -s .pkg $WAHOO_PATH/db/*.pkg)
    if not contains $item (basename {$WAHOO_PATH,$WAHOO_CUSTOM}/pkg/*)
      echo $item
    end
  end
end

function WAHOO::util::fork_github_repo
  set -l user $argv[1]
  set -l repo $argv[2]

  curl -u "$user" --fail --silent \
    https://api.github.com/repos/$repo/forks \
    -d "{\"user\":\"$user\"}" >/dev/null
end

function WAHOO::util::sync_head
  set -l repo "origin"
  set -q argv[1]; and set repo $argv[1]

  git fetch origin master
  git reset --hard FETCH_HEAD
  git clean -df
end

function WAHOO::util::db
  for db in $WAHOO_PATH/db/*.$argv[1]
    basename $db .$argv[1]
  end
end

function WAHOO::util::list_themes
  set -l seen ""
  for theme in (basename $WAHOO_PATH/themes/* $WAHOO_CUSTOM/themes/*) \
  (WAHOO::util::db theme)
    contains $theme $seen; or echo $theme
    set seen $seen $theme
  end
end

function WAHOO::util::apply_theme
  echo $argv[1] > $WAHOO_CONFIG/theme
  reload
end

function WAHOO::util::mkdir -a name
  set -l name "$argv[1]"
  if test -d "$WAHOO_CUSTOM"
    set name "$WAHOO_CUSTOM/$name"
  else if test -d "$WAHOO_PATH"
    set name "$WAHOO_PATH/$name"
  end
  mkdir -p "$name"
  echo $name
end

function WAHOO::util::die -a error msg
  echo $msg 1^&2
  exit $error
end

function WAHOO::git::repo_is_clean
  git diff-index --quiet HEAD --
end
