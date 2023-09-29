project := phx-01h57q8t23amkhpscfjenrp9y2
name := gitops-cluster

.PHONY: k3d-create
k3d-create:
		k3d cluster create $(name) --config=k3d/config.yaml

.PHONY: k3d-delete
k3d-delete:
		k3d cluster delete $(name) 

.PHONY: service-account
service-account:
		gcloud iam service-accounts create crossplane-provider --display-name "crossplane-provider"
                gcloud projects add-iam-policy-binding "$(project)" --member "serviceAccount:crossplane-provider@$(project).iam.gserviceaccount.com" --role roles/editor
