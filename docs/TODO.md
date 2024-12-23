# ✅ FMJ Studios Shopware 6 - `TODOs`

## ➕ Additions

- [ ] Add [Shopware Analytics](https://store.shopware.com/en/swag541977532977f/shopware-analytics.html) (possibly via
  Composer) -> not possible in 'dev' mode (requires registered shop)
- [ ] Add the [HiPages PHP-FPM Exporter](https://github.com/hipages/php-fpm_exporter)
- [ ] Add the [Nginx Exporter](https://github.com/nginxinc/nginx-prometheus-exporter)

## 📦 Container Changes

- [ ] Add a proper [Banner](http://patorjk.com/software/taag/#p=display&f=Doom&t=FMJ%20Studios%20-%20Shopware%206)
- [ ] Utilize
  the [Nginx OTEL Image](https://github.com/nginxinc/docker-nginx/blob/e78cf70ce7b73a0c9ea734c9cf8aaaa283c1cc5a/stable/debian-otel/Dockerfile)
  and [shared mount](https://tkacz.pro/kubernetes-nginx-and-php-fpm/) for the TCP/Unix socket
- [ ]
  Remove [SetUID-bits](https://eng.libretexts.org/Bookshelves/Computer_Science/Operating_Systems/Linux_-_The_Penguin_Marches_On_(McClanahan)/03%3A_Permission_and_Ownership_Management/3.04%3A_Special_Permission_Types_The_setuid_Bit#:~:text=The%20set%20user%20id%20bit,the%20user%20who%20launched%20it.)
  within the entire container like done
  line [Bitnami's Containers](https://github.com/bitnami/containers/blob/main/bitnami/redis/7.4/debian-12/Dockerfile#L48)
- [ ]
  Introduce [Bitnami-inspired](https://github.com/bitnami/containers/blob/main/bitnami/wordpress/6/debian-12/rootfs/opt/bitnami/scripts/wordpress/entrypoint.sh)
  `ENTRYPOINT` scripts utilizing `exec` for check process monitoring and separate `<program>-env.sh` scripts to
  configure the environment variables for each process instead of cluttering the entire container's ENV
- [ ]
  Implement [RedHat-recommended conventions](https://developers.redhat.com/articles/2023/03/23/10-tips-writing-secure-maintainable-dockerfiles)
  also to
  preserve [OpenShift Compatibility](https://developers.redhat.com/blog/2020/10/26/adapting-docker-and-kubernetes-containers-to-run-on-red-hat-openshift-container-platform#)
- [ ] Configure PHP-FPM on the fly like done in the [
  `docker-library/wordpress`](https://github.com/docker-library/wordpress/blob/master/latest/php8.3/fpm-alpine/Dockerfile)
  image to eliminate the need for repo-stored configuration files
- [ ] Switch to `Debian` as a more solid base, which is also usable as a `distroless` container and compile extensions
  without helper scripts or containers like [
  `docker-library/wordpress`](https://github.com/docker-library/wordpress/blob/master/latest/php8.3/fpm/Dockerfile)
- [ ] Implement a [`distroless`](https://github.com/s6n-labs/distroless-php/blob/main/Dockerfile) final image layer
  using `ldd` to minimize the image size (and switch to Debian...)
- [ ] Expand on
  the
  new [Shopware Deployment Helper](https://developer.shopware.com/docs/guides/hosting/installation-updates/deployments/deployment-helper.html)
  functionality and give the process its' own scripts to be run in an `initContainer`
- [ ] Explore the use of [`slim`](https://github.com/slimtoolkit/slim) for final minification

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
