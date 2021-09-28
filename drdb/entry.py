from .cli import cli
from .commands import autofill_payload
from .commands import update_variant_consensus

__all__ = [
    'cli',
    'autofill_payload',
    'update_variant_consensus'
]


if __name__ == '__main__':
    cli()
