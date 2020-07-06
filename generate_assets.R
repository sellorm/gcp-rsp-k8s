# Generate assets to be used elsewhere

cat("Generating assets...\n")

# ------------------------------------------------------------------------------

## Architecture diagram

cat("Generating asset: Architecture diagram\n")

library(nomnoml)

arch_diag <- "
[<frame>GCP Compute Engine VM|RStudio Server Pro (IDE FE);NFS Share (User & shared data);User auth]
[<frame>Kubernetes|
  [R sessions]
  [Python Sessions]
]
[<actor>Users] -> [GCP Compute Engine VM]
[GCP Compute Engine VM] <-> [Kubernetes]
"

nomnoml(arch_diag, png = "gcp_rsp_k8s.png")


# ------------------------------------------------------------------------------

cat("Finished\n")