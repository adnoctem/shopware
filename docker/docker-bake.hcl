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

# ==== Custom Functions ====
# return the appropriate tag for the image
function "latest_or_version" {
  params = [
    target
  ]
  result = target == "dev" ? "${VERSION}-${target}" : VERSION != null ? VERSION : "latest"
}

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
          tag == "latest" && target == "prod" ? "${REPO}:${tag}" : "",
          tag != "latest" && suffix != "-fcgi" && target != "prod" ? "${REPO}:${tag}${suffix}-${target}" : "",
          tag != "latest" && suffix == "-fcgi" && target != "prod" ? "${REPO}:${tag}-${target}" : "",
          tag != "latest" && suffix != "-fcgi" && target == "prod" ? "${REPO}:${tag}${suffix}" : "",
          tag != "latest" && suffix == "-fcgi" && target == "prod" ? "${REPO}:${tag}" : "",
      ])
    ],
    [
      for rgs in get_registry() : [
      for tag in VERSION == null ? flatten(split(",", TAGS)) : concat(flatten(split(",", TAGS)), [VERSION]) :
      flatten([
          tag == "latest" && target == "prod" ? "${rgs}/${REPO}:${tag}" : "",
          tag != "latest" && suffix != "-fcgi" && target != "prod" ? "${rgs}/${REPO}:${tag}${suffix}-${target}" : "",
          tag != "latest" && suffix == "-fcgi" && target != "prod" ? "${rgs}/${REPO}:${tag}-${target}" : "",
          tag != "latest" && suffix != "-fcgi" && target == "prod" ? "${rgs}/${REPO}:${tag}${suffix}" : "",
          tag != "latest" && suffix == "-fcgi" && target == "prod" ? "${rgs}/${REPO}:${tag}" : "",
      ])
    ]
    ]
  ])
}

# ==== Bake Groups ====
group "default" {
  targets = ["shopware-fcgi"]
}

group "nginx" {
  targets = ["shopware-nginx"]
}

group "aio" {
  targets = ["shopware-aio", "shopware-nginx-aio"]
}

group "all" {
  targets = ["shopware", "shopware-nginx", "shopware-aio", "shopware-nginx-aio"]
}

# ==== Bake Targets ====
# The (base) application image
target "base" {
  args = {
    VERSION = VERSION != null ? VERSION : "latest"
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
  # required due to Shopware's need to look up installed plugins and apps
  # at build time. a previously dumped configuration must exist within the
  # bucket otherwise the build will fail
  secret = [
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


target "shopware-fcgi" {
  name       = "shopware-fcgi-php${replace(php, ".", "-")}-${tgt}"
  dockerfile = "Dockerfile"
  inherits = ["base"]
  matrix = {
    php = get_php_version()
    tgt = get_target()
  }
  args = {
    PHP_VERSION = php
  }
  target = tgt
  tags = tags(
    "-fcgi",
    tgt
  )
}

# The Nginx application image
target "shopware-nginx" {
  name       = "shopware-nginx-${tgt}"
  dockerfile = "docker/nginx.Dockerfile"
  inherits = ["base"]
  matrix = {
    tgt = get_target()
  }
  contexts = {
    base = "docker-image://fmjstudios/shopware:${latest_or_version(tgt)}"
  }
  # never update latest for a non-fcgi image
  tags = setsubtract(tags("-nginx", tgt), ["${REPO}:latest", "ghcr.io/${REPO}:latest"])
}

# The AIO (all-in-one) application image
target "shopware-aio" {
  name       = "shopware-aio-${tgt}"
  dockerfile = "docker/aio.Dockerfile"
  inherits = ["base"]
  matrix = {
    tgt = get_target()
  }
  contexts = {
    base = "docker-image://fmjstudios/shopware:${latest_or_version(tgt)}"
  }
  tags = setsubtract(tags("-aio", tgt), ["${REPO}:latest", "ghcr.io/${REPO}:latest"])
}

# The Nginx AIO (all-in-one) application image
target "shopware-nginx-aio" {
  name       = "shopware-nginx-aio-${tgt}"
  dockerfile = "docker/aio.Dockerfile"
  inherits = ["base"]
  matrix = {
    tgt = get_target()
  }
  contexts = {
    base = join("", ["docker-image://fmjstudios/shopware:", tgt != "dev" ? "${VERSION}-nginx" : "${VERSION}-nginx-dev"])
  }
  tags = setsubtract(tags("-nginx-aio", tgt), ["${REPO}:latest", "ghcr.io/${REPO}:latest"])
}

# NOTE: The image using Caddy as the web server is deprecated, due to the DoS possibility with Caddy's
# 'Transfer-Encoding' HTTP header. Until further notice we'll only provide an Nginx image.
# ref: https://github.com/shopware/docker/issues/107
#
# The Caddy application image
# target "shopware-caddy" { }
