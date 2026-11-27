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
PROJECT_ID=YOUR_PROJECT_ID bash scripts/stress.sh
```

The script discovers running VMs every 30 seconds for 15 minutes and starts a
120-second CPU load on each VM if one is not already running. SSH connections run
sequentially so initial key generation cannot race. On Windows, gcloud's
`ssh/putty_force_connect` setting normally answers Plink's host-key prompt
automatically. You may see `Store key in cache?` immediately followed by command
output, without an opportunity to type `y`. Look for `SSH succeeded` or the actual
connection error after that prompt. If automatic confirmation is disabled, verify
the host key before accepting it interactively. Stop an old script run with
`Ctrl+C` before restarting it.

New autoscaled VMs can be `RUNNING` before SSH and package installation are ready.
The script retries a failed connection or missing `stress-ng` up to six times,
waiting ten seconds between attempts. Override `SSH_RETRIES` and
`SSH_RETRY_DELAY` to adjust this behavior. Retries and foreground SSH can extend
the requested duration; an in-progress connection is allowed to finish.

Override `ZONE`, `MIG`, `DURATION`, or `INTERVAL` as needed. The duration, interval,
retry count, and retry delay must be positive integers. If `PROJECT_ID` is omitted,
gcloud uses its configured project. The script strips Windows carriage returns
from VM names and stops on listing errors or after exhausting SSH retries, so
failures remain visible. After stopping the script, an already started remote CPU
load can continue for up to 120 seconds.
