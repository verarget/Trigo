# Trigo

Google Cloud web servers with a managed instance group, CPU autoscaling, and an
external HTTP load balancer.

Run Terraform from the repository root:

```sh
terraform -chdir=IaC init
terraform -chdir=IaC validate
terraform -chdir=IaC plan -var="project_id=qwiklabs-gcp-04-4265379245a7"
```

Replace the project ID with your Google Cloud project and configure Google Cloud
credentials before planning. If already inside `IaC`, omit `-chdir=IaC`.

The default region is `us-east1` and the default zone is `us-east1-c`, matching the
attached lab instructions. This lab project's `gcp.resourceLocations` organization
policy allows `us-east1` and `asia-south1`; it rejects `us-central1`. If overriding
the location, set both variables to an allowed region and a zone within it:

```sh
terraform -chdir=IaC plan -var="project_id=qwiklabs-gcp-04-4265379245a7" -var="region=us-east1" -var="zone=us-east1-c"
```

Remove or update any old `region` and `zone` overrides in `.tfvars` files,
`TF_VAR_region` / `TF_VAR_zone`, or CLI arguments, since they override these defaults.
The stress script defaults to `us-east1-c`; for another zone, run it as
`ZONE=asia-south1-a bash scripts/stress.sh`.

Keep the root `scripts` directory alongside `IaC`: the instance template loads
`../scripts/startup.sh` relative to the Terraform module. The load balancer reserves
a global IP and forwards HTTP traffic on port 80 to the web instances. After an
apply, `load_balancer_ip` and `application_url` expose its address.

Shell scripts use LF line endings, enforced by `.gitattributes`. Terraform also
normalizes the startup script before sending it to Linux VMs. Changes to the
instance template roll out automatically, with at most one extra VM and zero
planned unavailable VMs. Check that all backends become `HEALTHY` after applying:

```sh
gcloud compute backend-services get-health web-backend --global --project=qwiklabs-gcp-04-4265379245a7
```

Run the CPU stress script from Git Bash or a Linux shell:

```sh
PROJECT_ID=qwiklabs-gcp-04-4265379245a7 bash scripts/stress.sh
```

The script discovers running VMs every 30 seconds for 15 minutes and starts a
120-second CPU load on each VM if one is not already running. SSH connections run
sequentially so initial key generation cannot race. On Windows, PuTTY may ask you
to verify and cache each VM's host key on the first connection. `--quiet` controls
gcloud prompts; it does not suppress PuTTY's host-key prompt. Confirm the key only
after verifying that it belongs to the intended VM. Stop an old script run with
`Ctrl+C` before restarting it.

Override `ZONE`, `MIG`, `DURATION`, or `INTERVAL` as needed. `DURATION` and `INTERVAL`
are positive numbers of seconds. If `PROJECT_ID` is omitted, gcloud uses its
configured project. The script strips Windows carriage returns from VM names and
stops on listing or SSH errors so failures remain visible. After stopping the
script, an already started remote CPU load can continue for up to 120 seconds.
