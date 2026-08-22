# Renaming a module call needs `terraform init` before the next plan, even for a
# local source. Apply this file with the call named `solo` and no `moved` block,
# then rename it to `only` and add the block below.
#
# Plan without re-initialising:
#
#   Error: Module not installed
#   This module is not yet installed. Run "terraform init" to install all
#   modules required by this configuration.
#
# .terraform/modules/modules.json shows why: the install record is keyed by the
# call name, {"Key":"solo","Source":"./mod","Dir":"mod"}, so nothing is
# installed under `only` until init writes that key. After init, the move is
# clean: both resources report `has moved to` and the plan is 0/0/0.
module "only" {
  source = "./mod"
  suffix = "checks"
}

moved {
  from = module.solo
  to   = module.only
}
