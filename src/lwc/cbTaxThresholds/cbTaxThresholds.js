/**
Copyright (c) 04 2024, AJR
All rights reserved.
Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.
 * Neither the name of the CloudBudget, Inc. nor the names of its contributors
may be used to endorse or promote products derived from this software
without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
OF THE POSSIBILITY OF SUCH DAMAGE.

 */
import {LightningElement, track} from 'lwc';
import {_applyDecStyle, _parseServerError} from "c/cbUtils";
import getTaxThresholdsServer from '@salesforce/apex/CBPayrollExpressPageController.getTaxThresholdsServer';
import saveTaxThresholdsServer from '@salesforce/apex/CBPayrollExpressPageController.saveTaxThresholdsServer';
import saveNFLibraryServer from '@salesforce/apex/CBPayrollExpressPageController.saveNFLibraryServer';
import addTaxThresholdServer from '@salesforce/apex/CBPayrollExpressPageController.addTaxThresholdServer';
import deleteTaxThresholdServer from '@salesforce/apex/CBPayrollExpressPageController.deleteTaxThresholdServer';

export default class CBTaxThresholds extends LightningElement {

	@track showSpinner = false;
	@track readyToRender = false;
	@track taxThresholds = [];

	async connectedCallback() {
		this.readyToRender = false;
		this.showSpinner = true;
		await this.getTaxThresholds();
		this.showSpinner = false;
		this.readyToRender = true;
		_applyDecStyle();
	};

	getTaxThresholds = async () => {
		try {
			this.taxThresholds = await getTaxThresholdsServer();
		} catch (e) {
			_parseServerError('Get Employee Error: ', e);
		}
	};

	handleAnalyticChange = async (event) => {
		const tt = this.taxThresholds.find(t => t.Id === event.target.label);
		tt[event.target.name] = event.target.value;
		await saveTaxThresholdsServer({nflLib: tt});
		this.connectedCallback();
	};

	handleTTChange = (event) => {
		const library = this.taxThresholds.find(tt => tt.Id === event.target.name);
		library[event.target.label] = event.target.value;
		saveNFLibraryServer({library});
	};

	handleParamsChange = (event) => {
		let field = event.target.label;
		field = field.includes('Val') ? `cb5__${field}__c` : `${field}__c`;
		const value = event.target.value;
		const nflId = event.target.name;
		const library = {Id: nflId};
		library[field] = value;
		saveNFLibraryServer({library});
	};

	addTaxThreshold = async () => {
		this.showSpinner = true;
		await addTaxThresholdServer();
		this.connectedCallback();
	};

	deleteTaxThreshold = async (event) => {
		this.showSpinner = true;
		await deleteTaxThresholdServer({nflId: event.target.value});
		this.connectedCallback();
	};

}