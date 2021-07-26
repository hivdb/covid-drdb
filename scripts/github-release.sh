#! /bin/bash

set -e
export TZ=America/Los_Angeles

PRE_RELEASE=

while (($#)); do
  if [[ "$1" == "--pre-release" ]]; then
    PRE_RELEASE=$1
  fi
  shift
done

if [[ "$PRE_RELEASE" == "--pre-release" ]]; then
  VERSION=$(date +"%Y%m%d-%H%M%S")
  TODAY=$(date +"%Y-%m-%d %H:%M:%S %Z")
else
  VERSION=$(date +"%Y%m%d")
  TODAY=$(date +"%Y-%m-%d")
fi

GIT="git -C payload/"
export GITHUB_USER=hivdb
export GITHUB_REPO=covid-drdb-payload

info=$(github-release info --json)
known_tag=$(echo "$info" | jq -r ".Releases | map(select(.tag_name == \"$VERSION\")) | .[0].tag_name")
if [[ "$known_tag" == "$VERSION" ]]; then
  echo "Release abort: today's version $VERSION is already released." 1>&2
  if [[ "$PRE_RELEASE" != "--pre-release" ]]; then
    echo "You may want to 'make pre-release' for deploy a testing version." 1>&2
  fi
  exit 3
fi

if [[ "$PRE_RELEASE" == "--pre-release" ]]; then
  title="Pre-release $VERSION"
  description="Pre-release date: $TODAY"
else
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
  
  prev_tag=$(echo "$info" | jq -r '.Releases | map(select(.prerelease == false)) | .[0].tag_name')
  prev_commit=$(echo "$info" | jq -r ".Tags | map(select(.name == \"$prev_tag\")) | .[0].commit.sha")

  title="COVID-DRDB $VERSION"
  description="Release date: $TODAY"
  
  if [[ "$prev_commit" != "null" ]]; then
    description="Release date $TODAY\n\nChanges since previous release ($prev_tag):\n
$($GIT log --pretty=format:'- %s (%H, by %an)\n' --abbrev-commit $prev_commit..$local_commit)"
  fi
fi

scripts/export-sqlite.sh $VERSION

if [ ! -f "build/covid-drdb-$VERSION.db" ]; then
  echo "Release abort: file 'build/covid-drdb-$VERSION.db' is not found. Something wrong, please contact Philip." 1>&2
  exit 2
fi

if [ ! -f "build/covid-drdb-$VERSION-slim.db" ]; then
  echo "Release abort: file 'build/covid-drdb-$VERSION-slim.db' is not found. Something wrong, please contact Philip." 1>&2
  exit 2
fi

echo -e $description | github-release release --tag $VERSION --name "$title" $PRE_RELEASE --description -
github-release upload --tag $VERSION --name "covid-drdb-$VERSION.db" --file "build/covid-drdb-$VERSION.db"
github-release upload --tag $VERSION --name "covid-drdb-$VERSION-slim.db" --file "build/covid-drdb-$VERSION-slim.db"

if [[ "PRE_RELEASE" == "--pre-release" ]]; then
  echo "Pre-release $VERSION created: https://github.com/hivdb/covid-drdb-payload/releases/tag/$VERSION"
else
  echo "Release $VERSION created: https://github.com/hivdb/covid-drdb-payload/releases/tag/$VERSION"
fi

scripts/sync-to-s3.sh
