from .cli import cli
from .commands import autofill_payload
from .commands import merge_expgroup

__all__ = [
    'cli',
    'autofill_payload',
    'merge_expgroup'
]


if __name__ == '__main__':
    cli()
