## Snakemake Kubernetes Demo

This project doesn't quite work.
The configs are close, but the kubernetes nodes are forever stuck with a NoSchedule taint that I cannot figure out how to remove.

However snakemake will launch and will schedule pods to run its jobs, they just can't get scheduled because  of the taint issue.
To get this much running you can (using version 12 of terraform), run:
```bash
terraform apply
./build_configs.sh # this will place a config file in your ~/.kube directory
kubectl apply -f config_map_aws_auth.yaml
./launch.sh
```

I think that at this point I feel like AWS batch may be a better option for our use case, because it's focused on what we actually need instead of having the capabilities to run an entire system.
However if we do want to invest more time into getting kubernetes to work then I think we should start over with a better guide.

I used https://learn.hashicorp.com/terraform/aws/eks-intro, and it did not work without multiple modifications.
It actually probably made things harder because its configs were close and had things that looked right, but were just wrong enough not to work.
One example of that was the IAM role had permissions to AsssumeRole for EKS, but it also needed that for EC2.
If that role hadn't been provided at all it may have been easier to figure out that it was missing, but it was there, and it did have something that looked right, but it wasn't.

Terraform has a provider for kubernetes: https://www.terraform.io/docs/providers/kubernetes/index.html
There's also a guide that goes with it: https://www.terraform.io/docs/providers/kubernetes/guides/getting-started.html

However it might be a good idea to avoid guides made by Hashicorp and consider one of these instead:
  * https://upcloud.com/community/stories/terraform-kubernetes-provider/
  * https://coreos.com/matchbox/docs/latest/terraform/bootkube-install/README.html
  * https://spotinst.com/blog/kubernetes-tutorial-for-continuous-delivery-with-terraform/
