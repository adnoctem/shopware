# ✅ FMJ Studios Shopware 6 - `TODOs`

## ➕ Additions

- [X] Add [DevTools plugin](https://github.com/shopware/dev-tools) as development dependency -> added contained
  dependencies directly instead
- [ ] Add [Shopware Analytics](https://store.shopware.com/en/swag541977532977f/shopware-analytics.html) (possibly via
  Composer) -> not possible in 'dev' mode (requires registered shop)
- [X] Add [FroshTools](https://github.com/FriendsOfShopware/FroshTools)
- [X] Add ~~[FroshAdminer](https://github.com/FriendsOfShopware/FroshPlatformAdminer)~~ -> decided against
- [X] Add [Admin OAuth Plugin](https://github.com/HEPTACOM/HeptacomShopwarePlatformAdminOpenAuth) -> will create custom
  implementation
- [X] Add [HTML Minifier Plugin](https://github.com/FriendsOfShopware/FroshPlatformHtmlMinify)

## ✏️ Planned Changes

- [ ] Use [GitHub's workflow service containers][github_service_containers] instead of a new
  [Docker Compose file][ci_compose]
- [ ] Make Docker image rootless


## 💡 Ideas

- Create the [Helm Chart](https://github.com/fmjstudios/helm) for this repository
- Write a plugin implementing `OAuth2/OIDC`, `SAML`, `LDAP` for the administration and at least `OAuth2/OIDC` for the
  frontend
- Write a plugin implementing autocomplete for the order process (internationally)
- Write a plugin implementing the EU VIES API to enable net invoices for business customers

## 🔗 Links

- [GitHub - Awesome Shopware 6](https://github.com/elgentos/awesome-shopware6)
- [Packagist - Shopware 6 Plugins](https://packagist.org/?query=shopware&type=shopware-platform-plugin)

<!-- INTERNAL REFERENCES -->

<!-- File references -->

[ci_compose]: ../ci/compose.yaml

<!-- General links -->

[github_service_containers]: https://docs.github.com/en/actions/use-cases-and-examples/using-containerized-services/creating-postgresql-service-containers