from .cli import cli
from .commands import autofill_payload

__all__ = [
    'cli',
    'autofill_payload'
]


if __name__ == '__main__':
    cli()
