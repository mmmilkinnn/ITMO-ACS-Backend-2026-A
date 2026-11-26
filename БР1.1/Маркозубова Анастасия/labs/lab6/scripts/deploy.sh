#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077

if [[ ! -f .env ]]; then
  gateway=$(sudo -n docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}')
  {
    printf 'NODE_EXPORTER_BIND=%s\n' "$gateway"
    printf 'GRAFANA_ADMIN_PASSWORD=%s\n' "$(openssl rand -hex 24)"
  } > .env
fi

compose=(sudo -n docker compose)
if [[ "${1:-}" == "--smtp-from-stdin" ]]; then
  IFS= read -r smtp_user
  IFS= read -r smtp_password
  IFS= read -r recipient
  smtp_password=${smtp_password// /}
  email_pattern='^[a-zA-Z0-9_.+%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  [[ $smtp_user =~ $email_pattern && $recipient =~ $email_pattern && $smtp_password =~ ^[a-zA-Z0-9]{16}$ ]] || {
    echo "Проверьте адреса и пароль приложения Gmail." >&2
    exit 1
  }
  {
    printf 'GF_SMTP_ENABLED=true\nGF_SMTP_HOST=smtp.gmail.com:587\nGF_SMTP_STARTTLS_POLICY=MandatoryStartTLS\n'
    printf 'GF_SMTP_USER=%s\nGF_SMTP_PASSWORD=%s\nGF_SMTP_FROM_ADDRESS=%s\nLAB6_ALERT_TO=%s\n' "$smtp_user" "$smtp_password" "$smtp_user" "$recipient"
  } > .smtp.env
fi
if [[ -s .smtp.env ]]; then
  compose+=(-f compose.yaml -f compose.smtp.yaml)
fi
"${compose[@]}" config --quiet
"${compose[@]}" up -d
"${compose[@]}" ps
