import click
import requests
from pathlib import Path
from ..cli import cli
from ..utils.csvv import dump_csv

GENES_URL = (
    'https://raw.githubusercontent.com/hivdb/sierra-sars2/'
    'master/src/main/resources/genes.json'
)


@cli.command()
@click.argument(
    'payload_dir',
    type=click.Path(
        dir_okay=True,
        exists=True,
        file_okay=False
    )
)
def update_ref_amino_acid(payload_dir):
    payload_dir = Path(payload_dir)
    refaa_csv = payload_dir / 'tables' / 'ref_amino_acid.csv'
    resp = requests.get(GENES_URL)
    genes = resp.json()
    rows = []
    for gene_def in genes:
        gene = gene_def['abstractGene']
        refseq = gene_def['refSequence']
        for pos0, aa in enumerate(refseq):
            rows.append({
                'gene': gene,
                'position': pos0 + 1,
                'amino_acid': aa
            })
    dump_csv(
        refaa_csv,
        rows,
        ['gene', 'position', 'amino_acid']
    )
