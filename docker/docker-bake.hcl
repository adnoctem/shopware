# ==== Variables ====
# require setting a version
variable "VERSION" {
  default = null
}

# use 'latest' if no other TAGS are passed in
variable "TAGS" {
  default = "latest"
}

# targets to build
variable "TARGETS" {
  default = "dev,prod"
}

# determine (custom) image registries
variable "REGISTRIES" {
  default = "ghcr.io"
}

# lock the image repository
variable "REPO" {
  default = "fmjstudios/shopware"
}

# set a default version
variable "DEFAULT_PHP" {
  default = "8.3"
}

variable "PHP_VERSIONS" {
  default = "8.2,${DEFAULT_PHP}"
}

# ==== Environment Variables ====
variable "SHOPWARE_S3_BUCKET" {}
variable "SHOPWARE_S3_REGION" {}
variable "SHOPWARE_S3_ACCESS_KEY" {}
variable "SHOPWARE_S3_SECRET_KEY" {}
variable "SHOPWARE_S3_ENDPOINT" {}
variable "SHOPWARE_S3_CDN_URL" {}
variable "SHOPWARE_S3_USE_PATH_ENDPOINT" {}


# ==== Custom Functions ====
# determine in which we're going to append for the image
function "get_registry" {
  params = []
  result = flatten(split(",", REGISTRIES))
}

# determine in which we're going to append for the image
function "get_target" {
  params = []
  result = flatten(split(",", TARGETS))
}

# OpenContainers labels
# ref: https://github.com/opencontainers/image-spec/blob/main/annotations.md
function "labels" {
  params = []
  result = {
    "org.opencontainers.image.base.name"     = "fmjstudios/shopware:latest"
    "org.opencontainers.image.created"       = "${timestamp()}"
    "org.opencontainers.image.description"   = "Shopware - packaged by FMJ Studios"
    "org.opencontainers.image.documentation" = "https://github.com/fmjstudios/shopware"
    "org.opencontainers.image.licenses"      = "MIT"
    "org.opencontainers.image.url"           = "https://hub.docker.com/r/fmjstudios/shopware"
    "org.opencontainers.image.source"        = "https://github.com/fmjstudios/shopware"
    "org.opencontainers.image.title"         = "shopware"
    "org.opencontainers.image.vendor"        = "FMJ Studios"
    "org.opencontainers.image.authors"       = "info@fmj.studio"
    "org.opencontainers.image.version"       = VERSION == null ? "dev-${timestamp()}" : VERSION
  }
}

function "get_target" {
  params = []
  result = flatten(split(",", TARGETS))
}

function "get_php_version" {
  params = []
  result = flatten(split(",", PHP_VERSIONS))
}

function "tags" {
  params = [
    suffix,
    target
  ]
  result = flatten([
    [
      for tag in VERSION == null ? flatten(split(",", TAGS)) : concat(flatten(split(",", TAGS)), [VERSION]) :
      flatten([
          tag == "latest" ? "${REPO}:${tag}" : "",
          tag != "latest" && suffix != "-fcgi" && target != "prod" ? "${REPO}:${tag}${suffix}-${target}" : "",
          tag != "latest" && suffix != "-fcgi" && target == "prod" ? "${REPO}:${tag}${suffix}" : "",
          tag != "latest" && suffix == "-fcgi" && target == "prod" ? "${REPO}:${tag}" : "",
      ])
    ],
    [
      for rgs in get_registry() : [
      for tag in VERSION == null ? flatten(split(",", TAGS)) : concat(flatten(split(",", TAGS)), [VERSION]) :
      flatten([
          tag == "latest" ? "${rgs}/${REPO}:${tag}" : "",
          tag != "latest" && suffix != "-fcgi" && target != "prod" ? "${rgs}/${REPO}:${tag}${suffix}-${target}" : "",
          tag != "latest" && suffix != "-fcgi" && target == "prod" ? "${rgs}/${REPO}:${tag}${suffix}" : "",
          tag != "latest" && suffix == "-fcgi" && target == "prod" ? "${rgs}/${REPO}:${tag}" : "",
      ])
    ]
    ]
  ])
}

# ==== Bake Groups ====
group "default" {
  targets = ["shopware"]
}

group "nginx" {
  targets = ["shopware-nginx"]
}

# group "caddy" {
#   targets = ["shopware-caddy"]
# }

group "all" {
  targets = ["shopware", "shopware-nginx"]
}

# ==== Bake Targets ====
# The (base) application image
target "shopware" {
  name       = "shopware-php${replace(php, ".", "-")}-${tgt}"
  dockerfile = "Dockerfile"
  matrix = {
    php = get_php_version()
    tgt = get_target()
  }
  args = {
    PHP_VERSION = php
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
    "type=env,id=SHOPWARE_S3_BUCKET",
    "type=env,id=SHOPWARE_S3_REGION",
    "type=env,id=SHOPWARE_S3_ACCESS_KEY",
    "type=env,id=SHOPWARE_S3_SECRET_KEY",
    "type=env,id=SHOPWARE_S3_ENDPOINT",
    "type=env,id=SHOPWARE_S3_CDN_URL",
    "type=env,id=SHOPWARE_S3_USE_PATH_ENDPOINT",
  ]
  target = tgt
  tags = tags(
    "-fcgi",
    tgt
  )
  labels = labels()
  output = ["type=docker"]
}

# The Nginx application image
target "shopware-nginx" {
  name       = "shopware-nginx-php${replace(php, ".", "-")}-${tgt}"
  dockerfile = "docker/nginx.Dockerfile"
  contexts = {
    base = "docker-image://fmjstudios/shopware:latest"
  }
  matrix = {
    php = get_php_version()
    tgt = get_target()
  }
  args = {
    PHP_VERSION = php
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
    "type=env,id=SHOPWARE_S3_BUCKET",
    "type=env,id=SHOPWARE_S3_REGION",
    "type=env,id=SHOPWARE_S3_ACCESS_KEY",
    "type=env,id=SHOPWARE_S3_SECRET_KEY",
    "type=env,id=SHOPWARE_S3_ENDPOINT",
    "type=env,id=SHOPWARE_S3_CDN_URL",
    "type=env,id=SHOPWARE_S3_USE_PATH_ENDPOINT",
  ]
  tags = tags(
    "-nginx",
    tgt
  )
  labels = labels()
  output = ["type=docker"]
}

# NOTE: The image using Caddy as the web server is deprecated, due to the DoS possibility with Caddy's
# 'Transfer-Encoding' HTTP header. Until further notice we'll only provide an Nginx image.
# ref: https://github.com/shopware/docker/issues/107
#
# The Caddy application image
# target "shopware-caddy" {
#   name       = "shopware-caddy-php${replace(php, ".", "-")}"
#   dockerfile = "docker/caddy.Dockerfile"
#   contexts = {
#     base = "docker-image://fmjstudios/shopware:latest"
#   }
#   matrix = {
#     php = get_php_version()
#     tgt = get_target()
#   }
#   args = {
#     PHP_VERSION = php
#   }
#   platforms = [
#     "linux/amd64",
#     # uncomment if required
#     # "linux/arm64",
#     # "linux/arm/v7",
#     # "linux/arm/v6",
#     # "linux/riscv64",
#     # "linux/s390x",
#     # "linux/386",
#     # "linux/ppc64le"
#   ]
#   tags = tags(
#     "-caddy",
#     tgt
#   )
#   labels = labels()
#   output = ["type=docker"]
# }
