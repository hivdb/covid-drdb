import click
from pathlib import Path
from more_itertools import unique_everseen
from operator import itemgetter
from ..cli import cli
from ..utils.csvv import load_csv, dump_csv, load_multiple_csvs


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
                'subject',
                'sampling',
                'num_subjects',
                'num_subjects_with_mut',
                'section',
                'note',
                'date_added',
            ],
            BOM=True
        )


def autofill_rx(tables_dir):
    rxmabs = load_multiple_csvs(tables_dir / 'rx_antibodies')
    rxps = load_multiple_csvs(tables_dir / 'rx_plasma')

    invitro = []
    file_path = tables_dir / 'invitro_selection_results'
    if file_path.exists():
        invitro = load_multiple_csvs(file_path)

    naive_rx = []
    file_path = tables_dir / 'naive-rx.csv'
    if file_path.exists():
        naive_rx = load_csv(file_path)

    rxdms = []
    file_path = tables_dir / 'dms' / 'rx_dms.csv'
    if file_path.exists():
        rxdms = load_csv(file_path)

    treatments = list(unique_everseen([
        {'ref_name': rx['ref_name'],
         'rx_name': rx['rx_name']}
        for rx in rxmabs + rxps + naive_rx + invitro + rxdms
    ]))
    click.echo('Write to {}'.format(tables_dir / 'treatments.csv'))
    dump_csv(
        tables_dir / 'treatments.csv',
        records=treatments,
        headers=['ref_name', 'rx_name'],
        BOM=True
    )


def autofill_rx_plasma(tables_dir):
    rxcps = tables_dir / 'rx_plasma'
    for rxcp in rxcps.iterdir():
        if rxcp.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(rxcp))
            continue
        rows = load_csv(rxcp)
        for row in rows:
            if row.get('subject_name') is None:
                row['subject_name'] = row['rx_name']
        click.echo('Write to {}'.format(rxcp))
        dump_csv(
            rxcp,
            records=rows,
            headers=[
                'ref_name',
                'rx_name',
                'subject_name',
                'titer',
                'collection_date',
                'cumulative_group',
            ],
            BOM=True
        )


def autofill_dms(tables_dir):
    ace2_binding = tables_dir / 'dms' / 'dms_ace2_binding.csv'
    rows = load_csv(ace2_binding)

    for row in rows:
        if not row['ace2_binding']:
            row['ace2_binding'] = None
        if not row['expression']:
            row['expression'] = None

    click.echo('Write to {}'.format(ace2_binding))
    dump_csv(
        ace2_binding,
        records=rows,
        headers=[
            'gene',
            'position',
            'amino_acid',
            'ace2_binding',
            'expression',
            'ace2_contact',
        ],
        BOM=True,
    )

    escape_score = tables_dir / 'dms' / 'dms_escape_results.csv'
    rows = load_csv(escape_score)

    for row in rows:
        if not row['escape_score']:
            row['escape_score'] = None

    click.echo('Write to {}'.format(escape_score))
    dump_csv(
        escape_score,
        records=rows,
        headers=[
            'ref_name',
            'rx_name',
            'gene',
            'position',
            'amino_acid',
            'escape_score',
        ],
        BOM=True,
    )


def sort_csv(file_path, *key_list):
    records = load_csv(file_path)
    records.sort(key=itemgetter(*key_list))
    dump_csv(file_path, records)


def autofill_subjects(tables_dir):
    known_subjects = {
        (r['ref_name'], r['subject_name']): r
        for r in load_csv(tables_dir / 'subjects.csv')
    }

    rx_plasma = load_multiple_csvs(tables_dir / 'rx_plasma')

    subjects = sorted(
        unique_everseen([
            {'ref_name': rx['ref_name'],
             'subject_name': rx['subject_name'],
             'subject_species': (
                 known_subjects
                 .get((rx['ref_name'], rx['subject_name']), {})
                 .get('subject_species') or 'Human'
             ),
             'num_subjects': (
                 known_subjects
                 .get((rx['ref_name'], rx['subject_name']), {})
                 .get('num_subjects') or 1
             ),
             }
            for rx in rx_plasma
        ]),
        key=lambda rx: (rx['ref_name'], rx['subject_name'])
    )
    click.echo('Write to {}'.format(tables_dir / 'subjects.csv'))
    dump_csv(
        tables_dir / 'subjects.csv',
        records=subjects,
        headers=[
            'ref_name',
            'subject_name',
            'subject_species',
            'num_subjects'
        ],
        BOM=True
    )


def autofill_sub_history(tables_dir):
    pth_list = tables_dir / 'subject_history'
    for pth in pth_list.iterdir():
        if pth.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(pth))
            continue
        rows = load_csv(pth)
        for row in rows:
            if not row.get('iso_name'):
                row['iso_name'] = None
            if not row.get('severity'):
                row['severity'] = None
            if not row.get('vaccine_name'):
                row['vaccine_name'] = None
            if row['event'] not in ('1st dose', '2nd dose', '3rd dose'):
                row['vaccine_name'] = None
        click.echo('Write to {}'.format(pth))
        dump_csv(
            pth,
            records=rows,
            headers=[
                'ref_name',
                'subject_name',
                'event',
                'event_date_cmp',
                'event_date',
                'location',
                'iso_name',
                'vaccine_name',
                'severity',
            ],
            BOM=True
        )


def autofill_rx_potency(tables_dir):
    pth_list = tables_dir / 'rx_potency'
    for pth in pth_list.iterdir():
        if pth.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(pth))
            continue
        rows = load_csv(pth)
        for row in rows:
            row['potency_type'] = row.get('potency_type') or 'NT50'
            row['cumulative_count'] = row.get('cumulative_count') or 1
        click.echo('Write to {}'.format(pth))
        dump_csv(
            pth,
            records=rows,
            headers=[
                'ref_name',
                'rx_name',
                'iso_name',
                'section',
                'assay_name',
                'potency_type',
                'potency',
                'cumulative_count',
                'potency_upper_limit',
                'potency_lower_limit',
                'potency_unit',
                'date_added',
            ],
            BOM=True
        )


def autofill_rx_fold(tables_dir):
    suscs = tables_dir / 'rx_fold'
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
            if not row.get('cumulative_count'):
                row['cumulative_count'] = 1
            if not row.get('resistance_level'):
                row['resistance_level'] = None
            if not row.get('assay_name'):
                row['assay_name'] = None
            if not row.get('control_iso_name'):
                row['control_iso_name'] = 'Control'
            if not row.get('ineffective'):
                row['ineffective'] = None
            if not row.get('potency_type'):
                row['potency_type'] = 'IC50'
            if row.get('potency_type') == '0':
                row['potency_type'] = 'IC50'
            if row.get('potency_type') == '90':
                row['potency_type'] = 'IC90'
            if row.get('potency_type') == '50':
                row['potency_type'] = 'IC50'

        click.echo('Write to {}'.format(susc))
        dump_csv(
            susc,
            records=rows,
            headers=[
                'ref_name',
                'rx_name',
                'control_iso_name',
                'iso_name',
                'section',
                'assay_name',
                'potency_type',
                'fold_cmp',
                'fold',
                'resistance_level',
                'ineffective',
                'cumulative_count',
                'date_added'
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
    autofill_invitros(tables_dir)
    autofill_invivos(tables_dir)
    autofill_rx_plasma(tables_dir)
    autofill_dms(tables_dir)
    autofill_rx_fold(tables_dir)
    autofill_rx_potency(tables_dir)

    autofill_subjects(tables_dir)
    autofill_sub_history(tables_dir)

    antibodies = tables_dir / 'antibodies.csv'
    sort_csv(antibodies, 'ab_name')
    antibody_targets = tables_dir / 'antibody_targets.csv'
    sort_csv(antibody_targets, 'ab_name')
