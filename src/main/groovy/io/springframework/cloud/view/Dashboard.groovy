package io.springframework.cloud.view

import javaposse.jobdsl.dsl.JobManagement
import javaposse.jobdsl.dsl.View

class Dashboard extends View {

	protected Dashboard(JobManagement jobManagement) {
		super(jobManagement)
	}

	@Override
	Node getNode() {
		return new XmlParser().parse(this.class.getResourceAsStream("/${this.class.simpleName}-template.xml"))
	}
}