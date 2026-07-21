#!/usr/bin/env python3
"""
Repack the CI-built pop'n rhythmin .ipa with the game assets.

Fetches the latest CI-built .ipa (a freshly-built binary with none of the game assets, which are not
in the repo) through the GitHub REST API, overlays it onto a bundle directory that carries the
bundle-native files the build lacks, copies the game's Application Support contents into the app's
``assets/`` folder, repacks the result into a new .ipa, signs it with an Apple ID via ``plumesign``
(the only external process used), and optionally installs it to the device.
"""
from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, NoReturn
import argparse
import os
import shutil
import stat
import subprocess as sp
import sys
import tempfile
import zipfile

from tqdm import tqdm
import requests

if TYPE_CHECKING:
    from collections.abc import Sequence

__all__ = ('main',)

API = 'https://api.github.com'
_TIMEOUT = 60


def _die(message: str) -> NoReturn:
    """
    Print an error to stderr and exit with a non-zero status.

    Parameters
    ----------
    message : str
        The error message to print.
    """
    print(f'error: {message}', file=sys.stderr)
    raise SystemExit(1)


def _session(token: str) -> requests.Session:
    """
    Build a GitHub REST session authenticated with the given token.

    Parameters
    ----------
    token : str
        A GitHub token that can read the repo's Actions artifacts.

    Returns
    -------
    requests.Session
        The configured session.
    """
    session = requests.Session()
    session.headers.update({
        'Authorization': f'Bearer {token}',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
    })
    return session


def _pick_run_id(session: requests.Session, repo: str, workflow: str, run_id: str | None) -> str:
    """
    Return the CI run id to pull, using @p run_id or the latest successful workflow run.

    Parameters
    ----------
    session : requests.Session
        The authenticated GitHub session.
    repo : str
        The ``owner/name`` repository.
    workflow : str
        The workflow file that builds the .ipa.
    run_id : str | None
        An explicit run id, or ``None`` to pick the latest successful run.

    Returns
    -------
    str
        The run id.
    """
    if run_id:
        return run_id
    response = session.get(f'{API}/repos/{repo}/actions/workflows/{workflow}/runs',
                           params={'status': 'success', 'per_page': 1},
                           timeout=_TIMEOUT)
    response.raise_for_status()
    runs = response.json().get('workflow_runs', [])
    if not runs:
        _die(f'No successful {workflow} runs were found for {repo}.')
    return str(runs[0]['id'])


def _download_artifact(session: requests.Session, repo: str, artifact: str, run_id: str,
                       destination: Path) -> None:
    """
    Download the named artifact archive for a run to a local zip file.

    Parameters
    ----------
    session : requests.Session
        The authenticated GitHub session.
    repo : str
        The ``owner/name`` repository.
    artifact : str
        The artifact name to download.
    run_id : str
        The run to download from.
    destination : Path
        The local path to write the artifact zip to.
    """
    response = session.get(f'{API}/repos/{repo}/actions/runs/{run_id}/artifacts', timeout=_TIMEOUT)
    response.raise_for_status()
    artifacts = [a for a in response.json().get('artifacts', []) if a['name'] == artifact]
    if not artifacts:
        _die(f'Artifact {artifact} was not found on run {run_id}.')
    with session.get(artifacts[0]['archive_download_url'], stream=True, timeout=_TIMEOUT) as archive:
        archive.raise_for_status()
        with destination.open('wb') as out:
            for chunk in archive.iter_content(chunk_size=1 << 16):
                out.write(chunk)


def _extract_zip(archive: Path, destination: Path) -> None:
    """
    Extract a zip, preserving unix permissions and symlinks.

    Parameters
    ----------
    archive : Path
        The zip file to extract.
    destination : Path
        The directory to extract into.
    """
    with zipfile.ZipFile(archive) as zip_file:
        for info in zip_file.infolist():
            target = destination / info.filename
            mode = info.external_attr >> 16
            if stat.S_ISLNK(mode):
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.is_symlink() or target.exists():
                    target.unlink()
                target.symlink_to(zip_file.read(info).decode())
            elif info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with zip_file.open(info) as source, target.open('wb') as out:
                    shutil.copyfileobj(source, out)
                if mode:
                    target.chmod(stat.S_IMODE(mode))


def _find_ipa(download_dir: Path) -> Path:
    """
    Locate the .ipa in the extracted artifact, unwrapping a nested .zip when needed.

    Parameters
    ----------
    download_dir : Path
        The directory the artifact was extracted into.

    Returns
    -------
    Path
        The located .ipa file.
    """

    def ipa_files(root: Path) -> list[Path]:
        return sorted(p for p in root.rglob('*') if p.is_file() and p.suffix.lower() == '.ipa')

    if found := ipa_files(download_dir):
        return found[0]
    zips = sorted(p for p in download_dir.rglob('*') if p.is_file() and p.suffix.lower() == '.zip')
    if not zips:
        _die('No .ipa or .zip was found in the artifact.')
    nested = download_dir / 'nested'
    _extract_zip(zips[0], nested)
    if found := ipa_files(nested):
        return found[0]
    _die('No .ipa was found after extracting the artifact.')


def _find_app(payload: Path) -> Path:
    """
    Find the ``.app`` bundle directly under a Payload directory.

    Parameters
    ----------
    payload : Path
        The ``Payload`` directory to search.

    Returns
    -------
    Path
        The ``.app`` bundle directory.
    """
    apps = sorted(p for p in payload.glob('*.app') if p.is_dir())
    if not apps:
        _die(f'No .app was found under {payload}.')
    return apps[0]


def _make_ipa(merge_dir: Path, archive: Path) -> None:
    """
    Zip the bundle directory into an unsigned .ipa, preserving unix modes and symlinks.

    Parameters
    ----------
    merge_dir : Path
        The bundle directory to pack (its ``Payload`` becomes the archive root).
    archive : Path
        The output unsigned .ipa path.
    """
    base = merge_dir / 'Payload' if (merge_dir / 'Payload').is_dir() else merge_dir
    entries = sorted(base.rglob('*'))
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as zip_file:
        for path in tqdm(entries, desc='Packing the IPA', unit='file'):
            archived_name = str(path.relative_to(merge_dir))
            mode = path.lstat().st_mode
            if path.is_symlink():
                info = zipfile.ZipInfo(archived_name)
                info.external_attr = (mode & 0xFFFF) << 16
                zip_file.writestr(info, os.readlink(path))
            elif path.is_dir():
                info = zipfile.ZipInfo(archived_name + '/')
                info.external_attr = ((mode & 0xFFFF) << 16) | 0x10
                zip_file.writestr(info, b'')
            else:
                info = zipfile.ZipInfo(archived_name)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = (mode & 0xFFFF) << 16
                zip_file.writestr(info, path.read_bytes())


def _resolve_plumesign(override: str | None) -> str:
    """
    Resolve the plumesign binary from the flag or the usual locations.

    Parameters
    ----------
    override : str | None
        An explicit plumesign path, or ``None`` to search ``PATH`` and the working directory.

    Returns
    -------
    str
        The resolved plumesign command or path.
    """
    if override:
        return override
    if found := shutil.which('plumesign-linux-x86_64'):
        return found
    local = Path.cwd() / 'plumesign-linux-x86_64'
    if os.access(local, os.X_OK):
        return str(local)
    _die('The plumesign-linux-x86_64 binary was not found; pass --plumesign or --skip-sign.')


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    """
    Parse the command-line arguments.

    Parameters
    ----------
    argv : Sequence[str] | None
        The command-line arguments (defaults to ``sys.argv``).

    Returns
    -------
    argparse.Namespace
        The parsed arguments.
    """
    parser = argparse.ArgumentParser(description='Repack the CI-built .ipa with the game assets.')
    parser.add_argument('merge_dir',
                        type=Path,
                        help='bundle directory laid out as an IPA root (contains Payload/<App>.app) '
                        'with the bundle-native files the build lacks; MODIFIED in place')
    parser.add_argument('asset_dir',
                        type=Path,
                        help="the game's Application Support directory (charts, BGM, chara data, "
                        'art, rhythmin_lv, mulist/acmulist); copied into <App>.app/assets/')
    parser.add_argument('output_ipa',
                        nargs='?',
                        type=Path,
                        default=Path.cwd() / 'PopnRhythmin-signed.ipa',
                        help='output path for the final .ipa (default: ./PopnRhythmin-signed.ipa)')
    parser.add_argument('--token', required=True, help='GitHub token that can read the artifacts')
    parser.add_argument('--repo', default='Tatsh/expert-rotary-phone', help='the owner/name repo')
    parser.add_argument('--artifact', default='PopnRhythmin-adhoc-ipa', help='the artifact name')
    parser.add_argument('--workflow', default='build.yml', help='the workflow that builds the .ipa')
    parser.add_argument('--run-id', default=None, help='a run id (default: latest successful run)')
    parser.add_argument('--plumesign', default=None, help='path to the plumesign binary')
    parser.add_argument('--plumesign-arg',
                        action='append',
                        default=[],
                        dest='plumesign_args',
                        metavar='ARG',
                        help='an extra argument appended to plumesign sign (repeatable)')
    parser.add_argument('--udid', default='1', help='device UDID to install to')
    parser.add_argument('--no-install', action='store_true', help='sign only; do not install')
    parser.add_argument('--skip-sign', action='store_true', help='emit the unsigned repacked .ipa')
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    """
    Run the repack pipeline.

    Parameters
    ----------
    argv : Sequence[str] | None
        The command-line arguments (defaults to ``sys.argv``).

    Returns
    -------
    int
        The process exit status.
    """
    args = _parse_args(argv)

    if not args.merge_dir.is_dir():
        _die(f'The merge directory does not exist: {args.merge_dir}')
    if not args.asset_dir.is_dir():
        _die(f'The asset directory does not exist: {args.asset_dir}')

    # Resolve the signer up front so we fail fast before downloading anything.
    plumesign = '' if args.skip_sign else _resolve_plumesign(args.plumesign)

    merge_dir = args.merge_dir.resolve()
    asset_dir = args.asset_dir.resolve()
    output_ipa = args.output_ipa.resolve()

    session = _session(args.token)
    with tempfile.TemporaryDirectory() as work_name:
        work = Path(work_name)

        run_id = _pick_run_id(session, args.repo, args.workflow, args.run_id)
        print(f'Using run {run_id} of {args.repo}, artifact {args.artifact}.')

        download = work / 'dl'
        download.mkdir()
        artifact_zip = work / 'artifact.zip'
        _download_artifact(session, args.repo, args.artifact, run_id, artifact_zip)
        _extract_zip(artifact_zip, download)

        ipa = _find_ipa(download)
        print(f'Found the built IPA {ipa.name}.')

        extract = work / 'ipa'
        _extract_zip(ipa, extract)

        print(f'Merging the fresh build into {merge_dir}.')
        shutil.copytree(extract, merge_dir, dirs_exist_ok=True)

        # The preservation build loads its charts, lists, BGM, character data, and art from
        # <App>.app/assets/, so staging the asset dir there is required.
        app = _find_app(merge_dir / 'Payload')
        print(f'Populating the assets/ folder in {app.name}.')
        shutil.copytree(asset_dir, app / 'assets', dirs_exist_ok=True)

        unsigned = work / 'unsigned.ipa'
        _make_ipa(merge_dir, unsigned)

        output_ipa.unlink(missing_ok=True)
        if args.skip_sign:
            shutil.copyfile(unsigned, output_ipa)
            print(f'Wrote the unsigned IPA to {output_ipa}.')
        else:
            print(f'Signing with the Apple ID via {Path(plumesign).name}.')
            sp.run((plumesign, 'sign', '--package', str(unsigned), '--apple-id', '-o',
                    str(output_ipa), *args.plumesign_args),
                   check=True)
            print(f'Wrote the signed IPA to {output_ipa}.')

        # Install to the device, a separate step. Skipped when unsigned or when --no-install.
        if args.skip_sign or args.no_install:
            print('Skipping the device install.')
        else:
            print(f'Installing to device {args.udid}.')
            sp.run((plumesign, 'device', '--udid', args.udid, '--install', str(output_ipa)),
                   check=True)
            print('Installed to the device.')

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
