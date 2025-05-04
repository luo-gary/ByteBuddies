## Cheat Sheet
* https://training.github.com/downloads/github-git-cheat-sheet.pdf
* https://education.github.com/git-cheat-sheet-education.pdf

## Config
* Run `git config --list` to list the curret config settings
* Run `git config push.autoSetupRemote true` to set up remote upstream branchese automatically

## Branch
`git branch`
* list your branches. a * will appear next to the currently active branch

`git checkout <branch>`
* switch to another branch and check it out into your working directory

`git checkout -b <branch>`
* create a new branch based on the current branch
* Always run the below commands together to create a new branch based on a fresh master branch
```
git checkout master
git pull
git checkout -b <user>-<branch>
```

## Pull Request
* Edit your files
* Run `git status` to check which files have been changed
* Run `git diff` to check diff of what is changed but not staged
* Run `git add <directory or file>` to add them as they look now to your next commit (stage)
   * Optionally: run `git diff --staged` to show diff of what is staged but not yet commited
* Run `git commit -m '[descriptive message]'` to commit your staged content as a new commit snapshot
   * Optionally: run `git diff master` to show diff against the master branch
* Run `git push` to uploads all local branch commits to GitHub
* Open https://github.com/luo-gary/kidhustle/pull/new/<branch> to create a pull request
   * Or find your branch at https://github.com/luo-gary/kidhustle/branches to create a pull request
   * Ask a peer to review your pull request
   * Merge your pull request to the main branch

## Track Code Change History
* Find the directory or file in your repository on github.com
* Click the `History` button to check its change history
* Click the `blame` button to find out which line of code was changed by who at when

## Tempory Commits
Temporarily store modified, tracked files in order to change branches
`git stash`
* Save modified and staged changes
`git stash list`
* list stack-order of stashed file changes
`git stash pop`
* write working from top of stash stack
`git stash drop`
discard the changes from top of stash stack
