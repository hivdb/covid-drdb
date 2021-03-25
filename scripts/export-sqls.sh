#! /bin/bash

set -e

cd $(dirname $0)/..

DBML2SQL=$(which dbml2sql)
TARGET_DIR="local/sqls"

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
    @npm install -g @dbml/cli
fi

mkdir -p $TARGET_DIR

dbml2sql --postgres schema.dbml > $TARGET_DIR/01_schema.sql
echo "Written to $TARGET_DIR/01_schema.sql"

copy_csv payload/tables/articles.csv articles > $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/article_notes.csv article_notes >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/treatments.csv treatments >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/antibodies.csv antibodies >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/antibody_targets.csv antibody_targets >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/antibody_synonyms.csv antibody_synonyms >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/virus_variants.csv virus_variants >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/variant_mutations.csv variant_mutations >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/ref_amino_acid.csv ref_amino_acid >> $TARGET_DIR/02_data_tables.sql
ls payload/tables/susc_results | sort -h | while read filepath; do
    copy_csv payload/tables/susc_results/$filepath susc_results >> $TARGET_DIR/02_data_tables.sql
done
ls payload/tables/invitro_selection_results | sort -h | while read filepath; do
    copy_csv payload/tables/invitro_selection_results/$filepath invitro_selection_results >> $TARGET_DIR/02_data_tables.sql
done
ls payload/tables/invivo_selection_results | sort -h | while read filepath; do
    copy_csv payload/tables/invivo_selection_results/$filepath invivo_selection_results >> $TARGET_DIR/02_data_tables.sql
done
ls payload/tables/rx_antibodies | sort -h | while read filepath; do
    copy_csv payload/tables/rx_antibodies/$filepath rx_antibodies >> $TARGET_DIR/02_data_tables.sql
done
ls payload/tables/rx_conv_plasma | sort -h | while read filepath; do
    copy_csv payload/tables/rx_conv_plasma/$filepath rx_conv_plasma >> $TARGET_DIR/02_data_tables.sql
done
ls payload/tables/rx_immu_plasma | sort -h | while read filepath; do
    copy_csv payload/tables/rx_immu_plasma/$filepath rx_immu_plasma >> $TARGET_DIR/02_data_tables.sql
done

copy_csv payload/tables/dms/dms_ace2_binding.csv dms_ace2_binding >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/dms/dms_rx.csv dms_rx >> $TARGET_DIR/02_data_tables.sql
copy_csv payload/tables/dms/dms_escape_score.csv dms_escape_score >> $TARGET_DIR/02_data_tables.sql


echo "Written to $TARGET_DIR/02_data_tables.sql"
