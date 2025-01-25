# ==== Variables ====
# setting a version is mandatory
# ref: https://docs.docker.com/build/bake/variables/#validating-variables
variable "VERSION" {
  default = null

  validation {
    condition     = VERSION != ""
    error_message = "Must set 'VERSION' to bake images for ${REPO}"
  }
}

# determine (custom) image registries
variable "REGISTRIES" {
  default = "ghcr.io"
}

# lock the image repository
variable "REPO" {
  default = "adnoctem/shopware"
}

# set a default version
variable "PHP" {
  default = "8.3"
}

variable "PHP_VERSIONS" {
  default = "8.2,${PHP}"
}

# set a default node version
variable "NODE" {
  default = "20.18.2"
}

variable "NODE_VERSIONS" {
  default = "${NODE}"
  # default = "${NODE},22.13.1"
}


# ==== Custom Functions ====
# determine in which we're going to append for the image
function "get_registry" {
  params = []
  result = flatten(split(",", REGISTRIES))
}

# OpenContainers labels
# ref: https://github.com/opencontainers/image-spec/blob/main/annotations.md
function "labels" {
  params = []
  result = {
    "org.opencontainers.image.base.name"     = "adnoctem/shopware:latest"
    "org.opencontainers.image.created"       = "${timestamp()}"
    "org.opencontainers.image.description"   = "Shopware - packaged by Ad Noctem Collective"
    "org.opencontainers.image.documentation" = "https://github.com/adnoctem/shopware"
    "org.opencontainers.image.licenses"      = "MIT"
    "org.opencontainers.image.url"           = "https://hub.docker.com/r/adnoctem/shopware"
    "org.opencontainers.image.source"        = "https://github.com/adnoctem/shopware"
    "org.opencontainers.image.title"         = "shopware"
    "org.opencontainers.image.vendor"        = "Ad Noctem Collective"
    "org.opencontainers.image.authors"       = "info@adnoctem.co"
    "org.opencontainers.image.version"       = VERSION
  }
}

function "get_php_version" {
  params = []
  result = flatten(split(",", PHP_VERSIONS))
}

function "get_node_version" {
  params = []
  result = flatten(split(",", NODE_VERSIONS))
}

# Build base tags for suffix and append to for the various other images, versions and configurations
# These images already include all external registries we'd like to push to
function "base_tags" {
  params = []
  result = flatten(
    concat([
      "${REPO}:latest",
      "${REPO}:${VERSION}"
    ],
      [
        for reg in get_registry() : [
        "${reg}/${REPO}:latest",
        "${reg}/${REPO}:${VERSION}"
      ]
      ])
  )
}

# Build image tags for the Shopware application images
function "app_tags" {
  params = [
    suffix,
    php,
    node
  ]
  result = flatten([
    for tg in base_tags() : [
        php != "${PHP}" && node != "${NODE}" ? "${tg}-${php}-node${substr(node,0,2)}${suffix}" : "",
        php != "${PHP}" && node == "${NODE}" ? "${tg}-${php}${suffix}" : "",
        php == "${PHP}" && node != "${NODE}" ? "${tg}-node${substr(node,0,2)}${suffix}" : "",
        php == "${PHP}" && node == "${NODE}" ? "${tg}${suffix}" : "",
    ]
  ])
}

# Build the image tags for external applications for the repository 'adnoctem/shopware'
# NOTE: do not create tags like `latest-nginx`
function "external_tags" {
  params = [
    suffix
  ]
  result = flatten([
    for tag in setsubtract(
      base_tags(), ["${REPO}:latest", "ghcr.io/${REPO}:latest"]
    ) : [
      "${tag}${suffix}"
    ]
  ])
}

# Base configuration to inherit from
target "base" {
  args = {
    VERSION = VERSION
  }
  platforms = [
    "linux/amd64",
    # uncomment if required
    # "linux/arm64",
    # "linux/arm/v7",
    # "linux/arm/v6",
    # "linux/riscv64",
    # "linux/s390x",
    # "linux/386",
    # "linux/ppc64le"
  ]
  secret = [
    # DSNs/URLs
    "type=env,id=DATABASE_URL",
    "type=env,id=OPENSEARCH_URL",
    "type=env,id=REDIS_URL",
    "type=env,id=MESSENGER_TRANSPORT_DSN",
    "type=env,id=MAILER_DSN",
    "type=env,id=LOCK_DSN",
    # S3
    "type=env,id=S3_PUBLIC_BUCKET",
    "type=env,id=S3_PRIVATE_BUCKET",
    "type=env,id=S3_REGION",
    "type=env,id=S3_ACCESS_KEY",
    "type=env,id=S3_SECRET_KEY",
    "type=env,id=S3_ENDPOINT",
    "type=env,id=S3_CDN_URL",
    "type=env,id=S3_USE_PATH_STYLE_ENDPOINT",
  ]
  labels = labels()
  output = ["type=docker"]
}

# ==== Bake Groups ====
group "default" {
  targets = ["shopware"]
}

group "nginx" {
  targets = ["nginx"]
}

group "dev" {
  targets = ["shopware-dev"]
}

# group "aio" {
#   targets = ["shopware-aio"]
# }

group "all" {
  targets = ["shopware", "shopware-dev", "nginx"]
}

# ==== Bake Targets ====
target "shopware" {
  name       = "shopware-php${replace(php, ".", "-")}-node${substr(node,0,2)}"
  dockerfile = "Dockerfile"
  inherits = ["base"]
  matrix = {
    php = get_php_version()
    node = get_node_version()
  }
  args = {
    PHP_VERSION  = php
    NODE_VERSION = node
    APP_ENV      = "prod"
    BUILD_CMD    = "shopware-cli project ci ."
  }
  tags = app_tags(
    "",
    "${php}",
    "${node}"
  )
  secret = [
    "type=file,id=composer_auth,src=auth.json"
  ]
}

target "shopware-dev" {
  name       = "shopware-php${replace(php, ".", "-")}-node${substr(node,0,2)}-dev"
  dockerfile = "Dockerfile"
  inherits = ["base"]
  matrix = {
    php = get_php_version()
    node = get_node_version()
  }
  args = {
    PHP_VERSION  = php
    NODE_VERSION = node
    APP_ENV      = "dev"
    BUILD_CMD    = "shopware-cli project ci --with-dev-dependencies ."
  }
  tags = app_tags(
    "-dev",
    "${php}",
    "${node}"
  )
  secret = [
    "type=file,id=composer_auth,src=auth.json"
  ]
}

# The AIO (all-in-one) application image
# target "shopware-aio" {
#   name       = "shopware-aio-${tgt}"
#   dockerfile = "docker/aio.Dockerfile"
#   inherits = ["base"]
#   matrix = {
#     tgt = get_target()
#   }
#   contexts = {
#     base = "docker-image://adnoctem/shopware:${VERSION}"
#   }
#   tags = external_tags("-aio")
# }

# A custom Shopware-focused Nginx image
target "nginx" {
  # name       = "nginx"
  dockerfile = "docker/nginx.Dockerfile"
  tags = external_tags("-nginx")
}


# NOTE: The image using Caddy as the web server is discouraged, due to the DoS possibility with Caddy's
# 'Transfer-Encoding' HTTP header. Until further notice we'll only provide an Nginx image.
# ref: https://github.com/shopware/docker/issues/107
#
# The Caddy application image
# target "shopware-caddy" { }
