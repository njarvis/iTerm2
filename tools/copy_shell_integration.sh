#!/bin/bash

function die {
  echo $1
  exit
}

branch() {
  local output=$(git symbolic-ref -q --short HEAD)
    if [ $? -eq 0 ]; then
        echo "${output}"
    fi
}

set -x

SUBMODULE=$PWD/submodules/iTerm2-shell-integration
test -d $SUBMODULE || die No $SUBMODULE directory
pushd $SUBMODULE
if [ $(branch) != main ]; then
  echo "Not on main. The current branch is $(branch)."
fi
popd

(cd submodules/iTerm2-shell-integration/ && make)
cp $SUBMODULE/shell_integration/bash Resources/shell_integration/iterm2_shell_integration.bash
cp $SUBMODULE/shell_integration/fish Resources/shell_integration/iterm2_shell_integration.fish
cp $SUBMODULE/shell_integration/tcsh Resources/shell_integration/iterm2_shell_integration.tcsh
cp $SUBMODULE/shell_integration/zsh  Resources/shell_integration/iterm2_shell_integration.zsh
DEST=$PWD/Resources/utilities

pushd $SUBMODULE/utilities
files=$(find . -type f)
tar cvfz $DEST/utilities.tgz *
echo * > $DEST/utilities-manifest.txt
popd

HEADER="sources/iTermLatestVersionByShell.h"
echo "// DO NOT MODIFY - Generated by tools/copy_shell_integration.sh" > $HEADER
echo "latestVersionByShell = @{" >> $HEADER
grep ShellIntegrationVersion= Resources/shell_integration/iterm2_shell_integration.* | sed -n 's/^.*ShellIntegrationVersion=\([^;]*\).*shell=\([a-z]*\).*$/    @"\2": @\1,/p' >> $HEADER
echo "};" >> $HEADER

