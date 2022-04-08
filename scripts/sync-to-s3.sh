#! /bin/bash

set -e

S3_BUCKET=s3://cms.hivdb.org
S3_PREFIX=covid-drdb
RELEASE_INFO=$(github-release info -u hivdb -r covid-drdb-payload --json)

known_assets=
num_releases=$(echo "$RELEASE_INFO" | jq -r '.Releases | length')

s3_files=$(aws s3 ls ${S3_BUCKET}/${S3_PREFIX}/ | awk '{print $4}')

find_and_pop_s3_file() {
  tmp=
  ret=1
  while read file; do
    if [[ "$file" == "$1" ]]; then
      ret=0
    else
      tmp=$(echo -e "$tmp\n$file")
    fi
  done < <(echo "$s3_files")
  s3_files="$tmp"
  return $ret
}

rm -rf /github-assets 2>/dev/null || true
mkdir /github-assets
pushd /github-assets >/dev/null

for i in $(seq 0 $((num_releases - 1))); do
  num_assets=$(echo "$RELEASE_INFO" | jq -r ".Releases[$i].assets | length")
  for j in $(seq 0 $((num_assets - 1))); do
    name=$(echo "$RELEASE_INFO" | jq -r ".Releases[$i].assets[$j].name")
    url=$(echo "$RELEASE_INFO" | jq -r ".Releases[$i].assets[$j].url")
    if ! find_and_pop_s3_file "$name"; then
      echo "download: $name"
      # remote file doesn't exist
      real_url=$(curl -sSL -H "Authorization: $GITHUB_TOKEN" $url | jq -r ".browser_download_url")
      curl -sSL -H "Authorization: $GITHUB_TOKEN" $real_url -o $name
      echo "compress: $name"
      pigz -9 $name
      mv $name.gz $name
      aws s3 sync /github-assets/ "${S3_BUCKET}/${S3_PREFIX}/" \
        --content-encoding gzip --cache-control max-age=2592000
    fi
  done
done

popd >/dev/null

# echo "$s3_files" | while read file; do
#   if [[ $file != "" ]]; then
#     aws s3 rm ${S3_BUCKET}/${S3_PREFIX}/${file}
#   fi
# done
