import csv
from pathlib import Path
from itertools import chain
from more_itertools import unique_everseen


def load_csv(file_path, null_str=r'NULL'):
    with open(file_path, encoding='utf-8-sig') as fd:
        rows = []
        for row in csv.DictReader(fd):
            for key, val in row.items():
                if val == null_str:
                    row[key] = None
            rows.append(row)
        return rows


def load_multiple_csvs(csv_dir, null_str=r'NULL'):
    rows = []
    for child in sorted(Path(csv_dir).iterdir()):
        if child.suffix.lower() != '.csv':
            continue
        rows.extend(load_csv(child, null_str))
    return rows


def dump_csv(file_path, records, headers=[],
             BOM=False, null_str=r'NULL'):
    records = list(records)
    if not records:
        return
    if not headers:
        headers = list(unique_everseen(
            chain(*[r.keys() for r in records])
        ))

    if BOM:
        encoding = 'utf-8-sig'
    else:
        encoding = 'utf-8'

    with open(file_path, 'w', encoding=encoding) as fd:
        writer = csv.DictWriter(
            fd,
            fieldnames=headers,
            restval=null_str,
            extrasaction='ignore')
        writer.writeheader()
        for row in records:
            for key, val in row.items():
                if val is None:
                    row[key] = null_str
            writer.writerow(row)
