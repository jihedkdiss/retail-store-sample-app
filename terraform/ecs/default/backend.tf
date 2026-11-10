terraform {
  backend "s3" {
    bucket       = "tfstate-926105054786-retail-store"
    key          = "retail-store/ecs/dev.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}
