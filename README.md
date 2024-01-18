# Operating a Zammad Instance in the Google Cloud

## Abstract
* Simple and straightforward setup and operation using this guide
  * Updates via swapping the Docker image
* Lowest possible operating costs
  * Spot instance (Spot VMs may be terminated at any time)
  * Default network
  * Standard storage
  * Time-controlled operation possible
  * Operating in Central America (Iowa)
* Zammad instance on a VM instance with [minimal requirements](https://docs.zammad.org/en/latest/prerequisites/hardware.html#for-zammad-and-a-database-server-like-postgresql-we-recommend-at-least)
* Database is on a separate disk
* The separate disk is backed up daily with a snapshot
* Close or secure previously known vulnerabilities

## Technical Goal
* Docker image running on the VM instance (Container-Optimized OS/COS)
  * Image can be exchanged at any time with little downtime
* CentOS Stream 8 operating system
* _Supervisor_ as Service Manager
* _Elasticsearch_ with memory limit of 1GB
* _Letsencrypt SSL_ certificate for https access to _Zammad_
  * will be automatically renewed
  * Only TLS 1.2 and TLS 1.3 and current cipher as recommended by the Mozilla Foundation
  * Strong ec-521 encryption
* _PostgreSQL_ database
  * on external disk with 10 GB
    * incremental daily snapshots
* _Nginx_ reverse proxy
* _Zammad_ Web instance over HTTPS
  * HTTP with 301 on HTTPS
* Best elimination of known vulnerabilities in the image
  * [Trivy](https://www.aquasec.com/products/trivy/) finds no vulnerabilities in the Docker image

## Versions (at the time of release)
* CentOS Stream 8
* Elasticsearch v7.17.16
* Nginx v1.14.1
* PostgreSQL v10.23
* Zammad v6.2.0-1704877727.2bda00c4.centos8

## What the additional files are for
### `zammad-launcher.sh`
* Runs every time the system boots
* Initializes the database if not already done
* Migrates the database if necessary (in the case of Docker image replacement or Zammad updates)
* SSL certificate management

### `zammad_ssl.conf`
* Contains the SSL configuration for Nginx
* Use of secure ciphers by Mozilla Foundation
* Defines content compression
* Defines reverse proxy
* Logging of access and errors
* SSL relevant parameters

## Requirements
* Local Docker Installation
* [gcloud CLI](https://cloud.google.com/cli) Installation

## Build the Docker Image
Execute located in the project root directory:
```bash
docker build --build-arg BUILD_DATE="$(date --rfc-3339=seconds)" -t viselabs/zammad viselabs/zammad
```

## Definition of the project, zone and region where the operation takes place
The selection of the region and zone influences [the costs](https://cloud.google.com/compute/all-pricing) incurred during operation. Probably is
There is still a lot to think about when it comes to data protection.
```bash
gcloud config set project coloryzer
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a
```
## Push the Docker Image

### Artifact Registry Repository erstellen
The repository is needed as a storage location for the image we built. This is how the VM instance 
can do it obtain later. Updates can also be stored here later.  
⚠️ We recommend activating the [Security Scanner](https://console.cloud.google.com/artifacts/settings). (Please take the costs into account)
```bash
gcloud artifacts repositories create viselabs --repository-format=docker
```

### Set permission for Artifact Registry Docker Push
```bash
gcloud auth configure-docker us-docker.pkg.dev
```

### Docker image tagged for upload/push
```bash
docker tag viselabs/zammad us-docker.pkg.dev/"$(gcloud config get-value project)"/viselabs/zammad:6.2.0
```

We then upload the project to the Artifact Registry. We set version `6.2.0` here.
```bash
docker push us-docker.pkg.dev/"$(gcloud config get-value project)"/viselabs/zammad:6.2.0
```

## Create and start VM instance
* Image runs as [Spot Instance](https://cloud.google.com/spot-vms).
* Machine type is `e2-medium` 2 vCPU, 4 GB RAM
* An additional 10 GB disk is created for the PostgreSQL database
  * Backed up daily according to policy `default-schedule-1`
  * Will be automatically formatted with `ext4` by `konlet`, so this hasn't happened yet
  * Deployed to `/var/lib/pgsql/data` in the Docker container
* Configuration of SSL certificate properties and parameters
* Network configuration

```bash
gcloud compute instances create-with-container zammad-620-1 \
  --container-image us-docker.pkg.dev/"$(gcloud config get-value project)"/viselabs/zammad:6.2.0 \
  --container-mount-disk=mode=rw,mount-path=/var/lib/pgsql,name=zammad-data-1 \
  --create-disk=device-name=zammad-data-1,auto-delete=false,disk-resource-policy=projects/"$(gcloud config get-value project)"/regions/us-central1/resourcePolicies/default-schedule-1,mode=rw,name=zammad-data-1,size=10,type=pd-balanced \
  --instance-termination-action=STOP \
  --machine-type=e2-medium \
  --metadata=DOMAIN=support.coloryzer.com \
  --project="$(gcloud config get-value project)" \
  --provisioning-model=SPOT \
  --public-ptr \
  --public-ptr-domain=support.coloryzer.com \
  --shielded-integrity-monitoring \
  --shielded-secure-boot \
  --shielded-vtpm
```
⚠️ It can take up to **10 minutes** for the instance to be accessible after it is started for the first time.

## Connect to the started VM instance via SSH
⚠️ Required for administrative purposes. You can skip this step.
```bash
gcloud beta compute ssh zammad-620-1
```

## Create Firewall Rules
### List Rules
⚠️ Be sure to check beforehand whether these rules may already exist.
```bash
gcloud compute firewall-rules list
```
Optionally allow SSH access.
```bash
gcloud compute firewall-rules create allow-ssh --network default --allow tcp:22
```
Access via HTTP, but is redirected directly to HTTPS via redirect.
```bash
gcloud compute firewall-rules create allow-http --network default --allow tcp:80
```
Absolutely necessary.
```bash
gcloud compute firewall-rules create allow-https --network default --allow tcp:443
```

## Obtain Non-Volatile IP Address
Finding out the current IP address.
```bash
gcloud compute instances describe zammad-620-1 | grep natIP
```
Now we convert the IP address to a static one.
```bash
gcloud compute addresses create default --addresses=34.122.61.193 --region us-central1
```

## Assign static IP address to the instance
### Bind IP address to instance
```bash
TBD
```

## Maintain running system
Only security-relevant packages are updated. However, we exclude the `zammad` and `elasticsearch` package from the update.
```bash
dnf update --security --refresh --exclude=zammad,elasticsearch
```

## Update Zammad to a new version
In the [Google Cloud Console](https://console.cloud.google.com/) edit the instance `zammad-620-1` and under the Settings container
Store the new image e.g. `us-docker.pkg.dev/coloryzer/viselabs/zammad:6.2.1`.  
⚠️ The instance may need to be restarted afterwards.

### Alternative 
* Stop instance `zammad-620-1`
* Detach additional disk `zammad-data-1` from instance `zammad-620-1`
* Additional [create new instance](#create-and-start-vm-instance), only adjusting the instance name in the call
  * The external existing disc is reused
* Bind IP address to the new instance
* Delete the old instance only when the new one is running correctly

This can be skipped if the previous step has been completed. It is only intended to illustrate how a temporary update can be carried out.
```bash
dnf update zammad
zammad run rake db:migrate
zammad run rails r Rails.cache.clear
zammad run rails r Locale.sync
zammad run rails r Translation.sync
zammad run rake zammad:searchindex:rebuild[2]
```

## FAQ
* Boot disk must be 10GB (default)
* External disk is formatted with `ext4` initially
* It can take up to 10 minutes for Zammad to be accessible via the browser after starting

## Known Issues
* _Elasticsearch_ uses _Bouncy Castle_ and introduce a **not yet fixed** vulnerability (CVE-2023-33201)
  * The product does not validate, or incorrectly validates, a certificate.
* 

## Add swap memory to the VM instance
It seems that this one is not really needed.
If it is still required, add the metadata `user-data` when creating the instance.
```bash
gcloud compute instances add-metadata zammad-620-1 --metadata-from-file=user-data=cloud-init-production.yml
```
⚠️ If carried out during operation, a restart must then be carried out.
