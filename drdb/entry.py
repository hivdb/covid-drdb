from .cli import cli
from .commands import autofill_payload
from .commands import update_variant_consensus
from .commands import update_ref_amino_acid
from .commands import update_glue_prevalence
from .commands import extract_gisaid_mutations
from .commands import gen_mutation_distance

__all__ = [
    'cli',
    'autofill_payload',
    'update_variant_consensus',
    'update_ref_amino_acid',
    'update_glue_prevalence',
    'extract_gisaid_mutations',
    'gen_mutation_distance'
]


if __name__ == '__main__':
    cli()
