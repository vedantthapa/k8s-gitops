project := phx-01h57q8t23amkhpscfjenrp9y2
name := gitops-cluster

dockerpw = $(shell cat gcr-credentials.json)

.PHONY: k3d-create
k3d-create:
		k3d cluster create $(name) --config=k3d/config.yaml

.PHONY: k3d-delete
k3d-delete:
		k3d cluster delete $(name) 

.PHONY: service-account
service-account:
		gcloud iam service-accounts create crossplane-provider --display-name "crossplane-provider"
		gcloud projects add-iam-policy-binding "$(project)" \
				--member "serviceAccount:crossplane-provider@$(project).iam.gserviceaccount.com" \
				--role roles/editor
		gcloud projects add-iam-policy-binding "$(project)" \
				--member "serviceAccount:crossplane-provider@$(project).iam.gserviceaccount.com" \
				--role roles/resourcemanager.projectIamAdmin
		gcloud iam service-accounts keys create gcp-credentials.json \
				--iam-account=crossplane-provider@$(project).iam.gserviceaccount.com

.PHONY: gcp-secret
gcp-secret:
		kubeseal --fetch-cert \
				--controller-name=sealed-secrets-controller \
				--controller-namespace=flux-system > k8s/flux-system/pub-sealed-secrets.pem
		kubectl create secret generic gcp-secret \
				--namespace crossplane-system \
				--from-file=creds=./gcp-credentials.json -o yaml \
				--dry-run > k8s/crossplane-system/gcp-credentials.yaml
		kubeseal --format yaml \
				--cert k8s/flux-system/pub-sealed-secrets.pem < k8s/crossplane-system/gcp-credentials.yaml > k8s/crossplane-system/gcp-credentials-enc.yaml
		rm -f k8s/crossplane-system/gcp-credentials.yaml

# create secrets in flux-system and server namespace for image reconciliation and image pull respectively
.PHONY: account_keys
account_keys:
		gcloud iam service-accounts keys create gcr-credentials.json --iam-account gcr-credentials-sync@$(project).iam.gserviceaccount.com


.PHONY: registry-secret
registry-secret: account_keys
		kubectl create secret docker-registry gcr-credentials \
					--namespace=server \
                    --dry-run=client \
                    --docker-server=northamerica-northeast1-docker.pkg.dev \
  					--docker-username=_json_key \
  					--docker-password='$(dockerpw)' \
                    -o yaml | kubectl apply -f -
		kubectl create secret docker-registry gcr-credentials \
					--namespace=flux-system \
                    --dry-run=client \
                    --docker-server=northamerica-northeast1-docker.pkg.dev \
  					--docker-username=_json_key \
  					--docker-password='$(dockerpw)' \
                    -o yaml | kubectl apply -f -
