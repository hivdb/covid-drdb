import click
from pathlib import Path
from more_itertools import unique_everseen

from ..cli import cli
from ..utils.csvv import load_csv, dump_csv, load_multiple_csvs


def autofill_suscs(tables_dir):
    suscs = tables_dir / 'susc_results'
    for susc in suscs.iterdir():
        if susc.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(susc))
            continue
        rows = load_csv(susc)
        for row in rows:
            if not row.get('fold'):
                row['fold'] = None
                row['fold_cmp'] = None
            elif not row.get('fold_cmp'):
                row['fold_cmp'] = '='
            if not row.get('ordinal_number'):
                row['ordinal_number'] = 1
            if not row.get('cumulative_count'):
                row['cumulative_count'] = 1
            if not row.get('resistance_level'):
                row['resistance_level'] = None
        click.echo('Write to {}'.format(susc))
        dump_csv(
            susc,
            records=rows,
            headers=[
                'ref_name',
                'rx_name',
                'strain_name',
                'ordinal_number',
                'section',
                'fold_cmp',
                'fold',
                'resistance_level',
                'cumulative_count',
                'date_added'
            ],
            BOM=True
        )


def autofill_invitros(tables_dir):
    invitros = tables_dir / 'invitro_selection_results'
    for invitro in invitros.iterdir():
        if invitro.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(invitro))
            continue
        rows = load_csv(invitro)
        click.echo('Write to {}'.format(invitro))
        dump_csv(
            invitro,
            records=rows,
            headers=[
                'ref_name',
                'rx_name',
                'gene',
                'position',
                'amino_acid',
                'section',
                'date_added'
            ],
            BOM=True
        )


def autofill_invivos(tables_dir):
    invivos = tables_dir / 'invivo_selection_results'
    for invivo in invivos.iterdir():
        if invivo.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(invivo))
            continue
        rows = load_csv(invivo)
        click.echo('Write to {}'.format(invivo))
        dump_csv(
            invivo,
            records=rows,
            headers=[
                'ref_name',
                'rx_name',
                'strain_name',
                'patient',
                'sample',
                'section',
                'date_added'
            ],
            BOM=True
        )


def autofill_rx(tables_dir):
    rxmabs = load_multiple_csvs(tables_dir / 'rx_antibodies')
    rxcps = load_multiple_csvs(tables_dir / 'rx_conv_plasma')
    rxips = load_multiple_csvs(tables_dir / 'rx_immu_plasma')
    naive_rx = load_csv(tables_dir / 'naive-rx.csv')
    treatments = list(unique_everseen([
        {'ref_name': rx['ref_name'],
         'rx_name': rx['rx_name']}
        for rx in rxmabs + rxcps + rxips + naive_rx
    ]))
    click.echo('Write to {}'.format(tables_dir / 'treatments.csv'))
    dump_csv(
        tables_dir / 'treatments.csv',
        records=treatments,
        headers=['ref_name', 'rx_name'],
        BOM=True
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
def autofill_payload(payload_dir):
    payload_dir = Path(payload_dir)
    tables_dir = payload_dir / 'tables'
    autofill_rx(tables_dir)
    autofill_suscs(tables_dir)
    autofill_invitros(tables_dir)
    autofill_invivos(tables_dir)
