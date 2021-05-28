from .cli import cli
from .commands import autofill_payload
from .commands import merge_ptrx_and_plasma

__all__ = [
    'cli',
    'autofill_payload',
    'merge_ptrx_and_plasma'
]


if __name__ == '__main__':
    cli()
