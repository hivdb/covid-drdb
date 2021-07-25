#! /bin/bash

set -e

GIT="git -C payload/"
VERSION=$(date +"%Y%m%d")
TODAY=$(date +"%Y-%m-%d")
export GITHUB_USER=hivdb
export GITHUB_REPO=covid-drdb-payload

remote_commit=$($GIT rev-parse HEAD --branches=origin/master)
local_commit=$($GIT rev-parse HEAD)
if [[ "$remote_commit" != "$local_commit" ]]; then
  echo "Release abort: the local repository payload/ seems not up-to-date. Forgot running 'git pull --rebase' and 'git push'?" 1>&2
  exit 1
fi

if [ -n "$($GIT status -s .)" ]; then
  $GIT status
  echo "Release abort: uncommitted changes are found under payload/ directory. Please submit them & run 'git push' first." 1>&2
  exit 1
fi

if [ ! -f "build/covid-drdb-$VERSION.db" ]; then
  echo "Release abort: file 'build/covid-drdb-$VERSION.db' is not found. Forgot running 'make export-sqlite'?" 1>&2
  exit 2
fi

if [ ! -f "build/covid-drdb-$VERSION-slim.db" ]; then
  echo "Release abort: file 'build/covid-drdb-$VERSION-slim.db' is not found. Forgot running 'make export-sqlite'?" 1>&2
  exit 2
fi

info=$(github-release info --json)
prev_tag=$(echo $info | jq -r .Releases[0].tag_name)
if [[ "$prev_tag" == "$VERSION" ]]; then
  echo "Release abort: current version $VERSION is already release." 1>&2
  exit 3
fi

for i in $(seq 0 10); do
  test_tag=$(echo $info | jq -r .Tags[$i].name)
  if [[ "$test_tag" == "null" ]]; then
      continue
  fi
  if [[ "$test_tag" != "$prev_tag" ]]; then
      continue
  fi
  prev_commit=$(echo $info | jq -r .Tags[$i].commit.sha)
done

description="Release date: $TODAY"

if [ -n "$prev_commit" ]; then
  description="Release date $TODAY\n\nChanges since previous release:\n
$($GIT log --pretty=format:'- %s (%H, by %an)\n' --abbrev-commit $prev_commit..$local_commit)"
fi

echo -e $description | github-release release --tag $VERSION --name "COVID-DRDB $VERSION" --description -
github-release upload --tag $VERSION --name "covid-drdb-$VERSION.db" --file "build/covid-drdb-$VERSION.db"
github-release upload --tag $VERSION --name "covid-drdb-$VERSION-slim.db" --file "build/covid-drdb-$VERSION-slim.db"

echo "Release $VERSION created: https://github.com/hivdb/covid-drdb-payload/releases/tag/$VERSION"
