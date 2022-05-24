#! /bin/bash

set -e

PARALLELS=$(($(nproc --all) * 4))

AGG_OPTIONS=(
  rx_type
  article
  infected_variant
  vaccine
  antibody
  antibody:any
  antibody:indiv
  variant
  isolate_agg
  isolate
  position
  vaccine_dosage
  potency_type
  potency_unit
)

VERSION=$1
cd /dev/shm
curl -SLO https://github.com/hivdb/covid-drdb-payload/releases/download/$VERSION/covid-drdb-$VERSION.db
DBFILE=/dev/shm/covid-drdb-$VERSION.db

trap "rm -f $DBFILE" EXIT

TARGET_DIR=$2
SHM_TARGET_DIR=/dev/shm/covid-drdb-cache
rm -rf $SHM_TARGET_DIR 2>/dev/null || true
trap "rm -rf $SHM_TARGET_DIR" EXIT

_escape() {
  echo $1 | sed "s/'/''/g"
}

_eq() {
  echo "($1 = '$(_escape "$2")')"
}

_notnull() {
  echo "($1 IS NOT NULL)"
}

_join() {
  local separator="$1"
  shift
  local first="$1"
  shift
  printf "%s" "$first" "${@/#/$separator}"
}

_split() {
  local separator="$1"
  local arr=()
  shift
  IFS="$separator" read -r -a arr <<EOF
$1
EOF
  echo "${arr[@]}"
}

_camel() {
  echo "$1" | gsed -r 's/_(\w)/\U\1/g'
}

_where() {
  _join ' and ' "$@"
}

_groupby() {
  local ordered=()
  for option_a in "${AGG_OPTIONS[@]}"; do
    for option_b in "$@"; do
      if [[ "$option_a" == "$option_b" ]]; then
        ordered+=("$option_a")
      fi
    done
  done
  _join ',' "${ordered[@]}"
}

_orderby() {
  local columns=()
  for col in "$@"; do
    case $col in
      antibody_names)
        columns+=('CAST(antibody_order AS INTEGER)')
        ;;
      vaccine_name)
        columns+=('CAST(vaccine_order AS INTEGER)')
        ;;
      *)
        columns+=($col)
    esac
  done
  _join ', ' "${columns[@]}"
}

_execute() {
  local subqueries=()
  local idx=0
  while [ -n "$1" ]; do
    local keycol="$1"
    local valcol="$2"
    local conds="$3"
    local aggkey="$4"
    local ordercols="$5"
    shift 5

    if [ -z "$conds" ]; then
      conds="TRUE"
    fi

    aggcond="aggregate_by = '$aggkey'"
    if [ -z "$aggkey" ]; then
      aggcond="aggregate_by IS NULL"
    fi

    if [ -n "ordercols" ]; then
      orderby="ORDER BY $ordercols"
    fi

    subqueries+=("
    SELECT key, val FROM (
      SELECT $keycol AS key, $valcol AS val FROM susc_summary
      WHERE $aggcond AND $conds $orderby
    ) AS subquery${idx}")
    let idx=idx+1
  done

  local sql="
    SELECT json_group_array(json_object(key, val))
    FROM ($(_join ' UNION ' "${subqueries[@]}")) AS subqueries
  "

  # TODO: find a better way for error handling
  # The current way competes the resource of /dev/shm/error between
  # processes.
  sqlite3 "$DBFILE" "$sql" # 2>/dev/shm/error

  # if [ -s /dev/shm/error ]; then
  #   echo $error 1>&2
  #   echo -e $sql 1>&2
  #   exit 1
  # fi
}

_getval() {
  local getkey=$1
  shift
  for option in "$@"; do
    local key=${option%%:*}
    local val=${option#*:}
    if [[ "$getkey" == "$key" ]]; then
      echo "$val"
      break
    fi
  done
}


_append_eq() {
  colname=$1
  value=$2

  local rx_type

  if [ -z "$value" ]; then
    return
  fi

  case $colname in
    ref_name)
      aggregate_by+=('article')
      conds+=("$(_eq ref_name "$value")")
      ;;
    antibody_names)
      if [[ "$value" == 'any' ]]; then
        rx_type='antibody'
      else
        aggregate_by+=('antibody:any')
        conds+=("$(_eq antibody_names "$value")")
      fi
      ;;
    vaccine_name)
      if [[ "$value" == 'any' ]]; then
        rx_type='vacc-plasma'
      else
        aggregate_by+=('vaccine')
        conds+=("$(_eq vaccine_name "$value")")
      fi
      ;;
    infected_var_name)
      if [[ "$value" == 'any' ]]; then
        rx_type='conv-plasma'
      else
        aggregate_by+=('infected_variant')
        conds+=("$(_eq infected_var_name "$value")")
      fi
      ;;
    var_name)
      aggregate_by+=('variant')
      conds+=("$(_eq var_name "$value")")
      ;;
    iso_aggkey)
      aggregate_by+=('isolate_agg')
      conds+=("$(_eq iso_aggkey "$value")")
      ;;
    position)
      aggregate_by+=('position')
      conds+=("$(_eq position "$value")")
      ;;
  esac

  if [ -n "$rx_type" ]; then
    aggregate_by+=('rx_type')
    conds+=("$(_eq rx_type "$rx_type")")
  fi
}


query_article() {
  local ab_names=$(_getval antibody_names "$@")
  local vaccine_name=$(_getval vaccine_name "$@")
  local infected_var_name=$(_getval infected_var_name "$@")
  local var_name=$(_getval var_name "$@")
  local iso_aggkey=$(_getval iso_aggkey "$@")
  local gene_pos=$(_getval position "$@")

  aggregate_by=()
  conds=()

  _append_eq antibody_names "$ab_names"
  _append_eq vaccine_name "$vaccine_name"
  _append_eq infected_var_name "$infected_var_name"
  _append_eq var_name "$var_name"
  _append_eq iso_aggkey "$iso_aggkey"
  _append_eq position "$gene_pos"

  _execute \
    "'any'" num_experiments \
    "$(_where "${conds[@]}")" \
    "$(_groupby "${aggregate_by[@]}")" \
    "$(_orderby num_experiments)" \
    \
    ref_name num_experiments \
    "$(_where "$(_notnull ref_name)" "${conds[@]}")" \
    "$(_groupby article "${aggregate_by[@]}")" \
    "$(_orderby ref_name num_experiments)"
}

query_antibody() {
  local ab_aggregate_by=$(_getval ab_aggregate_by "$@")
  local ref_name=$(_getval ref_name "$@")
  local var_name=$(_getval var_name "$@")
  local iso_aggkey=$(_getval iso_aggkey "$@")
  local gene_pos=$(_getval position "$@")

  aggregate_by=()
  conds=()

  _append_eq ref_name "$ref_name"
  _append_eq var_name "$var_name"
  _append_eq iso_aggkey "$iso_aggkey"
  _append_eq position "$gene_pos"

  _execute \
    "'any'" num_experiments \
    "$(_where "${conds[@]}")" \
    "$(_groupby "${aggregate_by[@]}")" \
    "$(_orderby num_experiments)" \
    \
    "'ab-any'" num_experiments \
    "$(_where "$(_eq rx_type antibody)" "${conds[@]}")" \
    "$(_groupby rx_type "${aggregate_by[@]}")" \
    "$(_orderby num_experiments)" \
    \
    antibody_names num_experiments \
    "$(_where "$(_notnull antibody_names)" "${conds[@]}")" \
    "$(_groupby "$ab_aggregate_by" "${aggregate_by[@]}")" \
    "$(_orderby antibody_names num_experiments)"
}


query_infected_variant() {
  local ref_name=$(_getval ref_name "$@")
  local var_name=$(_getval var_name "$@")
  local iso_aggkey=$(_getval iso_aggkey "$@")
  local gene_pos=$(_getval position "$@")

  aggregate_by=()
  conds=()

  _append_eq ref_name "$ref_name"
  _append_eq var_name "$var_name"
  _append_eq iso_aggkey "$iso_aggkey"
  _append_eq position "$gene_pos"

  _execute \
    "'any'" num_experiments \
    "$(_where "${conds[@]}")" \
    "$(_groupby "${aggregate_by[@]}")" \
    "$(_orderby 'num_experiments')" \
    \
    "'cp-any'" num_experiments \
    "$(_where "$(_eq rx_type 'conv-plasma')" "${conds[@]}")" \
    "$(_groupby 'rx_type' "${aggregate_by[@]}")" \
    "$(_orderby 'num_experiments')" \
    \
    infected_var_name num_experiments \
    "$(_where "$(_notnull infected_var_name)" "${conds[@]}")" \
    "$(_groupby "infected_variant" "${aggregate_by[@]}")" \
    "$(_orderby 'infected_var_name' 'num_experiments')"
}


query_vaccine() {
  local ref_name=$(_getval ref_name "$@")
  local var_name=$(_getval var_name "$@")
  local iso_aggkey=$(_getval iso_aggkey "$@")
  local gene_pos=$(_getval position "$@")

  aggregate_by=()
  conds=()

  _append_eq ref_name "$ref_name"
  _append_eq var_name "$var_name"
  _append_eq iso_aggkey "$iso_aggkey"
  _append_eq position "$gene_pos"

  _execute \
    "'any'" num_experiments \
    "$(_where "${conds[@]}")" \
    "$(_groupby "${aggregate_by[@]}")" \
    "$(_orderby 'num_experiments')" \
    \
    "'vp-any'" num_experiments \
    "$(_where "$(_eq rx_type 'vacc-plasma')" "${conds[@]}")" \
    "$(_groupby 'rx_type' "${aggregate_by[@]}")" \
    "$(_orderby 'num_experiments')" \
    \
    vaccine_name num_experiments \
    "$(_where "$(_notnull vaccine_name)" "${conds[@]}")" \
    "$(_groupby "vaccine" "${aggregate_by[@]}")" \
    "$(_orderby 'vaccine_name' 'num_experiments')"
}


query_isolate_agg() {
  local ref_name=$(_getval ref_name "$@")
  local ab_names=$(_getval antibody_names "$@")
  local vaccine_name=$(_getval vaccine_name "$@")
  local infected_var_name=$(_getval infected_var_name "$@")

  aggregate_by=()
  conds=()

  _append_eq ref_name "$ref_name"
  _append_eq antibody_names "$ab_names"
  _append_eq vaccine_name "$vaccine_name"
  _append_eq infected_var_name "$infected_var_name"

  _execute \
    "'any'" num_experiments \
    "$(_where "${conds[@]}")" \
    "$(_groupby "${aggregate_by[@]}")" \
    "$(_orderby 'num_experiments')" \
    \
    iso_aggkey num_experiments \
    "$(_where "$(_notnull iso_aggkey)" "${conds[@]}")" \
    "$(_groupby 'isolate_agg' "${aggregate_by[@]}")" \
    "$(_orderby 'iso_aggkey' 'num_experiments')"
}


query_variant() {
  local ref_name=$(_getval ref_name "$@")
  local ab_names=$(_getval antibody_names "$@")
  local vaccine_name=$(_getval vaccine_name "$@")
  local infected_var_name=$(_getval infected_var_name "$@")

  aggregate_by=()
  conds=()

  _append_eq ref_name "$ref_name"
  _append_eq antibody_names "$ab_names"
  _append_eq vaccine_name "$vaccine_name"
  _append_eq infected_var_name "$infected_var_name"

  _execute \
    "'any'" num_experiments \
    "$(_where "${conds[@]}")" \
    "$(_groupby "${aggregate_by[@]}")" \
    "$(_orderby 'num_experiments')" \
    \
    var_name num_experiments \
    "$(_where "$(_notnull var_name)" "${conds[@]}")" \
    "$(_groupby 'variant' "${aggregate_by[@]}")" \
    "$(_orderby 'var_name' 'num_experiments')"
}


query_isolate() {
  local ref_name=$(_getval ref_name "$@")
  local ab_names=$(_getval antibody_names "$@")
  local vaccine_name=$(_getval vaccine_name "$@")
  local infected_var_name=$(_getval infected_var_name "$@")

  aggregate_by=()
  conds=()

  _append_eq ref_name "$ref_name"
  _append_eq antibody_names "$ab_names"
  _append_eq vaccine_name "$vaccine_name"
  _append_eq infected_var_name "$infected_var_name"

  _execute \
    "'any'" num_experiments \
    "$(_where "${conds[@]}")" \
    "$(_groupby "${aggregate_by[@]}")" \
    "$(_orderby 'num_experiments')" \
    \
    iso_name num_experiments \
    "$(_where "$(_notnull iso_name)" "${conds[@]}")" \
    "$(_groupby 'isolate' "${aggregate_by[@]}")" \
    "$(_orderby 'iso_name' 'num_experiments')"
}


query_position() {
  local ref_name=$(_getval ref_name "$@")
  local ab_names=$(_getval antibody_names "$@")
  local vaccine_name=$(_getval vaccine_name "$@")
  local infected_var_name=$(_getval infected_var_name "$@")

  aggregate_by=()
  conds=()

  _append_eq ref_name "$ref_name"
  _append_eq antibody_names "$ab_names"
  _append_eq vaccine_name "$vaccine_name"
  _append_eq infected_var_name "$infected_var_name"

    _execute \
    "'any'" num_experiments \
    "$(_where "${conds[@]}")" \
    "$(_groupby "${aggregate_by[@]}")" \
    "$(_orderby 'num_experiments')" \
    \
    position num_experiments \
    "$(_where "$(_notnull position)" "${conds[@]}")" \
    "$(_groupby 'position' "${aggregate_by[@]}")" \
    "$(_orderby 'position' 'num_experiments')"
}

# has_results() {
#   local ref_name=$(_getval ref_name "$@")
#   local ab_names=$(_getval antibody_names "$@")
#   local vaccine_name=$(_getval vaccine_name "$@")
#   local infected_var_name=$(_getval infected_var_name "$@")
#   local var_name=$(_getval var_name "$@")
#   local iso_aggkey=$(_getval iso_aggkey "$@")
#   local gene_pos=$(_getval position "$@")
# 
#   aggregate_by=()
#   conds=()
# 
#   _append_eq ref_name "$ref_name"
#   _append_eq antibody_names "$ab_names"
#   _append_eq vaccine_name "$vaccine_name"
#   _append_eq infected_var_name "$infected_var_name"
#   _append_eq var_name "$var_name"
#   _append_eq iso_aggkey "$iso_aggkey"
#   _append_eq position "$gene_pos"
# 
#   local ret=$(sqlite3 $DBFILE "
#     SELECT NOT EXISTS (
#       SELECT 1 FROM susc_summary WHERE
#         $(_join ' AND ' "${conds[@]}")
#     )
#     ")
#   return $ret
# }

query_all() {
  article_numexp=$(query_article "$@")
  antibody_any_numexp=$(query_antibody "$@")
  infected_variant_numexp=$(query_infected_variant "$@")
  vaccine_numexp=$(query_vaccine "$@")
  isolate_agg_numexp=$(query_isolate_agg "$@")
  variant_numexp=$(query_variant "$@")
  isolate_numexp=$(query_isolate "$@")
  position_numexp=$(query_position "$@")

  echo "{
    \"article\": ${article_numexp},
    \"antibody:any\": ${antibody_any_numexp},
    \"infected_variant\": ${infected_variant_numexp},
    \"vaccine\": ${vaccine_numexp},
    \"isolate_agg\": ${isolate_agg_numexp},
    \"variant\": ${variant_numexp},
    \"isolate\": ${isolate_numexp},
    \"position\": ${position_numexp}
  }" | jq -cr .
}


list_combinations() {
  sqlite3 -separator '$$' $DBFILE "
    SELECT DISTINCT $(_join ', ' "$@") FROM susc_summary
    WHERE $(_join ' IS NOT NULL AND ' "$@") IS NOT NULL
    ORDER BY $(_join ', ' "$@")
  "
}

# query_article 'antibody_names:157'
# query_antibody "antibody:any" "Ai22" 
# query_infected_variant "Cele22" 
# query_vaccine "Cele22" 
# query_isolate_agg "Cele22" 
# query_variant "Cele22" 
# query_isolate "Cele22" 
# query_position "Li20h" 
# query_all "Li20h" 


create_file() {
  local vals=($(_split '$$' "$1"))
  shift
  local keys=("$@")
  local options=()
  local json_params='{}'
  for idx in $(seq 0 $((${#keys[@]}-1))); do
    json_params="$(
      json_params="$json_params" jq \
      --arg "${keys[$idx]}" "${vals[$idx]}" \
      -ncr "(env.json_params | fromjson) + {\$${keys[$idx]}}"
    )"
    options+=("${keys[$idx]}:${vals[$idx]}")
  done
  hash=$(echo -n "$json_params" | sha256sum | awk '{print $1}')
  filepath="$SHM_TARGET_DIR/${hash:0:2}/${hash:2:2}/${hash:4:60}.json"
  mkdir -p $(dirname "$filepath")

  result="$(query_all "${options[@]}")" params="$json_params" jq \
    -ncr '{params: (env.params | fromjson)} + (env.result | fromjson)' > $filepath
  
  # echo $filepath
}

sp='/-\|'
spidx=1
progress() {
  local complete=$1
  local total=$2
  local pcnt=$((complete*100/total))
  echo -ne '\r'
  printf "  ${sp:spidx%${#sp}:1} "
  echo -n "$complete/$total ($pcnt%)"
  ((spidx++))
}


create_files() {
  echo "Create files for $(_join ', ' "$@"):"
  local keys=("$@")
  local idx=1
  local rows=($(list_combinations "${keys[@]}"))
  local processed=1
  local nrows=${#rows[@]}
  for row in "${rows[@]}"; do
    create_file "$row" "${keys[@]}" &
    if [ $idx -gt $PARALLELS ]; then
      let idx=idx-PARALLELS
      wait
      progress $processed $nrows
    fi
    let idx++
    let processed++
  done
  wait
  progress $nrows $nrows
  echo " done"
}


PARAMS=(
  ref_name
  antibody_names
  infected_var_name
  vaccine_name
  var_name
  iso_aggkey
  position
)

PARAM_GROUPS=(ref rx rx rx virus virus virus)

# combination of one
for param in "${PARAMS[@]}"; do
  create_files $param
done

# combination of two
last_idx=$((${#PARAMS[@]}-1))
for i in $(seq 0 $last_idx); do
  g1=${PARAM_GROUPS[$i]}
  for j in $(seq $((i+1)) $last_idx); do
    g2=${PARAM_GROUPS[$j]}
    if [[ "$g1" == "$g2" ]]; then
      continue
    fi
    create_files ${PARAMS[$i]} ${PARAMS[$j]}
  done
done

# combination of three
last_idx=$((${#PARAMS[@]}-1))
for i in $(seq 0 $last_idx); do
  g1=${PARAM_GROUPS[$i]}
  for j in $(seq $((i+1)) $last_idx); do
    g2=${PARAM_GROUPS[$j]}
    for k in $(seq $((j+1)) $last_idx); do
      g3=${PARAM_GROUPS[$k]}
      if [[ "$g1" == "$g2" || "$g1" == "$g3" || "$g2" == "$g3" ]]; then
        continue
      fi
      create_files ${PARAMS[$i]} ${PARAMS[$j]} ${PARAMS[$k]}
    done
  done
done

rsync --recursive --links --perms --group --owner --verbose --delete --checksum $SHM_TARGET_DIR/ $TARGET_DIR/
aws s3 sync --delete $TARGET_DIR/ s3://cms.hivdb.org/covid-drdb:susc-summary/
