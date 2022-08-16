#!/bin/sh
fro=$1
fro=${fro:-trunk}
umsg="update from $fro"
if [ "`git branch --show-current`" == "main" -a -f .git/info/attributes ] ; then
	echo "--- begin manual merge from $fro"
	git merge -m "$umsg" --no-ff --no-commit $fro
	git status -sb --porcelain
	echo "--- next step: inspect above list and make git reset HEAD\n    or git add/rm to keep main branch clean"
else
	echo "this script is useful only for the 'main' branch (configured)"
fi

