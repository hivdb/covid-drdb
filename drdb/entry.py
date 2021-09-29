from .cli import cli
from .commands import autofill_payload
from .commands import update_variant_consensus
from .commands import update_ref_amino_acid

__all__ = [
    'cli',
    'autofill_payload',
    'update_variant_consensus',
    'update_ref_amino_acid'
]


if __name__ == '__main__':
    cli()
