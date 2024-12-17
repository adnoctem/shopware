# ✅ FMJ Studios Shopware 6 - `TODOs`

## ➕ Additions

- [ ] Add [Shopware Analytics](https://store.shopware.com/en/swag541977532977f/shopware-analytics.html) (possibly via
  Composer) -> not possible in 'dev' mode (requires registered shop)

## ✏️ Planned Changes

- [x] ~~Use [GitHub's workflow service containers][github_service_containers] instead of a new
  [Docker Compose file][ci_compose]~~ -> made obsolete by new discoveries/configurations
- [x] Make Docker image rootless
- [x] Integrate `Shopware Deployment Helper` into `swctl` Docker container executable -> completed before I even promote
  it to a task
- [ ] Write a `snippet-translator` Plugin
- [ ] Introduce [validation of Docker
  `bake` variables](https://docs.docker.com/build/bake/variables/#validating-variables)
- [ ] Finish `bake.sh`
  with [these improvements](https://stackoverflow.com/questions/19331497/set-environment-variables-from-file-of-key-value-pairs)
- [ ] Add a `gosu` entrypoint script to take care of the heavy lifting required at runtime..
- [ ] Add logic to the `swctl` CLI or it's utility scripts to parse the currently set Sales Channel domain and switch it
  if it isn't actually the same as `$APP_URL` using the Shopware CLI JSON output with
  `pc sales-channel:list --output json > /tmp/sw-saleschannel.json` and parsing using jq with this expression:
  `cat /tmp/sw-saleschannel.json | jq -r '.[] | .domains | keys[0]`

## 💡 Ideas

- Create the [Helm Chart](https://github.com/fmjstudios/helm) for this repository
- Write a plugin implementing `OAuth2/OIDC`, `SAML`, `LDAP` for the administration and at least `OAuth2/OIDC` for the
  frontend
- Write a plugin implementing autocomplete for the order process (internationally)
- Write a plugin implementing the EU VIES API to enable net invoices for business customers
- Use `MySQL Tuning Primer` to establish proven defaults to for our Shopware database configurations

## 🔗 Links

- [GitHub - Awesome Shopware 6](https://github.com/elgentos/awesome-shopware6 "GitHub Awesome Shopware 6")
- [Packagist - Shopware 6 Plugins](https://packagist.org/?query=shopware&type=shopware-platform-plugin "Packagist Shopware Plugins")
- [MySQL Tuning Primer](https://github.com/BMDan/tuning-primer.sh "MySQL Primer")
- [Shopware Deployment Helper](https://developer.shopware.com/docs/guides/hosting/installation-updates/deployments/deployment-helper.html)
- [Admin OAuth Plugin](https://github.com/HEPTACOM/HeptacomShopwarePlatformAdminOpenAuth)

<!-- INTERNAL REFERENCES -->

<!-- File references -->

[ci_compose]: ../ci/compose.yaml

<!-- General links -->

[github_service_containers]: https://docs.github.com/en/actions/use-cases-and-examples/using-containerized-services/creating-postgresql-service-containers
