#!/bin/bash

echo "== Aplicando patches Phoenix/Nutanix para DL360 G7 =="

cd /root/phoenix || exit 1

echo "== Backup dos arquivos =="
cp -n phoenix phoenix.bak 2>/dev/null
cp -n kvm.py kvm.py.bak 2>/dev/null
cp -n sysUtil.py sysUtil.py.bak 2>/dev/null
cp -n gui.py gui.py.bak 2>/dev/null
cp -n /root/.local/lib/python3.9/site-packages/layout/layout_finder.py /root/.local/lib/python3.9/site-packages/layout/layout_finder.py.bak 2>/dev/null

echo "== Patch 1: ignorar serial duplicado em kvm.py =="
grep -n "Serial is found duplicate" kvm.py

# Comenta raises próximos ao erro de serial duplicado, se ainda não estiverem comentados.
sed -i '/Serial is found duplicate/,+3 s/^\([[:space:]]*\)raise Exception/\1# raise Exception/' kvm.py

echo "== Patch 2: forçar modelo em sysUtil.py =="
sed -i 's/param_list.model = find_model_match()\[1\]/param_list.model = "NX-3060-G5"/' sysUtil.py

echo "== Patch 3: get_node_model retorna modelo fixo =="
python3 - <<'PY'
from pathlib import Path

p = Path("/root/phoenix/sysUtil.py")
s = p.read_text()

start = s.find("def get_node_model")
if start != -1:
    line_end = s.find("\n", start)
    next_def = s.find("\ndef ", line_end)
    if next_def == -1:
        next_def = len(s)

    header = s[start:line_end+1]
    replacement = header + '  return "NX-3060-G5"\n'
    s = s[:start] + replacement + s[next_def:]

p.write_text(s)
PY

echo "== Patch 4: forçar boot disk sda em find_boot_disk =="
python3 - <<'PY'
from pathlib import Path

p = Path("/root/phoenix/sysUtil.py")
s = p.read_text()

marker = "# Find boot device using layout file's boot_device structure."
patch = '''# Force boot disk for unsupported DL360 G7 layout
  if "sda" in disks:
    return disks["sda"]

  '''

if marker in s and "Force boot disk for unsupported DL360 G7 layout" not in s:
    s = s.replace(marker, patch + marker)

p.write_text(s)
PY

echo "== Patch 5: layout_finder retorna modelo fake =="
python3 - <<'PY'
from pathlib import Path

p = Path("/root/.local/lib/python3.9/site-packages/layout/layout_finder.py")
s = p.read_text()

target = "def _find_model_match"
start = s.find(target)
if start != -1:
    line_end = s.find("\n", start)
    insert = '\n  return None, "NX-3060-G5", "NX-3060-G5", "NX-3060-G5"'
    if "return None, \"NX-3060-G5\", \"NX-3060-G5\", \"NX-3060-G5\"" not in s[start:start+300]:
        s = s[:line_end] + insert + s[line_end:]

p.write_text(s)
PY

echo "== Patch 6: get_node_positions retorna A =="
python3 - <<'PY'
from pathlib import Path

p = Path("/root/phoenix/gui.py")
s = p.read_text()

start = s.find("def get_node_positions")
if start != -1:
    line_end = s.find("\n", start)
    next_def = s.find("\ndef ", line_end)
    if next_def == -1:
        next_def = len(s)

    header = s[start:line_end+1]
    replacement = header + '  return ["A"]\n'
    s = s[:start] + replacement + s[next_def:]

p.write_text(s)
PY

echo "== Limpando temporários =="
for m in $(findmnt -Rnr -o TARGET /tmp/svm_install_chroot 2>/dev/null | sort -r); do
  umount -lf "$m" 2>/dev/null
done

rm -rf /tmp/svm_install_chroot
rm -f /tmp/svm_marker

echo "== Conferências rápidas =="
grep -n "Serial is found duplicate" kvm.py
grep -n "Force boot disk" sysUtil.py
grep -n "def get_node_model" sysUtil.py
grep -n "def _find_model_match" /root/.local/lib/python3.9/site-packages/layout/layout_finder.py
grep -n "def get_node_positions" gui.py

echo "== Patches aplicados. Rode: ./phoenix =="
