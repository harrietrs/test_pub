#!/bin/sh

set -e
set -x

if [ -z "$INPUT_SOURCE_FOLDER" ]
then
  echo "Source folder must be defined"
  return -1
fi

if [ $INPUT_DESTINATION_HEAD_BRANCH == "main" ] || [ $INPUT_DESTINATION_HEAD_BRANCH == "master"]
then
  echo "Destination head branch cannot be 'main' nor 'master'"
  return -1
fi

if [ -z "$INPUT_PULL_REQUEST_REVIEWERS" ]
then
  PULL_REQUEST_REVIEWERS=$INPUT_PULL_REQUEST_REVIEWERS
else
  PULL_REQUEST_REVIEWERS='-r '$INPUT_PULL_REQUEST_REVIEWERS
fi

echo "Setting git variables"
CLONE_DIR=$(mktemp -d)
TIME_ID=$(date +%s)
DESTINATION_HEAD_BRANCH=$INPUT_DESTINATION_HEAD_BRANCH$TIME_ID

export GITHUB_TOKEN=$API_TOKEN_GITHUB
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"

echo "Cloning destination git repository"
git clone "https://$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

echo "Copying contents to git repo"
mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER/
cp -a $INPUT_SOURCE_FOLDER "$CLONE_DIR/"
cd "$CLONE_DIR"
git config --global --add safe.directory "$CLONE_DIR"
git checkout -b "$DESTINATION_HEAD_BRANCH"
echo "Adding git commit"
git add .
git rm -rf --cached .github/workflows
git remote -v
if git status | grep -q "Changes to be committed"
then
  git commit --message "Test push to separate repo"
  echo "Pushing git commit"
  git push -u origin HEAD:$DESTINATION_HEAD_BRANCH
  echo "Creating a pull request"
  gh pr create -t $DESTINATION_HEAD_BRANCH \
             -b $DESTINATION_HEAD_BRANCH \
             -B $INPUT_DESTINATION_BASE_BRANCH \
             -H $DESTINATION_HEAD_BRANCH \
                $PULL_REQUEST_REVIEWERS
else
  echo "No changes detected"
fi
