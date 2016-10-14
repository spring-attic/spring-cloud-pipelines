#!/bin/bash

ruby coalesce_readme.rb -i 'docs/README.adoc' -o "README.adoc"
ruby coalesce_readme.rb -i 'docs/JENKINS.adoc' -o "jenkins/README.adoc"
ruby coalesce_readme.rb -i 'docs/CONCOURSE.adoc' -o "concourse/README.adoc"
ruby generate_index.rb