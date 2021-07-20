#! /bin/bash

DBML2SQL=$(which dbml2sql)
DOS2UNIX=$(which dos2unix)
TARGET_DIR="local/sqls"

set -e

cd $(dirname $0)/..

function copy_csv() {
    source_csv=$1
    target_table=$2
    cat <<EOF
COPY "$target_table" FROM STDIN WITH DELIMITER ',' CSV HEADER NULL 'NULL';
$(cat $source_csv | dos2unix)
\.

EOF
}

if [ ! -x "$DBML2SQL" ]; then
    npm install -g @dbml/cli
fi

if [ ! -x "$DOS2UNIX" ]; then
    brew install dos2unix
fi

mkdir -p $TARGET_DIR

dbml2sql --postgres schema.dbml > $TARGET_DIR/01_schema.sql
cat constraints_pre-import.sql >> $TARGET_DIR/01_schema.sql
echo "Written to $TARGET_DIR/01_schema.sql"

copy_csv payload/tables/assays.csv assays > $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/articles.csv articles >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/article_notes.csv article_notes >> $TARGET_DIR/02_data_tables.sql

copy_csv payload/tables/treatments.csv treatments >> $TARGET_DIR/02_data_tables.sql

copy_csv payload/tables/antibodies.csv antibodies >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/antibody_targets.csv antibody_targets >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/antibody_epitopes.csv antibody_epitopes >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/antibody_synonyms.csv antibody_synonyms >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/antibody_articles.csv antibody_articles >> $TARGET_DIR/02_data_tables.sql

copy_csv payload/tables/genes.csv genes >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/gene_synonyms.csv gene_synonyms >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/variants.csv variants >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/variant_synonyms.csv variant_synonyms >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/isolates.csv isolates >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/isolate_mutations.csv isolate_mutations >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/ref_amino_acid.csv ref_amino_acid >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/vaccines.csv vaccines >> $TARGET_DIR/02_data_tables.sql
ls payload/tables/invitro_selection_results | sort -h | while read filepath; do
    copy_csv payload/tables/invitro_selection_results/$filepath invitro_selection_results >> $TARGET_DIR/02_data_tables.sql
done
ls payload/tables/invivo_selection_results | sort -h | while read filepath; do
    copy_csv payload/tables/invivo_selection_results/$filepath invivo_selection_results >> $TARGET_DIR/02_data_tables.sql
done
ls payload/tables/rx_antibodies | sort -h | while read filepath; do
    copy_csv payload/tables/rx_antibodies/$filepath rx_antibodies >> $TARGET_DIR/02_data_tables.sql
done
copy_csv payload/tables/subjects.csv subjects >> $TARGET_DIR/02_data_tables.sql
ls payload/tables/rx_plasma | sort -h | while read filepath; do
    copy_csv payload/tables/rx_plasma/$filepath rx_plasma >> $TARGET_DIR/02_data_tables.sql
done

ls payload/tables/subject_history | sort -h | while read filepath; do
    copy_csv payload/tables/subject_history/$filepath subject_history >> $TARGET_DIR/02_data_tables.sql
done

ls payload/tables/rx_fold | sort -h | while read filepath; do
    copy_csv payload/tables/rx_fold/$filepath rx_fold >> $TARGET_DIR/02_data_tables.sql
done

ls payload/tables/rx_potency | sort -h | while read filepath; do
    copy_csv payload/tables/rx_potency/$filepath rx_potency >> $TARGET_DIR/02_data_tables.sql
done

ls payload/tables/ref_isolate_pairs | sort -h | while read filepath; do
    copy_csv payload/tables/ref_isolate_pairs/$filepath ref_isolate_pairs >> $TARGET_DIR/02_data_tables.sql
done


# ## Excluded results
# copy_csv payload/excluded/treatments.csv treatments >> $TARGET_DIR/02_data_tables.sql
# # ls payload/excluded/invitro_selection_results | sort -h | while read filepath; do
# #     copy_csv payload/excluded/invitro_selection_results/$filepath invitro_selection_results >> $TARGET_DIR/02_data_tables.sql
# # done
# ls payload/excluded/invivo_selection_results | sort -h | while read filepath; do
#     copy_csv payload/excluded/invivo_selection_results/$filepath invivo_selection_results >> $TARGET_DIR/02_data_tables.sql
# done
# ls payload/excluded/rx_antibodies | sort -h | while read filepath; do
#     copy_csv payload/excluded/rx_antibodies/$filepath rx_antibodies >> $TARGET_DIR/02_data_tables.sql
# done
# ls payload/excluded/rx_plasma | sort -h | while read filepath; do
#     copy_csv payload/excluded/rx_plasma/$filepath rx_plasma >> $TARGET_DIR/02_data_tables.sql
# done
# ## End of Excluded results

copy_csv payload/tables/dms/dms_ace2_binding.csv dms_ace2_binding >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/dms/rx_dms.csv rx_dms >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/dms/dms_escape_results.csv dms_escape_results >> $TARGET_DIR/02_data_tables.sql

pushd payload/
if [ -z "$(git status -s .)" ]
then
    mtime=$(git log -1 --date unix . | \grep '^Date:' | \awk '{print $2}')
else
    # echo 'There are uncommited changes under payload/ repository. Please commit your changes.' 1>&2
    # exit 42
    if [ "$(uname)" = "Darwin" ]
    then
        mtime=$(find . -type f -print0 | xargs -0 stat -f %m | sort -nr | head -1)
    else
        mtime=$(find . -type f -print0 | xargs -0 stat -c %Y | sort -nr | head -1)
    fi
fi
export TZ=0
last_update=$(date -r ${mtime} +%FT%TZ)
popd
echo "INSERT INTO last_update (scope, last_update) VALUES ('global', '${last_update}');" >> $TARGET_DIR/02_data_tables.sql

echo "Written to $TARGET_DIR/02_data_tables.sql"

echo '' > $TARGET_DIR/03_derived_tables.sql
ls derived_tables/*.sql | sort -h | while read filepath; do
    cat $filepath >> $TARGET_DIR/03_derived_tables.sql
done
cat constraints_post-import.sql >> $TARGET_DIR/03_derived_tables.sql
echo "Written to $TARGET_DIR/03_derived_tables.sql"
