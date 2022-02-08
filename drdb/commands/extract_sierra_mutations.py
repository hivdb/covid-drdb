import os
import csv
import click
from tqdm import tqdm  # type: ignore
from typing import TextIO, Dict, List

from ..cli import cli

HEADER: List[str] = [
    'iso_name',
    'gene',
    'position',
    'amino_acid',
    'count',
    'total'
]


@cli.command()
@click.argument(
    'sierra-mutation-list-dir',
    type=click.Path(exists=True, file_okay=False)
)
@click.argument(
    'output_mutations_csv',
    type=click.File('w', encoding='UTF-8-sig')
)
def extract_sierra_mutations(
    sierra_mutation_list_dir: str,
    output_mutations_csv: TextIO
) -> None:
    fp: TextIO
    mutlist: str
    row: Dict[str, str]

    reader: csv.DictReader
    writer: csv.DictWriter = csv.DictWriter(
        output_mutations_csv,
        HEADER
    )
    writer.writeheader()

    for mutlist in tqdm(os.listdir(sierra_mutation_list_dir)):
        if not mutlist.startswith('MutationList') or \
                not mutlist.endswith('.csv'):
            continue
        mutlist = os.path.join(sierra_mutation_list_dir, mutlist)
        with open(mutlist, encoding='UTF-8-sig') as fp:
            reader = csv.DictReader(fp)
            for row in reader:
                writer.writerow({
                    'iso_name': row['Sequence Name'],
                    'gene': row['Gene'],
                    'position': row['Position'],
                    'amino_acid': row['MutAA'],
                    'count': 'NULL',
                    'total': 'NULL'
                })
    click.echo('Create {}'.format(output_mutations_csv.name))
