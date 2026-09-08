#!/usr/bin/env python3
"""Patch dumpling kickstart with docker permission / rootless / NAT fixes.

Usage:
    python3 scripts/patch-ks-docker.py [ks-file]

- Idempotent: safe to run twice (skips if marker already present).
- Does NOT touch %packages (docker package names differ per release/repos,
  a hard %packages dep would break the whole image build). Instead the
  injected %post does a best-effort `zypper in ... || true`.
- Injects a new `%post --erroronfail` block that bakes into the image:
    1. docker daemon config (iptables/NAT/DNS/overlay2)
    2. docker.socket permission fix (group docker, 0660)
    3. sysctl ip_forward
    4. docker-nat-fix.service  -> container outer-net access on every boot
    5. docker-firstboot-fix.service + script -> runs once after defaultuser
       is created: usermod -aG docker, subuid/subgid, setuid newuidmap,
       loginctl linger, socket chgrp, iptables MASQUERADE, user hints.
"""
import sys
from pathlib import Path

MARKER = "90_docker_rootless_nat"

SNIPPET = r"""
%post --erroronfail
export SSU_RELEASE_TYPE=release
### begin 90_docker_rootless_nat
set +e
echo "[docker-fix] installing docker stack (best effort, never fail build)..."
zypper --non-interactive refresh || true
zypper --non-interactive in docker docker-compose iptables slirp4netns fuse-overlayfs rootlesskit nftables iproute2 || true
zypper --non-interactive in docker-rootless docker-rootless-extras || true

getent group docker >/dev/null 2>&1 || groupadd -r docker || true

# --- 1. dockerd: allow iptables/NAT, sane DNS, overlay2 ---
mkdir -p /etc/docker
if [ -f /etc/docker/daemon.json ]; then cp -a /etc/docker/daemon.json /etc/docker/daemon.json.bak 2>/dev/null || true; fi
cat > /etc/docker/daemon.json <<'EOF'
{
  "iptables": true,
  "ip-forward": true,
  "ip-masq": true,
  "dns": ["8.8.8.8", "1.1.1.1", "208.67.222.222"],
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"},
  "storage-driver": "overlay2"
}
EOF
chmod 600 /etc/docker/daemon.json || true

# --- 2. docker.socket permission fix: defaultuser (docker group) can talk to it ---
mkdir -p /etc/systemd/system/docker.socket.d
cat > /etc/systemd/system/docker.socket.d/10-permissions.conf <<'EOF'
[Socket]
SocketGroup=docker
SocketMode=0660
EOF

# --- 3. kernel forwarding for container outer-net access ---
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/90-docker.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF

# --- 4. NAT service: re-apply MASQUERADE/FORWARD every boot (connman rewrites rules) ---
cat > /usr/local/bin/docker-nat-fix.sh <<'SCRIPT'
#!/bin/sh
# Re-applied on every boot so containers keep outer-net access.
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
# rootful bridge network
iptables -C FORWARD -i docker0 -o docker0 -j ACCEPT 2>/dev/null || iptables -A FORWARD -i docker0 -o docker0 -j ACCEPT 2>/dev/null || true
iptables -C FORWARD -i docker0 ! -o docker0 -j ACCEPT 2>/dev/null || iptables -A FORWARD -i docker0 ! -o docker0 -j ACCEPT 2>/dev/null || true
iptables -C FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || iptables -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -t nat -C POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE 2>/dev/null || true
iptables -t nat -C POSTROUTING -s 172.18.0.0/16 ! -o docker0 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 172.18.0.0/16 ! -o docker0 -j MASQUERADE 2>/dev/null || true
# rootless slirp network
iptables -t nat -C POSTROUTING -s 10.0.2.0/24 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 10.0.2.0/24 -j MASQUERADE 2>/dev/null || true
exit 0
SCRIPT
chmod 755 /usr/local/bin/docker-nat-fix.sh || true
cat > /etc/systemd/system/docker-nat-fix.service <<'EOF'
[Unit]
Description=Fix Docker NAT/forwarding so containers have outer-net access
After=network-online.target connman.service firewalld.service docker.service
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/docker-nat-fix.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

# --- 5. first-boot: defaultuser docker group + rootless (subuid/linger) + socket perms ---
cat > /usr/local/bin/docker-firstboot-fix.sh <<'SCRIPT'
#!/bin/sh
LOG=/var/log/docker-firstboot-fix.log
mkdir -p /var/log
exec >>"$LOG" 2>&1
echo "[docker-fix] firstboot start $(date)"
# defaultuser is created on first boot by oneshot, so resolve it at runtime
UID_MIN=$(awk '/^UID_MIN/{print $2}' /etc/login.defs 2>/dev/null)
[ -z "$UID_MIN" ] && UID_MIN=100000
DEVICEUSER=$(getent passwd "$UID_MIN" 2>/dev/null | cut -d: -f1)
if [ -z "$DEVICEUSER" ]; then DEVICEUSER=$(getent passwd 100000 2>/dev/null | cut -d: -f1); fi
if [ -z "$DEVICEUSER" ] || ! id "$DEVICEUSER" >/dev/null 2>&1; then
  if id defaultuser >/dev/null 2>&1; then DEVICEUSER=defaultuser; else echo "[docker-fix] no device user yet, exit"; exit 0; fi
fi
echo "[docker-fix] device user: $DEVICEUSER"
# a) docker group (permission fix for /var/run/docker.sock)
getent group docker >/dev/null 2>&1 || groupadd -r docker || true
usermod -aG docker "$DEVICEUSER" || true
# b) rootless: subuid/subgid + setuid helpers
grep -q "^${DEVICEUSER}:" /etc/subuid 2>/dev/null || echo "${DEVICEUSER}:100000:65536" >> /etc/subuid || true
grep -q "^${DEVICEUSER}:" /etc/subgid 2>/dev/null || echo "${DEVICEUSER}:100000:65536" >> /etc/subgid || true
chmod u+s /usr/bin/newuidmap /usr/bin/newgidmap 2>/dev/null || true
# c) lingering so rootless user systemd (docker --user) survives logout
mkdir -p /var/lib/systemd/linger || true
touch "/var/lib/systemd/linger/${DEVICEUSER}" 2>/dev/null || true
loginctl enable-linger "$DEVICEUSER" 2>/dev/null || true
# d) socket perms for already-running rootful daemon
if [ -S /var/run/docker.sock ]; then chgrp docker /var/run/docker.sock 2>/dev/null || true; chmod 660 /var/run/docker.sock 2>/dev/null || true; fi
# e) outer-net + hint files
/usr/local/bin/docker-nat-fix.sh || true
UID_NUM=$(id -u "$DEVICEUSER")
mkdir -p "/home/${DEVICEUSER}/.config/docker" "/home/${DEVICEUSER}/.config/systemd/user" || true
cat > "/home/${DEVICEUSER}/.config/docker/rootless-hint" <<EOF2
# rootless docker quickstart (run as $DEVICEUSER):
#   systemctl --user enable --now docker
#   export DOCKER_HOST=unix:///run/user/${UID_NUM}/docker.sock
#   docker run --rm hello-world
#   docker run --rm alpine ping -c2 8.8.8.8   # outer-net check
EOF2
chown -R "${UID_NUM}:$(id -g "$DEVICEUSER")" "/home/${DEVICEUSER}/.config" 2>/dev/null || true
touch /var/lib/docker-firstboot-fix.done || true
echo "[docker-fix] firstboot done $(date)"
exit 0
SCRIPT
chmod 755 /usr/local/bin/docker-firstboot-fix.sh || true
cat > /etc/systemd/system/docker-firstboot-fix.service <<'EOF'
[Unit]
Description=Docker permission + rootless setup for defaultuser (first boot)
After=systemd-user-sessions.service network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/docker-firstboot-fix.done
[Service]
Type=oneshot
ExecStart=/usr/local/bin/docker-firstboot-fix.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

systemctl --no-reload enable docker.socket 2>/dev/null || true
systemctl --no-reload enable docker.service 2>/dev/null || true
systemctl --no-reload enable docker-nat-fix.service 2>/dev/null || true
systemctl --no-reload enable docker-firstboot-fix.service 2>/dev/null || true
echo "[docker-fix] baked into image OK"
### end 90_docker_rootless_nat
%end
"""


def main() -> int:
    ks = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
        "Jolla-@RELEASE@-dumpling-@ARCH@.ks")
    if not ks.exists():
        # try to resolve @-template name against cwd
        cands = list(Path(".").glob("Jolla-*-dumpling-*.ks"))
        if cands:
            ks = cands[0]
        else:
            print(f"ks file not found: {ks}", file=sys.stderr)
            return 1
    text = ks.read_text()
    if MARKER in text:
        print(f"[patch] {ks} already patched, skip")
        return 0
    # append snippet at end (mic concatenates all %post blocks)
    if not text.endswith("\n"):
        text += "\n"
    text += SNIPPET.lstrip("\n")
    ks.write_text(text)
    print(f"[patch] {ks} patched with docker rootless/NAT fixes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
