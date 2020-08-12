IMAGE := alpine/fio
APP:="app/deploy-openesb.sh"

deploy-kong:
	bash app/deploy-kong.sh

deploy-minikube-latest:
	bash app/deploy-minikube_latest.sh

deploy-minikube:
	bash app/deploy-minikube.sh

push-image:
	docker push $(IMAGE)
.PHONY: deploy-openesb deploy-dashboard push-image
