"""Local UITest helper, restricted to the RentReceipt test app.
Requires explicit user authorization for command-line UI control.
"""
import argparse, json, re, subprocess, time
from pathlib import Path

HDC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
BUNDLE = 'com.vincent.rentreceipt'
parser = argparse.ArgumentParser()
parser.add_argument('--device', default='127.0.0.1:5555')
parser.add_argument('--name', default='phone')
parser.add_argument('action', choices=['snapshot', 'click', 'fill', 'scroll', 'back'])
parser.add_argument('label', nargs='?', default='')
parser.add_argument('value', nargs='?', default='')
args = parser.parse_args()
output = Path(__file__).resolve().parent.parent / 'outputs/harmonyos-qa'
output.mkdir(parents=True, exist_ok=True)

def hdc(*arguments):
    result = subprocess.run([HDC, '-t', args.device, *arguments], capture_output=True, text=True, timeout=25)
    if result.returncode or any(value in result.stdout for value in ['Connect server failed', '[Fail]', 'No target', 'Invalid parameters']):
        raise RuntimeError(result.stderr or result.stdout)
    return result.stdout.strip()

def layout():
    remote = '/data/local/tmp/rentreceipt-layout.json'
    api = int(hdc('shell', 'param', 'get', 'const.ohos.apiversion'))
    arguments = ['shell', 'uitest', 'dumpLayout', '-p', remote]
    if api >= 18:
        arguments += ['-b', BUNDLE]
    hdc(*arguments)
    local = output / (args.name + '-layout.json')
    hdc('file', 'recv', remote, str(local))
    tree = json.loads(local.read_text())
    if not any(attrs(node).get('bundleName') == BUNDLE for node, _ in all_nodes(tree)):
        raise RuntimeError('RentReceipt is not in the foreground; UI control stopped')
    return tree

def all_nodes(value, parents=()):
    if isinstance(value, dict):
        if 'attributes' in value:
            yield value, parents
            parents = parents + (value,)
        for key, child in value.items():
            if key != 'attributes':
                yield from all_nodes(child, parents)
    elif isinstance(value, list):
        for child in value:
            yield from all_nodes(child, parents)

def attrs(node): return node.get('attributes', {})
def center(node):
    points = list(map(int, re.findall(r'-?\d+', attrs(node).get('bounds', ''))))
    if len(points) != 4 or points[2] <= points[0] or points[3] <= points[1]:
        raise RuntimeError('Target is not visible')
    return str((points[0]+points[2])//2), str((points[1]+points[3])//2)

def target(tree):
    matches = [(node, parents) for node, parents in all_nodes(tree) if attrs(node).get('text') == args.label]
    if not matches:
        raise RuntimeError('Visible label not found: ' + args.label)
    for node, parents in matches:
        if args.action == 'fill':
            for parent in reversed(parents):
                fields = [n for n, _ in all_nodes(parent) if attrs(n).get('type') in ['TextInput', 'Search']]
                if fields: return fields[0]
        else:
            for candidate in (node,) + tuple(reversed(parents)):
                if attrs(candidate).get('clickable') == 'true' and attrs(candidate).get('enabled') == 'true':
                    return candidate
            if parents:
                toggles = [n for n, _ in all_nodes(parents[-1]) if attrs(n).get('type') == 'Toggle']
                if toggles: return toggles[0]
    raise RuntimeError('No actionable control for: ' + args.label)

state = layout()
if args.action in ['click', 'fill']:
    x, y = center(target(state))
    if args.action == 'click': hdc('shell', 'uitest', 'uiInput', 'click', x, y)
    else:
        hdc('shell', 'uitest', 'uiInput', 'click', x, y)
        time.sleep(0.3)
        x, y = center(target(layout()))
        # Official SDK key codes: CTRL_LEFT=2072, A=2017, DEL=2055.
        hdc('shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017')
        hdc('shell', 'uitest', 'uiInput', 'keyEvent', '2055')
        if args.value: hdc('shell', 'uitest', 'uiInput', 'inputText', x, y, args.value)
    time.sleep(0.4)
    state = layout()
    if args.action == 'fill' and not any(attrs(node).get('type') in ['TextInput', 'SearchField'] and attrs(node).get('text') == args.value for node, _ in all_nodes(state)):
        raise RuntimeError('Input did not match expected value')
elif args.action == 'back':
    hdc('shell', 'uitest', 'uiInput', 'keyEvent', 'Back'); time.sleep(0.4); state = layout()
elif args.action == 'scroll':
    bounds = [list(map(int, re.findall(r'-?\d+', attrs(node).get('bounds', '')))) for node, _ in all_nodes(state)]
    bounds = [b for b in bounds if len(b) == 4]
    w, h = max(b[2] for b in bounds), max(b[3] for b in bounds)
    start, end = (int(h*.78), int(h*.28)) if args.label != 'up' else (int(h*.28), int(h*.78))
    hdc('shell', 'uitest', 'uiInput', 'swipe', str(int(w*.8)), str(start), str(int(w*.8)), str(end), '1200')
    time.sleep(0.4)
    state = layout()
if args.action == 'snapshot':
    remote = '/data/local/tmp/rentreceipt-screen.png'
    hdc('shell', 'uitest', 'screenCap', '-p', remote)
    hdc('file', 'recv', remote, str(output / (args.name + '.png')))
for node, _ in all_nodes(state):
    a = attrs(node)
    if a.get('text') or a.get('type') in ['TextInput', 'Toggle']:
        print(a.get('type'), a.get('text', ''), a.get('bounds', ''), a.get('enabled', ''))
