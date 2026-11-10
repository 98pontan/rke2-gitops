# Rollout TODO: morning-times, UI, VPA, Tailscale

Open steps for the work done on 2026-11-09/10. Most are outside git (Vault, Tailscale admin
console, Cloudflare, AppProjects), so Argo cannot do them. Order matters where numbered.

Status when written: `workload-apps/morning-times` + VPA committed (d70aa74). Not committed yet:
`platform-apps/tailscale-operator.yaml`, `tailscale-operator/`, `values/tailscale-operator/`,
`workload-apps/morning-times-ui/`, `platform-apps/TODO.txt`.

## 0. apps AppProject: allow CreateNamespace
- [ ] `clusterResourceWhitelist` must contain `{group: "", kind: Namespace}`, else new workload apps fail with
      "resource :Namespace is not permitted in project apps" (CreateNamespace=true in the ApplicationSet)

## 1. VPA (platform-apps/vertical-pod-autoscaler.yaml)
- [ ] Add to the `apps` AppProject `namespaceResourceWhitelist`:
      `{group: autoscaling.k8s.io, kind: VerticalPodAutoscaler}`
- [ ] Make sure the VPA app is synced before the morning-times charts (else "no matches for kind VerticalPodAutoscaler")
- [ ] After ~a week: `kubectl -n morning-times describe vpa` and check the recommendations

## 2. morning-times backend (workload-apps/morning-times)
- [ ] Gemini API key: aistudio.google.com -> Get API key
- [ ] Vault secret (POSTGRES_PASSWORD must be hex/URL-safe and never changed after first start):
      `vault kv put -mount=secret morning-times/config GEMINI_API_KEY=... EMAIL_PASSWORD=... POSTGRES_PASSWORD=$(openssl rand -hex 24)`
- [ ] Vault role `app` allows SA `morning-times` in namespace `morning-times`
- [ ] Push ~/project/morning-times to Forgejo `python-apps/morning-times` (CI builds the image)
- [ ] Check: `kubectl -n morning-times get externalsecret,pods`, then
      `curl -X POST .../api/briefs/generate?send=false` and read the first real Gemini brief
- [ ] Backups for Postgres (Longhorn backup target or pg_dump; a CronJob needs adding to the apps AppProject)

## 3. morning-times-ui (workload-apps/morning-times-ui)
- [ ] Push ~/project/morning-times-ui to Forgejo `python-apps/morning-times-ui`
- [ ] Cloudflare: A record `morning-times` -> `192.168.50.53`, DNS only (grey cloud), NOT in the cloudflared tunnel
- [ ] Commit + push the chart; open https://morning-times.pontus-homelab.space

## 4. Tailscale (platform-apps/tailscale-operator.yaml), details in values/tailscale-operator/README.md
- [ ] Tailnet policy: tagOwners (tag:k8s-operator, tag:k8s), autoApprovers for the three node /32 routes,
      grant tcp:443/80/6443 on the nodes; remove the default allow-all rule
- [ ] OAuth client (Trust credentials): write on General>Services, Devices>Core, Keys>Auth Keys, tag tag:k8s-operator
- [ ] `vault kv put -mount=secret tailscale/operator-oauth client_id=... client_secret=...`
- [ ] Vault role `app` allows SA `eso-vault` in namespace `tailscale`
- [ ] `infra` AppProject allows SecretStore/ExternalSecret (ns tailscale) and cluster-scoped tailscale.com/Connector
- [ ] DHCP reservations for 192.168.50.53 / .173 / .219 (the Connector and the policy list them)
- [ ] Commit + push; check Machines shows k8s-operator and homelab-subnet-router (routes approved)
- [ ] Devices: Tailscale on phone/laptop, `tailscale up --accept-routes` on Linux; test kubectl + https names away from home

## 5. Leftovers found on the way
- [ ] iss-tracker: Vault secret must be at `secret/iss-tracker/config` key EMAIL_PASSWORD
      (written with `-mount=secret`, no `data/` in the path); ESO reported "Secret does not exist"
- [ ] `platform-apps/argo-rollouts.yaml` uses cluster-issuer `letsencrypt-prod`; everything else uses
      `letsencrypt-cloudflare`. Fix unless that issuer exists.
- [ ] `platform-apps/cloudflare-tunnel.yaml` uses `targetRevision: "*"`; pin a chart version
- [ ] Forgejo workflow: add a test step (pytest / npm test) before build-and-push
- [ ] Later: login for the morning-times API/UI (needed before sharing it with anyone)
