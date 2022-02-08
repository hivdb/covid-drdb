#! /bin/sh

set -e

USAGE="Usage: $0 <SIERRA_MUTLIST_DIR> <OUTPUT_CSV>"

sierra_mutlist="$1"
output="$2"

if [ ! -d "$sierra_mutlist" ]; then
  echo "<SIERRA_MUTLIST_DIR> is not specified or not a directory" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

if [ -z "$output" ]; then
  echo "<OUTPUT_CSV> is not specified" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

if [ -e "$output" ]; then
  echo "<OUTPUT_CSV> $output already exists, refuse to overwrite" 1>&2
  echo $USAGE 1>&2
  exit 1
fi

# $output should be a file
touch $output

output_filename=$(basename $output)

docker run --rm -it \
	--volume=$(pwd):/covid-drdb/ \
	--volume=$(realpath $sierra_mutlist):/sierra-mutlist \
	--volume=$(realpath $output):/output/$output_filename \
 		hivdb/covid-drdb-builder:latest \
	pipenv run python -m drdb.entry extract-sierra-mutations /sierra-mutlist /output/$output_filename
