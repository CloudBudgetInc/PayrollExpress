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
		this.showSpinner = true;
		try {
			await this.getTaxThresholds();
			this.readyToRender = true;
			_applyDecStyle();
		} catch (error) {
			_parseServerError('Initialization Error: ', error);
		} finally {
			this.showSpinner = false;
		}
	}

	async getTaxThresholds() {
		try {
			this.taxThresholds = await getTaxThresholdsServer();
		} catch (error) {
			_parseServerError('Get Tax Thresholds Error: ', error);
		}
	}

	async handleAnalyticChange(event) {
		const tt = this.taxThresholds.find(t => t.Id === event.target.label);
		tt[event.target.name] = event.target.value;
		try {
			await saveTaxThresholdsServer({nflLib: tt});
		} catch (error) {
			_parseServerError('Save Tax Threshold Error: ', error);
		}
		await this.connectedCallback();
	}

	handleTTChange(event) {
		const library = this.taxThresholds.find(tt => tt.Id === event.target.name);
		library[event.target.label] = event.target.value;
		saveNFLibraryServer({library}).catch(e => _parseServerError('Saving Error : ', e));
	}

	handleParamsChange(event) {
		const field = event.target.label.includes('Val') ? `cb5__Single${event.target.label}__c` : `${event.target.label}__c`;
		const value = event.target.value;
		const nflId = event.target.name;
		const library = {Id: nflId};
		library[field] = value;
		console.log('Before Save : ' + JSON.stringify(library));
		saveNFLibraryServer({library}).catch(e => _parseServerError('Saving Error : ', e));
	}

	async addTaxThreshold() {
		this.showSpinner = true;
		try {
			await addTaxThresholdServer();
			await this.connectedCallback();
		} catch (error) {
			_parseServerError('Add Tax Threshold Error: ', error);
		} finally {
			this.showSpinner = false;
		}
	}

	async deleteTaxThreshold(event) {
		this.showSpinner = true;
		try {
			await deleteTaxThresholdServer({nflId: event.target.value});
			await this.connectedCallback();
		} catch (error) {
			_parseServerError('Delete Tax Threshold Error: ', error);
		} finally {
			this.showSpinner = false;
		}
	}
}
