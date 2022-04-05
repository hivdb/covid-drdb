import click
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from ..cli import cli
from ..utils.csvv import load_csv, dump_csv


def load_articles(payload_dir: Path) -> List[Dict]:
    articles_csv: Path = payload_dir / 'tables' / 'articles.csv'
    return load_csv(articles_csv)


def abort_if_ref_name_used(
    ctx: click.Context,
    param: click.Option,
    value: str
) -> str:
    articles: List[Dict] = load_articles(Path(ctx.params['payload_dir']))
    for a in articles:
        if a['ref_name'] == value:
            raise click.BadParameter(
                'Specified {} {} is already used by article {}'
                .format(param.opts[-1], a['ref_name'], a['doi'] or a['url']),
                ctx,
                param
            )
    return value


def abort_if_ref_name_unused(
    ctx: click.Context,
    param: click.Option,
    value: str
) -> str:
    articles: List[Dict] = load_articles(Path(ctx.params['payload_dir']))
    if not any(a['ref_name'] == value for a in articles):
        raise click.BadParameter(
            'Specified {} {} does not exist'
            .format(param.opts[-1], value),
            ctx,
            param
        )
    return value


def add_article(
    ref_name: str,
    doi: str,
    first_author: str,
    year: str,
    payload_dir: Path
) -> None:
    articles: List[Dict] = load_articles(payload_dir)
    articles.append({
        'ref_name': ref_name,
        'doi': doi if doi.startswith('10.') else None,
        'url': None if doi.startswith('10.') else doi,
        'first_author': first_author,
        'year': year,
        'date_added': datetime.now().strftime('%Y-%m-%d')
    })
    dump_csv(
        payload_dir / 'tables' / 'articles.csv',
        records=articles,
        headers=list(articles[0].keys()),
        BOM=True
    )


def save_xx_tpl(
    ref_name: str,
    example_ref_name: str,
    tpl_dir: Path,
    filename_suffix: str,
    repeat: int,
    **extra_fields: Optional[str]
) -> Path:
    tpl_path: Path = tpl_dir / '{}{}.csv'.format(
        ref_name.lower(), filename_suffix)
    ex_path: Path = tpl_dir / '{}{}.csv'.format(
        example_ref_name.lower(), filename_suffix)
    ex_rows: List[Dict] = load_csv(ex_path)
    dump_csv(
        tpl_path,
        records=[
            {**extra_fields, 'ref_name': ref_name}
        ] * repeat,
        headers=list(ex_rows[0].keys()),
        BOM=True
    )
    return tpl_path


@cli.command()
@click.argument(
    'payload_dir',
    is_eager=True,
    type=click.Path(
        dir_okay=True,
        exists=True,
        file_okay=False
    )
)
@click.option(
    '--ref-name', prompt="Enter new study's refName",
    callback=abort_if_ref_name_used,
    help='Reference name of article to be entered')
@click.option(
    '--doi', prompt="Enter new study's DOI/URL",
    help='DOI of article to be entered')
@click.option(
    '--first_author', prompt="Enter new study's first author (e.g. Harari, S)",
    help='DOI of article to be entered')
@click.option(
    '--year', prompt="Enter new study's publication year (e.g. 2022)",
    help='Publication year of article to be entered')
@click.option(
    '--example-ref-name',
    default='Lee22',
    callback=abort_if_ref_name_unused,
    help='Reference name of example article')
def new_selection_study(
    payload_dir: str,
    ref_name: str,
    doi: str,
    first_author: str,
    year: str,
    example_ref_name: str
) -> None:
    tables_dir: Path = Path(payload_dir) / 'tables'

    tpls: List[Tuple[str, str, int, Dict[str, Optional[str]]]] = [
        (
            'isolates.d',
            '-iso',
            4,
            {
                'iso_name': 'hCoV-19/...',
                'site_directed': 'FALSE',
                'gisaid_id': '1234567',
                'expandable': 'TRUE'
            }
        ),
        (
            'isolate_mutations.d',
            '-isomuts',
            10,
            {'iso_name': 'hCoV-19/...', 'gene': 'S'}
        ),
        (
            'subject_isolates',
            '-sbjiso',
            4,
            {
                'iso_name': 'hCoV-19/...',
                'subject_name': 'Patient ...',
                'iso_source': 'NP',
                'iso_culture': 'FALSE',
                'collection_date_cmp': '='
            }
        ),
        (
            'subject_infections',
            '-inf',
            2,
            {
                'subject_name': 'Patient ...',
                'infection_date_cmp': '<',
            }
        ),
        (
            'subject_severity',
            '-sev',
            2,
            {
                'subject_name': 'Patient ...',
                'start_date_cmp': '<',
                'end_date_cmp': '>'
            }
        ),
        (
            'subject_treatments',
            '-prx',
            4,
            {
                'subject_name': 'Patient ...',
                'start_date_cmp': '<',
                'end_date_cmp': '>'
            }
        )
    ]

    click.echo('=' * 50)
    click.echo('  Selection Study Entering Instruction')
    click.echo('=' * 50)
    click.echo()
    click.echo(
        'Following template files are created under `{}` directory. '
        'You should edit them for entering this new study.'
        .format(payload_dir)
    )

    add_article(ref_name, doi, first_author, year, Path(payload_dir))

    tpl_dir: str
    fname_suffix: str
    repeat: int
    extra: Dict[str, Optional[str]]
    for tpl_dir, fname_suffix, repeat, extra in tpls:
        tpl = save_xx_tpl(
            ref_name,
            example_ref_name,
            tables_dir / tpl_dir,
            fname_suffix,
            repeat,
            **extra
        )
        click.echo('- {}'.format(tpl))
