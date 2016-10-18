#!/bin/bash

yes | cf delete-route local.pcfdev.io -n github-webhook-test
yes | cf delete-route local.pcfdev.io -n github-eureka-test
yes | cf delete-route local.pcfdev.io -n stubrunner-test
yes | cf delete-route local.pcfdev.io -n github-webhook-stage
yes | cf delete-route local.pcfdev.io -n github-eureka-stage
yes | cf delete-route local.pcfdev.io -n github-webhook-prod
yes | cf delete-route local.pcfdev.io -n github-eureka-prod