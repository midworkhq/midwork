# Introduction
This is a public repository which everyone in the world wide web can access.

We try to keep hidden stuff to the minimum but for example it's not nice to publicly mention our IP-addresses or API-keys for everyone to see.

Our servers are running behind Cloudflare so that they can't be DDOSsed easily and by publicly announcing the IP-addresses it kind of defeats the point.

## Adding new values to Github secrets
```
# Run this inside the repository
$ gh secret set RUSTY_IP --body "1.2.3.4"
```