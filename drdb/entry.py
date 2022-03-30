from .cli import cli
from .commands import autofill_payload
from .commands import update_variant_consensus
from .commands import update_ref_amino_acid
from .commands import update_glue_prevalence
from .commands import extract_gisaid_mutations
from .commands import gen_mutation_distance
from .commands import fetch_iedb_epitopes
from .commands import extract_sierra_mutations
from .commands import refactor_sbj_history
from .commands import new_selection_study

__all__ = [
    'cli',
    'autofill_payload',
    'update_variant_consensus',
    'update_ref_amino_acid',
    'update_glue_prevalence',
    'extract_gisaid_mutations',
    'extract_sierra_mutations',
    'gen_mutation_distance',
    'fetch_iedb_epitopes',
    'refactor_sbj_history',
    'new_selection_study'
]


if __name__ == '__main__':
    cli()
