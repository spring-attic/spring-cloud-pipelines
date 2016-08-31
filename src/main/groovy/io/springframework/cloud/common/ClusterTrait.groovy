package io.springframework.cloud.common

import groovy.transform.CompileStatic

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
trait ClusterTrait {

	String preClusterShell() {
		return '''\
					mkdir -p etcd
					cd etcd
					curl -L  https://github.com/coreos/etcd/releases/download/v2.3.3/etcd-v2.3.3-linux-amd64.tar.gz -o etcd-v2.3.3-linux-amd64.tar.gz
					tar xzvf etcd-v2.3.3-linux-amd64.tar.gz
					cd etcd-v2.3.3-linux-amd64
					nohup ./etcd &
					cd ../..
				'''
	}

	String postClusterShell() {
		return '''\
					pkill etcd && echo "Killed ETCD" || echo "No ETCD process is running"
					rm -rf etcd && echo "Removed ETCD target" || echo "NO ETCD target"
					'''
	}
}