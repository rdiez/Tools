
--- Git Helper Scripts ---


clean-git-repo.sh

Reverts the working directory to a pristine state, like after doing
the first "git clone" (which is rather destructive).


git-revert-file-permissions.sh

Git stores the 'execute' file permission in the repository, but permissions get sometimes lost
when copying files around to/from Windows PCs or FAT/FAT32 disk partitions.
This script restores all file permissions to their original values in the Git repository.


git-stash-index.sh  and  git-stash-no-index.sh

git-stash-index.sh stashes only the changes in the stage/index. It is
useful if you are in the middle of a big commit, and you just realised that
you want to make a small, unrelated commit before the big one.

git-stash-no-index.sh stashes only the changes in the working files
that are not in the stage/index. Useful to test that your next commit compiles cleanly,
or just to temporarily unclutter your workspace.


pull.sh

Use instead of "git pull" in order to prevent creating unnecessary merge commits
without having to remember git commands or options.
