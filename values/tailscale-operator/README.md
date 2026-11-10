# Tailscale operator: tailnet setup

The operator (`platform-apps/tailscale-operator.yaml`) runs a subnet router
(`tailscale-operator/connector.yaml`) that makes the three cluster nodes reachable from the
tailnet. The usual `https://*.pontus-homelab.space` names then work away from home too:
Cloudflare DNS still answers `192.168.50.53`, the phone reaches it through the tailnet, and
ingress-nginx serves the same Let's Encrypt certificate as on the home network.

## Tailnet policy (admin console -> Access controls)

Merge these into the existing policy:

```jsonc
{
  "tagOwners": {
    "tag:k8s-operator": [],
    "tag:k8s": ["tag:k8s-operator"]
  },

  // Approve the subnet router's routes automatically (otherwise approve them by hand
  // under Machines -> homelab-subnet-router -> Edit route settings).
  "autoApprovers": {
    "routes": {
      "192.168.50.53/32":  ["tag:k8s"],
      "192.168.50.173/32": ["tag:k8s"],
      "192.168.50.219/32": ["tag:k8s"]
    }
  },

  "grants": [
    // Your devices may use HTTPS/HTTP (ingress) and the Kubernetes API on the nodes, nothing else.
    {
      "src": ["autogroup:member"],
      "dst": ["192.168.50.53/32", "192.168.50.173/32", "192.168.50.219/32"],
      "ip":  ["tcp:443", "tcp:80", "tcp:6443"]
    }
  ]
}
```

The grant only restricts anything if the policy no longer has the default "allow all" rule
(`{"src": ["*"], "dst": ["*"], "ip": ["*"]}`, or the older `acls` equivalent). If it is still
there, replace it with grants for what your own devices need to reach each other, e.g.
`{"src": ["autogroup:member"], "dst": ["autogroup:self"], "ip": ["*"]}`.

## OAuth client

Admin console -> Settings -> Trust credentials -> "+ Credential": write access to
General > Services, Devices > Core and Keys > Auth Keys, each with tag `tag:k8s-operator`.
Store it in Vault (ESO turns it into the `operator-oauth` Secret):

```
vault kv put -mount=secret tailscale/operator-oauth client_id=<id> client_secret=<secret>
```

## On your devices

- Phone/laptop: install Tailscale, log in, and accept subnet routes. Linux needs
  `tailscale up --accept-routes`; the mobile apps accept them by default.
- At home the same IPs are on the local network; the Tailscale clients prefer the local
  network, so nothing changes there.

## DNS for new private services

Add an A record in Cloudflare pointing at `192.168.50.53`, **DNS only** (grey cloud), and give
the service a normal Ingress with `cert-manager.io/cluster-issuer: letsencrypt-cloudflare`.
Do not add private services to the Cloudflare tunnel (`cloudflared`): that is the public path.
