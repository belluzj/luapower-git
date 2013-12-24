# check that the templates have the same exclude lists as the git repos, and if not, update them.

for repo in $(cd git-repos; ls -1); do
	diff git-repos/$repo/.git/info/exclude git-templates/$repo/info/exclude || {
		cat git-repos/$repo/.git/info/exclude > git-templates/$repo/info/exclude
		#cat git-templates/$repo/info/exclude > git-repos/$repo/.git/info/exclude
	}
done
