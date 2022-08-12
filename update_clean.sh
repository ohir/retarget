#!/bin/sh
fro=$1
fro=${fro:-trunk}
umsg="update from $fro"
if [ "`git branch --show-current`" == "main" -a -f .git/info/attributes ] ; then
	echo "--- coming changes: ---"
	git status
	for f in .vscode/* retarget.flags update_clean.sh pubspec.lock notes.txt retarget.flags; do 
		git reset HEAD $f
	done
	echo "--- cleaned-up changes: ---"
	git status
	echo "--- next step: inspect, remove unwanted changes via git reset HEAD file, then"
	echo "               git commit -m '$umsg' -a"
else
	echo "this script is useful only for the 'main' branch (configured)"
fi

