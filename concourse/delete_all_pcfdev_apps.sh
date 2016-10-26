#!/bin/bash

cf login -a https://api.local.pcfdev.io --skip-ssl-validation -u admin -p admin -o pcfdev-org -s pcfdev-test

cf target -o pcfdev-org -s pcfdev-test
yes | cf delete  github-webhook
yes | cf delete  github-analytics
yes | cf delete  github-eureka
yes | cf delete  stubrunner

cf target -o pcfdev-org -s pcfdev-stage
yes | cf delete github-webhook
yes | cf delete  github-analytics
yes | cf delete github-eureka

cf target -o pcfdev-org -s pcfdev-prod
yes | cf delete github-webhook
yes | cf delete  github-analytics
yes | cf delete github-eureka