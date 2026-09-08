# IB Gateway port-redirect: `ndc1` → `cdc1`

## The problem

IB Gateway's login handshake reaches IBKR via a "CCp gateway" peer. The
default peer is `ndc1.ibllc.com` on port 4001 (live) or 4002 (paper). On
some networks (corporate egress filters, ISPs with port-range blocking,
home routers with restrictive firewalls) outbound TCP to those ports is
blocked, but TCP/443 to `api.ibkr.com` works.

IB Gateway then can't complete authentication and your Gateway sits at
the "Connecting to server" spinner forever.

## What we did about it

IB Gateway honors a `Peer=` setting in `jts.ini` and a `defaultCcpGateway=`
argument in the install4j `response.varfile`. Pointing both at
`cdc1.ibllc.com` (the secondary CCp gateway that IBKR also runs) gets
around the block.

### `jts.ini`

```ini
[IBGateway]
RemoteHostOrderRouting=cdc1.ibllc.com
RemotePortOrderRouting=4001
[Communication]
Peer=cdc1.ibllc.com:4001
[Logon]
SupportsSSL=cdc1.ibllc.com:4000,true,20260906,false
```

### `response.varfile` (install4j)

```properties
cmdLineArgs$StringArray="/home/USER/Jts","cdc1\.ibllc\.com\:4000","language\=https\://download2.interactivebrokers.com/installers/shared/i18n/ib"
```

The `4000` here is the CCp gateway SSL port (different from the 4001
client API port).

## Does this work?

Yes — verified. IB Gateway logs `Connected to cdc1.ibllc.com:4001 (SSL)`
and authentication completes normally.

## Why isn't this in upstream docs?

Probably because IBKR doesn't advertise `cdc1` as a public endpoint and
they'd rather you fix your firewall. But it's been working in production
for IBKR for years and is mentioned in some community wikis.

## Caveats

- IBKR may rotate which gateway peer is available. If `cdc1` ever stops
  accepting connections, you'll see the same "Connecting to server"
  symptom. Revert to `ndc1` and fix the firewall instead.
- The `response.varfile` redirect is honored at install time but the
  `jts.ini` setting wins at runtime. Update both for safety.
