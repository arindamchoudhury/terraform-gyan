# Chained `moved` blocks collapse. Apply first with the resource named `a` and
# no blocks, then replace the file with what is below and plan:
#
#   # aws_s3_bucket.a has moved to aws_s3_bucket.c
#   Plan: 0 to add, 0 to change, 0 to destroy.
#
# The intermediate address `b` never appears. ApplyMoves walks a graph of the
# statements in topological order, so an object passes through every hop before
# the plan is computed.
#
# To see the failure mode, point two blocks at each other instead (from d to e
# and from e to d): the run stops with "Cyclic dependency in move statements",
# because a chain must end at an address no other statement moves away from.
resource "aws_s3_bucket" "c" {
  bucket = "ch16-chain"
}

moved {
  from = aws_s3_bucket.a
  to   = aws_s3_bucket.b
}

moved {
  from = aws_s3_bucket.b
  to   = aws_s3_bucket.c
}
