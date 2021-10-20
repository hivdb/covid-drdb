import re
import click
import requests
from pathlib import Path
from collections import defaultdict
from ..cli import cli
from ..utils.csvv import load_csv, dump_csv

PANGO_LINEAGE_PATTERN = re.compile(r"""
    ^
    (?P<pango>[A-Z]+(?:\.\d+)*)
    (?:
        (?P<mod>/|\sw/o\s)
        (?P<muts>[A-Z]\d+(?:[A-Z]|ins|del|stop)\+?)+
    )?
    $
""", re.VERBOSE)

GENE_PATTERN = re.compile(r'^([^:]+):')
DIGIT_PATTERN = re.compile(r'(\d+)')
MUTAA_PATTERN = re.compile(r'([A-Z]|ins|del|stop)$')
WILDTYPES = ['A']

QUERY_URL = 'https://api.outbreak.info/genomics/lineage-mutations'
ORDERED_GENES = [
    'nsp1', 'nsp2', 'PLpro', 'nsp4', '_3CLpro', 'nsp5', 'nsp6',
    'nsp7', 'nsp8', 'nsp9', 'nsp10', 'RdRP', 'nsp13', 'nsp14',
    'nsp15', 'nsp16', 'S', 'ORF3a', 'E', 'M', 'ORF6', 'ORF7a',
    'ORF7b', 'ORF8', 'N', 'ORF10'
]


def parse_mutations(muts):
    muts = muts.split('+')
    results = []
    for mut in muts:
        gene = GENE_PATTERN.search(mut)
        if gene:
            gene = gene.group(1)
        else:
            gene = 'S'
        results.append((
            gene,
            int(DIGIT_PATTERN.search(mut).group(1)),
            MUTAA_PATTERN.search(mut).group(1)
        ))
    return results


def mutation_sort_key(mut):
    gene, pos, aa = mut
    gene_idx = ORDERED_GENES.index(gene)
    return (gene_idx, pos, aa)


def translate_gene_position(gene, pos):
    if gene == 'ORF1a':
        if pos <= 180:
            return 'nsp1', pos
        elif pos <= 818:
            return 'nsp2', pos - 180
        elif pos <= 2763:
            return 'PLpro', pos - 818
        elif pos <= 3263:
            return 'nsp4', pos - 2763
        elif pos <= 3569:
            return '_3CLpro', pos - 3263
        elif pos <= 3859:
            return 'nsp6', pos - 3569
        elif pos <= 3942:
            return 'nsp7', pos - 3859
        elif pos <= 4140:
            return 'nsp8', pos - 3942
        elif pos <= 4253:
            return 'nsp9', pos - 4140
        elif pos <= 4392:
            return 'nsp10', pos - 4253
        else:
            return 'RdRP', pos - 4392
    elif gene == 'ORF1b':
        if pos <= 923:
            return 'RdRP', pos + 9
        elif pos <= 1524:
            return 'nsp13', pos - 923
        elif pos <= 2051:
            return 'nsp14', pos - 1524
        elif pos <= 2397:
            return 'nsp15', pos - 2051
        else:
            return 'nsp16', pos - 2397
    return gene, pos


def read_outbreak_mutations(muts):
    results = []
    for mut in muts:
        gene = mut['gene']
        mut_aa = mut['alt_aa']
        if mut_aa == '*':
            mut_aa = 'stop'
        pos = int(mut['codon_num'])
        mut_type = mut['type']
        if mut_type == 'deletion':
            pos_end = int(mut['codon_end'])
            if pos_end == 'None':
                pos_end = pos
            for p in range(pos, pos_end + 1):
                new_gene, new_pos = translate_gene_position(gene, p)
                results.append((new_gene, new_pos, 'del'))
        else:
            new_gene, new_pos = translate_gene_position(gene, pos)
            results.append((new_gene, new_pos, mut_aa))
    return results


def fetch_consensus(variant_maps, consensus_availability):
    pangos = {pango for _, pango, _, _ in variant_maps}
    resp = requests.get(QUERY_URL, params={
        'pangolin_lineage': ','.join(pangos),
        'frequency': '0.75'
    })
    results = resp.json()
    all_muts_lookup = {}
    for pango, muts in results['results'].items():
        all_muts_lookup[pango] = read_outbreak_mutations(muts)
    for var_name, pango, mod, extra_muts in variant_maps:
        muts = all_muts_lookup.get(pango)
        if not muts:
            if var_name == 'A':
                yield {
                    'var_name': 'A',
                    'gene': 'ORF8',
                    'position': 84,
                    'amino_acid': 'S'
                }
            if var_name not in WILDTYPES:
                consensus_availability[var_name] = 'FALSE'
                click.echo(
                    'Pangolin lineage {} does not exist on Outbreak.Info'
                    .format(pango),
                    err=True
                )
            continue
        if mod == '/':
            muts = muts + extra_muts
        elif mod == ' w/o ':
            muts = set(muts) - set(extra_muts)
        muts = set(muts)

        # it seems outbreak.info switched to use WA1, which has S at ORF8:84
        if any(gene == 'ORF8' and pos == 84 for gene, pos, _ in muts):
            if ('ORF8', 84, 'L') in muts:
                muts.remove(('ORF8', 84, 'L'))
        else:
            muts.add(('ORF8', 84, 'S'))

        muts = sorted(muts, key=mutation_sort_key)
        for gene, pos, aa in muts:
            yield {
                'var_name': var_name,
                'gene': gene,
                'position': pos,
                'amino_acid': aa
            }


@cli.command()
@click.argument(
    'payload_dir',
    type=click.Path(
        dir_okay=True,
        exists=True,
        file_okay=False
    )
)
def update_variant_consensus(payload_dir):
    payload_dir = Path(payload_dir)
    variants_csv = payload_dir / 'tables' / 'variants.csv'
    variants = load_csv(variants_csv)
    variant_synonyms = load_csv(payload_dir / 'tables/variant_synonyms.csv')
    synonym_lookup = defaultdict(list)
    cons_avail = {}
    variant_maps = []
    for synonym in variant_synonyms:
        synonym_lookup[synonym['var_name']].append(synonym['synonym'])
    for variant in variants:
        var_name = variant['var_name']
        synonyms = synonym_lookup[var_name]
        for name in [var_name] + synonyms:
            match = PANGO_LINEAGE_PATTERN.match(name)
            if not match:
                continue
            result = match.groupdict()
            pango = result['pango']
            mod = result['mod']
            muts = result['muts']
            if mod:
                muts = parse_mutations(muts)
            else:
                muts = []
            variant_maps.append((
                var_name,
                pango,
                mod,
                muts
            ))
            break
        else:
            cons_avail[var_name] = 'FALSE'
            click.echo(
                'Variant {} does not have a valid Pango lineage used as its '
                'primary name or ont of its synonyms'.format(var_name),
                err=True
            )
    target = payload_dir / 'tables' / 'variant_consensus.csv'
    dump_csv(
        target,
        fetch_consensus(variant_maps, cons_avail),
        ['var_name', 'gene', 'position', 'amino_acid'])
    dump_csv(
        variants_csv,
        [{**var,
          'consensus_availability': cons_avail.get(var['var_name'], 'TRUE')}
         for var in variants],
        ['var_name', 'as_wildtype', 'consensus_availability'])
