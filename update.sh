#!/bin/sh
fro=$1
fro=${fro:-trunk}
umsg="update from $fro"
if [ "`git branch --show-current`" == "main" -a -f .git/info/attributes ] ; then
	echo "--- begin manual merge from $fro"
	git merge -m "$umsg" --no-ff --no-commit $fro
	echo "--- next step: ./update_clean.sh"
else
	echo "this script is useful only for the 'main' branch (configured)"
fi

