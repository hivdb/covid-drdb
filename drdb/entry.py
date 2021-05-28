from .cli import cli
from .commands import autofill_payload
from .commands import merge_cpvp
from .commands import update_pt_history

__all__ = [
    'cli',
    'autofill_payload',
    'merge_cpvp',
    'update_pt_history'
]


if __name__ == '__main__':
    cli()
