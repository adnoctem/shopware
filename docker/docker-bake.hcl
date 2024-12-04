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
variable "REPOSITORY" {
  default = "fmjstudios/shopware"
}

variable "DEFAULT_PHP" {
  default = "8.3"
}

# build for multiple PHP versions - can be a comma-separated list of values like 7.4,8.1,8.2 etc.
variable "PHP_VERSIONS" {
  default = "8.2,${DEFAULT_PHP}"
}

# ==== Custom Functions ====
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

# determine in which Docker repositories we're going to store this image
# function "get_repository" {
#   params = []
#   result = flatten(split(",", REPOSITORIES))
# }

function "get_target" {
  params = []
  result = flatten(split(",", TARGETS))
}

function "get_php_version" {
  params = []
  result = flatten(split(",", PHP_VERSIONS))
}

# determine in which we're going to append for the image
function "get_tags" {
  params = []
  result = VERSION == null ? flatten(split(",", TAGS)) : concat(flatten(split(",", TAGS)), [VERSION])
}

# determine in which we're going to append for the image
function "get_registry" {
  params = []
  result = flatten(split(",", REGISTRIES))
}

# create the fully qualified tags
function "tags" {
  params = [
    php,
    suffix
  ]
  result = flatten(concat(
    [
      for tag in get_tags() : [
        suffix == "-fcgi" ? php == "${DEFAULT_PHP}" ?
        "${REPOSITORY}:${tag}" :
        "${REPOSITORY}:${tag}-php${php}" :
        "${REPOSITORY}:${tag}-php${php}${suffix}"
    ]
    ],
    [
      for registry in get_registry() :
      [
        for tag in get_tags() : [
          suffix == "-fcgi" ? php == "${DEFAULT_PHP}" ?
          "${registry}/${REPOSITORY}:${tag}" :
          "${registry}/${REPOSITORY}:${tag}-php${php}" :
          "${registry}/${REPOSITORY}:${tag}-php${php}${suffix}"
      ]
      ]
    ]
  ))
}


# ==== Bake Groups ====
group "default" {
  targets = ["shopware"]
}

group "all" {
  targets = ["shopware", "shopware-nginx", "shopware-caddy"]
}

# ==== Bake Targets ====
# The (base) application image
target "shopware" {
  name = "shopware-php${replace(php, ".", "-")}"
  # dockerfile = "Dockerfile"
  matrix = {
    php = get_php_version()
  }
  args = {
    PHP_VERSION = php
  }
  platforms = [
    "linux/amd64",
    # "linux/arm64",
    # uncomment if required
    # "linux/arm/v7",
    # "linux/arm/v6",
    # "linux/riscv64",
    # "linux/s390x",
    # "linux/386",
    # "linux/ppc64le"
  ]
  tags = tags(
    php,
    "-fcgi"
  )
  labels = labels()
  output = ["type=docker"]
}

# The Nginx application image
target "shopware-nginx" {
  name       = "shopware-nginx-php${replace(php, ".", "-")}"
  dockerfile = "docker/nginx.Dockerfile"
  contexts = {
    base = "docker-image://fmjstudios/shopware:latest"
  }
  matrix = {
    php = get_php_version()
  }
  args = {
    PHP_VERSION = php
  }
  platforms = [
    "linux/amd64",
    "linux/arm64",
    # uncomment if required
    # "linux/arm/v7",
    # "linux/arm/v6",
    # "linux/riscv64",
    # "linux/s390x",
    # "linux/386",
    # "linux/ppc64le"
  ]
  tags = tags(
    php,
    "-nginx"
  )
  labels = labels()
  output = ["type=docker"]
}

# The Caddy application image
target "shopware-caddy" {
  name       = "shopware-caddy-php${replace(php, ".", "-")}"
  dockerfile = "docker/caddy.Dockerfile"
  contexts = {
    base = "docker-image://fmjstudios/shopware:latest"
  }
  matrix = {
    php = get_php_version()
  }
  args = {
    PHP_VERSION = php
  }
  platforms = [
    "linux/amd64",
    "linux/arm64",
    # uncomment if required
    # "linux/arm/v7",
    # "linux/arm/v6",
    # "linux/riscv64",
    # "linux/s390x",
    # "linux/386",
    # "linux/ppc64le"
  ]
  tags = tags(
    php,
    "-caddy"
  )
  labels = labels()
  output = ["type=docker"]
}
