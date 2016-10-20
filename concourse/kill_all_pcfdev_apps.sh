#!/bin/bash

cf login -a https://api.local.pcfdev.io --skip-ssl-validation -u admin -p admin -o pcfdev-org -s pcfdev-test

cf target -o pcfdev-org -s pcfdev-test
yes | cf stop github-webhook
yes | cf stop github-eureka
yes | cf stop stubrunner

cf target -o pcfdev-org -s pcfdev-stage
yes | cf stop github-webhook
yes | cf stop github-eureka

cf target -o pcfdev-org -s pcfdev-prod
yes | cf stop github-webhook
yes | cf stop github-eureka