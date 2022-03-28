import click
from pathlib import Path
from more_itertools import unique_everseen
from operator import itemgetter
from typing import List, Dict, Optional, Tuple

from ..cli import cli
from ..utils.csvv import (
    load_csv,
    dump_csv,
    load_multiple_csvs,
    CSVReaderRow,
    CSVWriterRow
)


def autofill_invitros(tables_dir: Path) -> None:
    rows: List[CSVReaderRow]
    invitro: Path
    invitros: Path = tables_dir / 'invitro_selection_results'
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


def autofill_invivos(tables_dir: Path) -> None:
    row: CSVReaderRow
    rows: List[CSVReaderRow]
    invivo: Path
    invivos: Path = tables_dir / 'ref_invivo'
    for invivo in invivos.iterdir():
        if invivo.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(invivo))
            continue
        rows = load_csv(invivo)

        for row in rows:
            if not row.get('note'):
                row['note'] = None

        click.echo('Write to {}'.format(invivo))
        dump_csv(
            invivo,
            records=rows,
            headers=[
                'ref_name',
                'subject_name',
                'collection_date',
                'section',
                'note',
                'date_added',
            ],
            BOM=True
        )


def autofill_rx(tables_dir: Path) -> None:
    file_path: Path

    rxmabs: List[CSVReaderRow] = load_multiple_csvs(
        tables_dir / 'rx_antibodies')

    rxps: List[
        Dict[str, Optional[str]]
    ] = load_multiple_csvs(tables_dir / 'subject_plasma')

    unclassified_rx: List[CSVReaderRow] = []
    file_path = tables_dir / 'unclassified-rx.csv'
    if file_path.exists():
        unclassified_rx = load_csv(file_path)

    # warning: do not add rx_names from invitro, invivo, or DMS tables Only the
    # rx_antibodies, subject_plasma and unclassified_rx should be the source of
    # treatments table.

    treatments: List[CSVWriterRow] = list(unique_everseen([
        {'ref_name': rx['ref_name'],
         'rx_name': rx['rx_name']}
        for rx in rxmabs + rxps + unclassified_rx
    ]))
    click.echo('Write to {}'.format(tables_dir / 'treatments.csv'))
    dump_csv(
        tables_dir / 'treatments.csv',
        records=treatments,
        headers=['ref_name', 'rx_name'],
        BOM=True
    )


def autofill_sbj_plasma(tables_dir: Path) -> None:
    rows: List[CSVReaderRow]
    rxcp: Path
    rxcps: Path = tables_dir / 'subject_plasma'
    for rxcp in rxcps.iterdir():
        if rxcp.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(rxcp))
            continue
        rows = load_csv(rxcp)
        for row in rows:
            if not row.get('collection_date_cmp'):
                row['collection_date_cmp'] = '='
            if not row.get('subject_name'):
                row['subject_name'] = row['rx_name']
            if not row.get('location'):
                row['location'] = None
            if not row.get('section'):
                row['section'] = None
        click.echo('Write to {}'.format(rxcp))
        dump_csv(
            rxcp,
            records=rows,
            headers=[
                'ref_name',
                'subject_name',
                'rx_name',
                'collection_date_cmp',
                'collection_date',
                'location',
                'cumulative_group',
                'section'
            ],
            BOM=True
        )


def autofill_dms(tables_dir: Path) -> None:
    row: CSVReaderRow
    ace2_binding: Path = tables_dir / 'dms' / 'dms_ace2_binding.csv'
    rows: List[CSVReaderRow] = load_csv(ace2_binding)

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

    escape_score: Path = tables_dir / 'dms' / 'dms_escape_results.csv'
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


def sort_csv(file_path: Path, *key_list: str) -> None:
    records: List[CSVReaderRow] = load_csv(file_path)
    records.sort(key=itemgetter(*key_list))
    dump_csv(file_path, records)


def autofill_subjects(tables_dir: Path) -> None:
    known_subjects: Dict[Tuple[str, str], CSVReaderRow] = {
        (r['ref_name'], r['subject_name']): r
        for r in load_csv(tables_dir / 'subjects.csv')
        if r['ref_name'] is not None and
        r['subject_name'] is not None
    }

    sbj_plasma: List[CSVReaderRow] = load_multiple_csvs(
        tables_dir / 'subject_plasma')
    ref_invivo: List[CSVReaderRow] = load_multiple_csvs(
        tables_dir / 'ref_invivo')

    subjects: List[CSVWriterRow] = sorted(
        unique_everseen([
            {'ref_name': rx['ref_name'],
             'subject_name': rx['subject_name'],
             'subject_species': (
                 known_subjects
                 .get((rx['ref_name'], rx['subject_name']), {})
                 .get('subject_species') or 'Human'
             ),
             'birth_year': (
                 known_subjects
                 .get((rx['ref_name'], rx['subject_name']), {})
                 .get('birth_year') or 'NULL'
             ),
             'immune_status': (
                 known_subjects
                 .get((rx['ref_name'], rx['subject_name']), {})
                 .get('immune_status') or 'NULL'
             ),
             'num_subjects': (
                 known_subjects
                 .get((rx['ref_name'], rx['subject_name']), {})
                 .get('num_subjects') or 1
             ),
             }
            for rx in sbj_plasma + ref_invivo
            if rx['ref_name'] is not None and
            rx['subject_name'] is not None

        ]),
        key=lambda rx: (rx['ref_name'] or '', rx['subject_name'] or '')
    )
    click.echo('Write to {}'.format(tables_dir / 'subjects.csv'))
    dump_csv(
        tables_dir / 'subjects.csv',
        records=subjects,
        headers=[
            'ref_name',
            'subject_name',
            'subject_species',
            'birth_year',
            'immune_status',
            'num_subjects'
        ],
        BOM=True
    )


def autofill_sbj_treatments(tables_dir: Path) -> None:
    row: CSVReaderRow
    rows: List[CSVReaderRow]
    prx: Path
    prx_list: Path = tables_dir / 'subject_treatments'
    for prx in prx_list.iterdir():
        if prx.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(prx))
            continue
        rows = load_csv(prx)
        for row in rows:
            if not row.get('start_date_cmp'):
                row['start_date_cmp'] = '='
            if not row.get('end_date_cmp'):
                row['end_date_cmp'] = '='
            if not row.get('section'):
                row['section'] = None
        click.echo('Write to {}'.format(prx))
        dump_csv(
            prx,
            records=rows,
            headers=[
                'ref_name',
                'subject_name',
                'rx_name',
                'start_date_cmp',
                'start_date',
                'end_date_cmp',
                'end_date',
                'dosage',
                'dosage_unit',
                'section'
            ],
            BOM=True
        )


def autofill_sbj_infections(tables_dir: Path) -> None:
    row: CSVReaderRow
    rows: List[CSVReaderRow]
    pth: Path
    pth_list: Path = tables_dir / 'subject_history'
    for pth in pth_list.iterdir():
        if pth.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(pth))
            continue
        rows = load_csv(pth)
        for row in rows:
            if not row.get('iso_name'):
                row['iso_name'] = None
            if not row.get('cycle_threshold_cmp'):
                row['cycle_threshold_cmp'] = None
            if not row.get('cycle_threshold'):
                row['cycle_threshold'] = None
            if not row.get('severity'):
                row['severity'] = None
            if not row.get('vaccine_name'):
                row['vaccine_name'] = None
            if row['event'] not in ('1st dose', '2nd dose', '3rd dose'):
                row['vaccine_name'] = None
            if not row.get('event_date_cmp'):
                row['event_date_cmp'] = '='
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
                'cycle_threshold_cmp',
                'cycle_threshold',
                'vaccine_name',
                'severity',
            ],
            BOM=True
        )


def autofill_sub_history(tables_dir: Path) -> None:
    row: CSVReaderRow
    rows: List[CSVReaderRow]
    pth: Path
    pth_list: Path = tables_dir / 'subject_history'
    for pth in pth_list.iterdir():
        if pth.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(pth))
            continue
        rows = load_csv(pth)
        for row in rows:
            if not row.get('iso_name'):
                row['iso_name'] = None
            if not row.get('cycle_threshold_cmp'):
                row['cycle_threshold_cmp'] = None
            if not row.get('cycle_threshold'):
                row['cycle_threshold'] = None
            if not row.get('severity'):
                row['severity'] = None
            if not row.get('vaccine_name'):
                row['vaccine_name'] = None
            if row['event'] not in ('1st dose', '2nd dose', '3rd dose'):
                row['vaccine_name'] = None
            if not row.get('event_date_cmp'):
                row['event_date_cmp'] = '='
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
                'cycle_threshold_cmp',
                'cycle_threshold',
                'vaccine_name',
                'severity',
            ],
            BOM=True
        )


def autofill_rx_potency(tables_dir: Path) -> None:
    row: CSVReaderRow
    rows: List[CSVReaderRow]
    pth: Path
    pth_list: Path = tables_dir / 'rx_potency'
    for pth in pth_list.iterdir():
        if pth.suffix.lower() != '.csv':
            click.echo('Skip {}'.format(pth))
            continue
        rows = load_csv(pth)
        for row in rows:
            row['potency_type'] = row.get('potency_type') or 'NT50'
            row['cumulative_count'] = row.get('cumulative_count') or '1'
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


def autofill_rx_fold(tables_dir: Path) -> None:
    row: CSVReaderRow
    rows: List[CSVReaderRow]
    susc: Path
    suscs: Path = tables_dir / 'rx_fold'
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
                row['cumulative_count'] = '1'
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
def autofill_payload(payload_dir: str) -> None:
    payload_dir_path = Path(payload_dir)
    tables_dir: Path = payload_dir_path / 'tables'
    antibodies: Path = tables_dir / 'antibodies.csv'
    antibody_targets: Path = tables_dir / 'antibody_targets.csv'
    autofill_rx(tables_dir)
    autofill_invitros(tables_dir)
    autofill_invivos(tables_dir)
    autofill_sbj_plasma(tables_dir)
    autofill_dms(tables_dir)
    autofill_rx_fold(tables_dir)
    autofill_rx_potency(tables_dir)

    autofill_subjects(tables_dir)
    # autofill_sub_history(tables_dir)
    autofill_sbj_treatments(tables_dir)

    sort_csv(antibodies, 'ab_name')
    sort_csv(antibody_targets, 'ab_name')
