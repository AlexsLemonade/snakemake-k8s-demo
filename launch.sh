#!/bin/bash

REMOTE=S3
PREFIX=kurt-snakemake-test

snakemake --kubernetes --use-conda --default-remote-provider $REMOTE --default-remote-prefix $PREFIX
