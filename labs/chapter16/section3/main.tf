module "shards" {
  count  = 2
  source = "./mod"
  suffix = count.index
}

module "solo" {
  source = "./mod"
  suffix = "solo"
}
