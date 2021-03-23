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
            if not row.get('assay'):
                row['assay'] = None
            if not row.get('control_variant_name'):
                row['control_variant_name'] = 'Control'
            if not row.get('ineffective'):
                row['ineffective'] = None
        click.echo('Write to {}'.format(susc))
        dump_csv(
            susc,
            records=rows,
            headers=[
                'ref_name',
                'rx_name',
                'control_variant_name',
                'variant_name',
                'ordinal_number',
                'section',
                'fold_cmp',
                'fold',
                'resistance_level',
                'ineffective',
                'cumulative_count',
                'assay',
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

        for row in rows:
            if not row['dosage']:
                row['dosage'] = 'None'
            if not row['rx_name']:
                row['rx_name'] = 'None'
            if not row['position']:
                row['position'] = None
            if not row['amino_acid']:
                row['amino_acid'] = None

        click.echo('Write to {}'.format(invivo))
        dump_csv(
            invivo,
            records=rows,
            headers=[
                'ref_name',
                'rx_name',
                'dosage',
                'host',
                'infection_name',
                'gene',
                'position',
                'amino_acid',
                'patient',
                'sampling',
                'num_patients',
                'num_patients_with_mut',
                'section',
                'note',
                'date_added',
            ],
            BOM=True
        )


def autofill_rx(tables_dir):
    rxmabs = load_multiple_csvs(tables_dir / 'rx_antibodies')
    rxcps = load_multiple_csvs(tables_dir / 'rx_conv_plasma')
    rxips = load_multiple_csvs(tables_dir / 'rx_immu_plasma')
    invitro = load_multiple_csvs(tables_dir / 'invitro_selection_results')
    naive_rx = load_csv(tables_dir / 'naive-rx.csv')
    treatments = list(unique_everseen([
        {'ref_name': rx['ref_name'],
         'rx_name': rx['rx_name']}
        for rx in rxmabs + rxcps + rxips + naive_rx + invitro
    ]))
    click.echo('Write to {}'.format(tables_dir / 'treatments.csv'))
    dump_csv(
        tables_dir / 'treatments.csv',
        records=treatments,
        headers=['ref_name', 'rx_name'],
        BOM=True
    )


def autofill_rx_conv_plasma(tables_dir):
    rxcps = tables_dir / 'rx_conv_plasma'
    for rxcp in rxcps.iterdir():
        if rxcp.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(rxcp))
            continue
        rows = load_csv(rxcp)
        click.echo('Write to {}'.format(rxcp))
        dump_csv(
            rxcp,
            records=rows,
            headers=[
                'ref_name',
                'rx_name',
                'infection',
                'cumulative_group',
            ],
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
    autofill_rx_conv_plasma(tables_dir)

    tables_dir = payload_dir / 'excluded'
    autofill_suscs(tables_dir)
