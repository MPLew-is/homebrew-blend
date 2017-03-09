#!/bin/sh
#
#Updates the homebrew formula file for this project when called
#
#Example usage:
#	./scripts/deploy.sh

#Exit immediately if any of the commands in this script fail
set -e


projectHost="github.com"
projectUser="MPLew-is"
projectRepository="homebrew-blend"

tapHost="${projectHost}"
tapUser="${projectUser}"
tapRepository="homebrew-experimental"
tapFormula="brew-blend"


#Get current tagged release
tag="$(git describe --tags)"


#Change into the home directory
cd ../


#Download the tagged release's archive
repositoryPrefix="https://${projectHost}/${projectUser}/${projectRepository}/archive"
archiveURL="${repositoryPrefix}/${tag}.tar.gz"
wget --output-document="archive.tar.gz" "${archiveURL}"

#Get the archive's hash
tagHash="$(shasum --portable --algorithm 256 "archive.tar.gz" | awk '{print $1}')"

#Remove the archive
rm "archive.tar.gz"


#If the tap has been cached, update it from its remote
if [ -d "brew-tap" ]
then
	cd "brew-tap/Formula"
	
	git fetch
	git pull

#If not, clone it and change directories into it
else
	git clone "git@${tapHost}:${tapUser}/${tapRepository}.git" "brew-tap"
	
	cd "brew-tap/Formula"
fi


#Replace the old archive URL with the new archive URL
sed -i'' -e "s#url \"${repositoryPrefix}/[^/]*.tar.gz\"\$#url \"${archiveURL}\"#g" "${tapFormula}.rb"

#Repalce the old hash with the new hash
sed -i'' -e "s/sha256 \"[a-f0-9]*\"\$/sha256 \"${tagHash}\"/g" "${tapFormula}.rb"

#Commit and push the auto-deployment
git commit --all --message="Upgrade 'brew-blend' to '${tag}' (CircleCI auto-deploy)"
git push


exit 0
