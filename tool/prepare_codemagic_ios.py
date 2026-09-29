"""Prepare client defines and a Codemagic build number without logging keys."""
import json
import os
import re
from pathlib import Path


def prepare():
    required = ('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'CM_ENV')
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise SystemExit('Missing Codemagic variables: ' + ', '.join(missing))
    verification = os.environ.get('REQUIRE_EMAIL_VERIFICATION', 'true').lower()
    if verification not in ('true', 'false'):
        raise SystemExit('REQUIRE_EMAIL_VERIFICATION must be true or false')
    override = os.environ.get('BUILD_NUMBER')
    if override:
        build_number = override
    else:
        counter = os.environ.get('PROJECT_BUILD_NUMBER', '')
        if not re.fullmatch(r'[0-9]+', counter):
            raise SystemExit('PROJECT_BUILD_NUMBER must be supplied by Codemagic')
        version = re.search(r'^version:\s*[^\s+]+\+(\d+)\s*$',
                            Path('pubspec.yaml').read_text(encoding='utf-8'), re.M)
        base = int(version.group(1)) if version else 1
        build_number = str(base + int(counter) + 1)
    if not re.fullmatch(r'[1-9][0-9]*', build_number):
        raise SystemExit('BUILD_NUMBER must be a positive integer')
    target = Path('build/codemagic/flutter-defines.json')
    target.parent.mkdir(parents=True, exist_ok=True)
    values = {name: os.environ[name] for name in required[:2]}
    values['REQUIRE_EMAIL_VERIFICATION'] = verification == 'true'
    target.write_text(json.dumps(values), encoding='utf-8')
    target.chmod(0o600)
    with Path(os.environ['CM_ENV']).open('a', encoding='utf-8') as environment:
        environment.write(f'\nVW_IOS_BUILD_NUMBER={build_number}\n')
    print(f'Prepared iOS configuration for build {build_number}')


if __name__ == '__main__':
    prepare()
