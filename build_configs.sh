#!/bin/bash

./terraform12 output kubeconfig >> ~/.kube/config

./terraform12 output config_map_aws_auth >> config_map_aws_auth.yaml
