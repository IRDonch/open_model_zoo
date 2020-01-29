#!/usr/bin/env python3

import sys
import subprocess
import urllib.parse
import urllib.request

from pathlib import Path

import panflute

def extract_urls_from_md(path):
    with subprocess.Popen(['pandoc', '-t', 'json', '--', str(path)], stdout=subprocess.PIPE) as pandoc:
        doc = panflute.load(pandoc.stdout)
        if pandoc.wait() != 0:
            sys.exit('pandoc failed') # TODO: sys.exit?

    urls = set()

    def save_url(element, doc):
        if isinstance(element, (panflute.Image, panflute.Link)):
            urls.add(element.url)

    doc.walk(save_url)
    return urls

def main():
    repo_root = Path(sys.argv[0]).resolve().parent.parent

    all_good = True

    def complain(format, *args):
        nonlocal all_good
        print(format.format(*args))
        all_good = False

    local_targets = {}
    remote_targets = {}

    print('extracting links...')

    for md_path in sorted(repo_root.glob('**/*.md')):
        md_path_relative = md_path.relative_to(repo_root)

        for url in sorted(extract_urls_from_md(md_path)):
            try:
                components = urllib.parse.urlparse(url)
            except ValueError:
                print('in {}: invalid URL {!r}'.format(md_path_relative, url))
                all_good = False
                continue

            if components.scheme:
                if components.scheme == 'mailto': continue

                if components.scheme not in {'http', 'https'}:
                    complain('in {}: unknown scheme in URL "{}"; only "http" and "https" are supported',
                        md_path_relative, url)
                    continue

                remote_targets.setdefault(urllib.parse.urlunparse(components._replace(fragment='')), set()).add(md_path_relative)
            else:
                if components.netloc or components.path.startswith('/'):
                    complain('in {}: unacceptable non-relative local URL "{}"', md_path_relative, url)
                    continue

                if not components.path: # self-link
                    continue

                path = md_path.parent / Path(urllib.request.url2pathname(components.path))

                try:
                    relative_path = path.resolve().relative_to(repo_root)
                except ValueError:
                    complain('in {}: URL "{}" points outside the repo', md_path_relative, url)
                    continue

                local_targets.setdefault(relative_path, set()).add(md_path_relative)

    print('checking local link targets...')

    for path, sources in local_targets.items():
        if not (repo_root / path).is_file():
            complain('nonexistent local target: "{}" referenced in:', path)
            for source in sorted(sources):
                complain('    {}', source)

    # TODO: validate remote targets

    print('checked {} local + {} remote link targets'.format(len(local_targets), len(remote_targets)))
    sys.exit(0 if all_good else 1)

if __name__ == '__main__':
    main()
