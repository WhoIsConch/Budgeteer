@echo OFF
echo Running dart format and dart fix...

REM Format all .dart files in the lib directory
dart format lib/

REM Apply fixes to all .dart files in the lib directory. [2, 3]
dart fix --apply lib/

REM Add any changed files back to the staging area
git add lib/

echo Pre-commit checks finished.
exit 0
